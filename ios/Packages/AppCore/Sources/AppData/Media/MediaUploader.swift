import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One object to upload: a local file and where it goes in the bucket.
public struct UploadItem: Codable, Hashable, Sendable {
    public var path: String
    public var fileURL: URL
    public var contentType: String

    public init(path: String, fileURL: URL, contentType: String) {
        self.path = path
        self.fileURL = fileURL
        self.contentType = contentType
    }
}

/// Back-off for transient failures (offline, timeouts, 5xx, 429).
public struct RetryPolicy: Hashable, Sendable {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval
    public var maxDelay: TimeInterval

    public init(maxAttempts: Int = 5, baseDelay: TimeInterval = 1, maxDelay: TimeInterval = 30) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    func delay(afterAttempt attempt: Int) -> TimeInterval {
        min(maxDelay, baseDelay * pow(2, Double(max(0, attempt - 1))))
    }
}

/// Uploads files to the private `media` bucket (docs/API.md §7) with retries:
///
/// - files under `resumableThreshold` go in one `POST /storage/v1/object/<bucket>/<path>`;
/// - larger files (videos, long Live Photo motion) use the Storage resumable (TUS) endpoint in
///   6 MiB chunks; after a failure the upload continues from the server's offset, and the upload
///   URL is kept in the ledger so it continues after a relaunch.
///
/// Uploads never overwrite (`x-upsert: false`). Every path is unique (it contains a fresh UUID),
/// so "already exists" means an earlier attempt of this same upload landed and counts as done.
/// On Apple platforms pass a `BackgroundUploadTransport` so uploads survive suspension.
public struct MediaUploader: Sendable {
    /// Supabase Storage requires 6 MiB TUS chunks (S3 multipart parts) on hosted projects.
    public static let chunkSize = 6 * 1024 * 1024

    public let client: DataClient
    public let transport: any UploadTransport
    public let ledger: UploadLedger?
    public let retry: RetryPolicy
    public let resumableThreshold: Int
    /// Where chunk files are written (background upload tasks need a file per request).
    public let scratchDirectory: URL

    public init(
        client: DataClient,
        transport: any UploadTransport = FoundationUploadTransport(),
        ledger: UploadLedger? = nil,
        retry: RetryPolicy = RetryPolicy(),
        resumableThreshold: Int = MediaUploader.chunkSize,
        scratchDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("AppDataUploads", isDirectory: true)
    ) {
        self.client = client
        self.transport = transport
        self.ledger = ledger
        self.retry = retry
        self.resumableThreshold = resumableThreshold
        self.scratchDirectory = scratchDirectory
    }

    // MARK: Uploading

