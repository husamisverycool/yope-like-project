import UIKit
import XCTest

/// Real photos for the snapshot fixtures: `fixtures/photos/` at the repository root (Unsplash License; the source,
/// photographer and content of each file are in `fixtures/photos/INDEX.md`). Read from the repository at test time,
/// relative to `#filePath` like `SnapshotRecorder`'s output folder; never added to the app or the test bundle.
///
/// File names carry the shape (`…-3x4`, `-4x5`, `-9x16`, `-1x1`, `-4x3`, `-3x2`) or are `avatar-NN` (square
/// head-and-shoulders portraits). Lists are sorted by name, so a pick by index or key is stable until photos are added
/// or removed. Every image is scale 1: its `size` is its pixel size.
enum SamplePhotos {
    /// <repo>/fixtures/photos (this file is <repo>/ios/AppTests/Support/SamplePhotos.swift).
    static let directory: URL = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("fixtures", isDirectory: true)
        .appendingPathComponent("photos", isDirectory: true)

    /// Photo shapes, by the suffix of the file name.
    enum Orientation: CaseIterable {
        /// 3:4, the app's own capture shape.
        case portrait
        /// 4:5.
        case portraitTall
        /// 9:16.
        case story
        /// 1:1.
        case square
        /// 4:3 and 3:2.
        case landscape

        var suffixes: [String] {
            switch self {
            case .portrait: return ["3x4"]
            case .portraitTall: return ["4x5"]
            case .story: return ["9x16"]
            case .square: return ["1x1"]
            case .landscape: return ["4x3", "3x2"]
            }
        }

        /// Width / height.
        var aspect: CGFloat {
            switch self {
            case .portrait: return 3.0 / 4.0
            case .portraitTall: return 4.0 / 5.0
            case .story: return 9.0 / 16.0
            case .square: return 1
            case .landscape: return 4.0 / 3.0
            }
        }

        /// The orientation whose aspect is closest to `width` : `height`.
        static func closest(width: CGFloat, height: CGFloat) -> Orientation {
            let aspect = width / max(height, 1)
            return allCases.min { abs(log($0.aspect / aspect)) < abs(log($1.aspect / aspect)) } ?? .portrait
        }
    }

    // MARK: Names

    /// Every photo (file name without `.jpg`), sorted.
    static let names: [String] = {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let names = files.filter { $0.hasSuffix(".jpg") }.map { String($0.dropLast(4)) }.sorted()
        if names.isEmpty { XCTFail("no sample photos in \(directory.path)") }
        return names
    }()

    /// The square portraits used as avatars, sorted.
    static var avatarNames: [String] { names.filter { $0.hasPrefix("avatar-") } }

    static func names(_ orientation: Orientation) -> [String] {
        names.filter { name in orientation.suffixes.contains { name.hasSuffix("-" + $0) } }
    }

    /// The `index`th photo of `orientation` (wraps around, negative indexes too).
    static func name(index: Int, orientation: Orientation = .portrait) -> String {
        pick(names(orientation), index)
    }

    /// The `index`th avatar (wraps around).
    static func avatarName(index: Int) -> String {
        pick(avatarNames, index)
    }

    /// A photo for `key` (a storage path, an id): the same for the same key in every run (a stable hash, not
    /// `hashValue`), of the orientation closest to `width` : `height`.
    static func name(forKey key: String, width: CGFloat = 3, height: CGFloat = 4) -> String {
        name(index: stableHash(key), orientation: .closest(width: width, height: height))
    }

    /// An avatar for `key`, the same for the same key in every run.
    static func avatarName(forKey key: String) -> String {
        avatarName(index: stableHash(key))
    }

    // MARK: Files and images

    static func url(named name: String) -> URL {
        directory.appendingPathComponent(name.hasSuffix(".jpg") ? name : name + ".jpg")
    }