    public func upload(_ item: UploadItem) async throws {
        guard StoragePaths.isSafe(item.path) else { throw DataError.api(.invalidPath, details: item.path) }
        if ledger?.isCompleted(item.path) == true { return }
        let size: Int
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: item.fileURL.path)
            size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        } catch {
            throw DataError.localFile(item.fileURL.lastPathComponent)
        }
        if size > resumableThreshold {
            try await uploadResumable(item, size: size)
        } else {
            try await withRetry { try await uploadOnce(item) }
        }
        ledger?.markCompleted(item.path)
    }

    /// Writes `data` to a scratch file and uploads it.
    public func upload(data: Data, path: String, contentType: String) async throws {
        let file = try writeScratch(data, name: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try await upload(UploadItem(path: path, fileURL: file, contentType: contentType))
    }

    /// Uploads a profile picture and returns its path (`avatars/<uid>/<uuid>.jpg`); then call
    /// `ProfileRepository.updateProfile(avatarPath:)`.
    public func uploadAvatar(jpeg: Data) async throws -> String {
        let path = StoragePaths.avatar(owner: try await client.requireUserID())
        try await upload(data: jpeg, path: path, contentType: ContentType.jpeg)
        return path
    }

    /// Uploads a group cover and returns its path (`u/<uid>/covers/<uuid>.jpg`) for
    /// `GroupRepository.create(coverPath:)` / `update(cover: .set(path))`.
    public func uploadCover(jpeg: Data) async throws -> String {
        let path = StoragePaths.cover(owner: try await client.requireUserID())
        try await upload(data: jpeg, path: path, contentType: ContentType.jpeg)
        return path
    }

    /// Uploads a link preview's image (`u/<uid>/links/<uuid>.jpg`) and returns its path for
    /// `ChatRepository.setLinkPreview`.
    public func uploadLinkPreview(jpeg: Data) async throws -> String {
        let path = StoragePaths.linkPreview(owner: try await client.requireUserID())
        try await upload(data: jpeg, path: path, contentType: ContentType.jpeg)
        return path
    }

    /// Uploads a chat voice message (`u/<uid>/voice/<uuid>.m4a`) and returns its path for
    /// `ChatRepository.sendVoice`.
    public func uploadChatVoice(fileURL: URL) async throws -> String {
        let path = StoragePaths.chatVoice(owner: try await client.requireUserID())
        try await upload(UploadItem(path: path, fileURL: fileURL, contentType: ContentType.m4a))
        return path
    }

    // MARK: Single request

    private func uploadOnce(_ item: UploadItem) async throws {
        var request = try await baseRequest(url: objectURL(item.path), method: "POST")
        request.setValue(item.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("false", forHTTPHeaderField: "x-upsert")
        request.setValue("max-age=3600", forHTTPHeaderField: "cache-control")
        request.setValue(item.path, forHTTPHeaderField: UploadHeaders.objectPath)
        let (data, response) = try await send(request, bodyFile: item.fileURL)
        if (200..<300).contains(response.statusCode) { return }
        let failure = Self.storageFailure(data: data, status: response.statusCode)
        if failure == .alreadyExists { return }
        throw DataError.storage(failure)
    }

    // MARK: Resumable (TUS 1.0.0)

    private func uploadResumable(_ item: UploadItem, size: Int) async throws {
        var location = ledger?.resumableLocation(for: item.path)
        var offset = 0
        var attempt = 0
        while true {
            do {
                if location == nil {
                    guard let created = try await createResumable(item, size: size) else { return } // already uploaded
                    location = created
                    ledger?.setResumableLocation(created, for: item.path)
                    offset = 0
                } else if let current = location {
                    guard let serverOffset = try await resumableOffset(current) else {
                        // Expired or unknown upload: start over (an upload that already completed
                        // answers "already exists" and ends here).
                        location = nil
                        ledger?.setResumableLocation(nil, for: item.path)
                        continue
                    }
                    offset = serverOffset
                }
                guard let current = location else { continue }
                while offset < size {
                    offset = try await patchChunk(item, location: current, offset: offset, size: size)
                    attempt = 0
                }
                ledger?.setResumableLocation(nil, for: item.path)
                return
            } catch {
                let mapped = DataError.from(error)
                attempt += 1
                guard mapped.isTransient, attempt < retry.maxAttempts else { throw mapped }
                try await sleep(retry.delay(afterAttempt: attempt))
            }
        }
    }

    /// Returns the upload URL, or nil when the object already exists.
    private func createResumable(_ item: UploadItem, size: Int) async throws -> URL? {
        var request = try await baseRequest(url: client.configuration.storageURL.appendingPathComponent("upload/resumable"), method: "POST")
        request.setValue("1.0.0", forHTTPHeaderField: "Tus-Resumable")
        request.setValue(String(size), forHTTPHeaderField: "Upload-Length")
        request.setValue("false", forHTTPHeaderField: "x-upsert")
        let metadata = [
            ("bucketName", client.configuration.bucket),
            ("objectName", item.path),
            ("contentType", item.contentType),
            ("cacheControl", "3600"),
        ].map { "\($0.0) \(Data($0.1.utf8).base64EncodedString())" }.joined(separator: ",")
        request.setValue(metadata, forHTTPHeaderField: "Upload-Metadata")
        let (data, response) = try await send(request, bodyFile: nil)
        if response.statusCode == 201, let location = response.value(forHTTPHeaderField: "Location") {
            return resolveLocation(location)
        }
        let failure = Self.storageFailure(data: data, status: response.statusCode)
        if failure == .alreadyExists { return nil }
        throw DataError.storage(failure)
    }

    /// The server's offset, or nil when the upload is gone (404 / 410).
    private func resumableOffset(_ location: URL) async throws -> Int? {
        var request = try await baseRequest(url: location, method: "HEAD")
        request.setValue("1.0.0", forHTTPHeaderField: "Tus-Resumable")
        let (data, response) = try await send(request, bodyFile: nil)
        if response.statusCode == 404 || response.statusCode == 410 { return nil }
        guard (200..<300).contains(response.statusCode),
              let value = response.value(forHTTPHeaderField: "Upload-Offset"), let offset = Int(value) else {
            throw DataError.storage(Self.storageFailure(data: data, status: response.statusCode))
        }
        return offset
    }

    /// Sends the chunk at `offset`; returns the new offset.
    private func patchChunk(_ item: UploadItem, location: URL, offset: Int, size: Int) async throws -> Int {
        let length = min(Self.chunkSize, size - offset)
        let chunk = try readChunk(item.fileURL, offset: offset, length: length)
        let file = try writeScratch(chunk, name: "chunk-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        var request = try await baseRequest(url: location, method: "PATCH")
        request.setValue("1.0.0", forHTTPHeaderField: "Tus-Resumable")
        request.setValue(String(offset), forHTTPHeaderField: "Upload-Offset")
        request.setValue("application/offset+octet-stream", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await send(request, bodyFile: file)
        guard (200..<300).contains(response.statusCode) else {
            throw DataError.storage(Self.storageFailure(data: data, status: response.statusCode))
        }
        if let value = response.value(forHTTPHeaderField: "Upload-Offset"), let next = Int(value) { return next }
        return offset + length
    }

    // MARK: Helpers

    private func send(_ request: URLRequest, bodyFile: URL?) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await transport.send(request, bodyFile: bodyFile)
        } catch {
            throw DataError.from(error)
        }
    }

    private func objectURL(_ path: String) -> URL {
        // Paths are restricted to [A-Za-z0-9_./-] (StoragePaths.isSafe), so no escaping is needed.
        URL(string: client.configuration.storageURL.absoluteString + "/object/\(client.configuration.bucket)/\(path)")!
    }

    /// The server may answer with its internal host; keep our base URL and its upload id.
    private func resolveLocation(_ location: String) -> URL? {
        guard let url = URL(string: location) else { return nil }
        let id = url.lastPathComponent
        guard !id.isEmpty else { return url }
        return client.configuration.storageURL.appendingPathComponent("upload/resumable").appendingPathComponent(id)
    }

    private func baseRequest(url: URL, method: String) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try await client.accessToken())", forHTTPHeaderField: "Authorization")
        request.setValue(client.configuration.anonKey, forHTTPHeaderField: "apikey")
        return request
    }

    private func withRetry(_ operation: () async throws -> Void) async throws {
        var attempt = 0
        while true {
            do {
                try await operation()
                return
            } catch {
                let mapped = DataError.from(error)
                attempt += 1
                guard mapped.isTransient, attempt < retry.maxAttempts else { throw mapped }
                try await sleep(retry.delay(afterAttempt: attempt))
            }
        }
    }

    private func sleep(_ seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }

    private func writeScratch(_ data: Data, name: String) throws -> URL {
        do {
            try FileManager.default.createDirectory(at: scratchDirectory, withIntermediateDirectories: true)
            let url = scratchDirectory.appendingPathComponent(name)
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            throw DataError.localFile(name)
        }
    }

    private func readChunk(_ file: URL, offset: Int, length: Int) throws -> Data {
        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(offset))
            return try handle.read(upToCount: length) ?? Data()
        } catch {
            throw DataError.localFile(file.lastPathComponent)
        }
    }

    static func storageFailure(data: Data, status: Int) -> DataError.StorageFailure {
        struct Body: Decodable {
            var statusCode: String?
            var error: String?
            var message: String?
        }
        let body = try? JSONDecoder().decode(Body.self, from: data)
        let code = Int(body?.statusCode ?? "") ?? status
        let text = [body?.error, body?.message, body == nil ? String(data: data, encoding: .utf8) : nil]
            .compactMap { $0 }.joined(separator: " ")
        return DataError.storageFailure(status: code, text: text)
    }
}