    /// The JPEG file's bytes.
    static func data(named name: String, file: StaticString = #filePath, line: UInt = #line) -> Data {
        guard let data = try? Data(contentsOf: url(named: name)) else {
            XCTFail("no sample photo \(url(named: name).path)", file: file, line: line)
            return Data()
        }
        return data
    }

    /// The photo at its stored size (decoded once, scale 1).
    static func image(named name: String, file: StaticString = #filePath, line: UInt = #line) -> UIImage {
        cache.lock.lock()
        defer { cache.lock.unlock() }
        if let image = cache.images[name] { return image }
        guard let image = UIImage(contentsOfFile: url(named: name).path) else {
            XCTFail("no sample photo \(url(named: name).path)", file: file, line: line)
            return placeholder
        }
        cache.images[name] = image
        return image
    }

    /// The `index`th photo of `orientation` at its stored size.
    static func photo(index: Int, orientation: Orientation = .portrait) -> UIImage {
        image(named: name(index: index, orientation: orientation))
    }

    /// The photo centre-cropped to `size`'s shape and scaled to exactly `size` pixels (scale 1, a new image).
    static func photo(named name: String, size: CGSize) -> UIImage {
        cropped(image(named: name), to: size)
    }

    /// `photo(named:size:)` as a JPEG.
    static func jpeg(named name: String, size: CGSize, quality: CGFloat = 0.9) -> Data {
        photo(named: name, size: size).jpegData(compressionQuality: quality) ?? Data()
    }

    /// `image` aspect-filled into `size` pixels (centre crop), scale 1.
    static func cropped(_ image: UIImage, to size: CGSize) -> UIImage {
        renderer(size).image { _ in
            image.draw(in: fillRect(for: image.size, in: CGRect(origin: .zero, size: size)))
        }
    }

    /// A grid of `names` (`columns` across, row by row, each tile centre-cropped) on black, `gap` pixels apart, at
    /// `size` pixels: a stand-in for a server-composed collage.
    static func collage(size: CGSize, names: [String], columns: Int, gap: CGFloat = 0) -> UIImage {
        let columns = max(columns, 1)
        let rows = max((names.count + columns - 1) / columns, 1)
        let tile = CGSize(
            width: (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns),
            height: (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        )
        return renderer(size).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, name) in names.enumerated() {
                let origin = CGPoint(x: CGFloat(index % columns) * (tile.width + gap), y: CGFloat(index / columns) * (tile.height + gap))
                let frame = CGRect(origin: origin, size: tile)
                context.cgContext.saveGState()
                context.cgContext.clip(to: frame)
                let source = image(named: name)
                source.draw(in: fillRect(for: source.size, in: frame))
                context.cgContext.restoreGState()
            }
        }
    }

    // MARK: Private

    /// Decoded photos by name, behind a lock.
    private final class Cache: @unchecked Sendable {
        let lock = NSLock()
        var images: [String: UIImage] = [:]
    }

    private static let cache = Cache()

    private static let placeholder: UIImage = renderer(CGSize(width: 1, height: 1)).image { _ in }

    private static func renderer(_ size: CGSize) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format)
    }

    /// The rect that draws an image of `imageSize` aspect-filling `frame`, centred.
    private static func fillRect(for imageSize: CGSize, in frame: CGRect) -> CGRect {
        let scale = max(frame.width / max(imageSize.width, 1), frame.height / max(imageSize.height, 1))
        let drawn = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: frame.midX - drawn.width / 2, y: frame.midY - drawn.height / 2, width: drawn.width, height: drawn.height)
    }

    private static func pick(_ list: [String], _ index: Int) -> String {
        guard !list.isEmpty else { return "" }
        return list[((index % list.count) + list.count) % list.count]
    }

    /// FNV-1a over the UTF-8 bytes, folded to a non-negative `Int` (`hashValue` changes every run).
    private static func stableHash(_ key: String) -> Int {
        var hash: UInt32 = 2_166_136_261
        for byte in key.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return Int(hash & 0x7FFF_FFFF)
    }
}
