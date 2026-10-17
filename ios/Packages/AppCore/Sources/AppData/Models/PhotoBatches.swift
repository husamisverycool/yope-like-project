import Foundation

/// The batch a photo belongs to (migration 0051, docs/API.md `posts.batch_id`): the same author and the same `batch_id`.
/// The composer gives every photo of one selection the same id; each photo stays its own post.
public struct PhotoBatchKey: Hashable, Sendable {
    public let authorID: UserID
    public let batchID: String

    public init(authorID: UserID, batchID: String) {
        self.authorID = authorID
        // uuids are compared without regard to case (the server writes them lower case; a device may not)
        self.batchID = batchID.lowercased()
    }
}

extension Post {
    /// The photo's batch; nil for a photo posted alone.
    public var batchKey: PhotoBatchKey? {
        batchID.map { PhotoBatchKey(authorID: authorID, batchID: $0) }
    }
}

/// Where a photo stands among the photos of its batch (the viewer's page dots, `photo.viewer.layout.batchDots`): 1-based
/// `index` of `total`. Positions, never a count shown as a number.
public struct PhotoBatchPosition: Equatable, Sendable {
    public let index: Int
    public let total: Int

    public init(index: Int, total: Int) {
        self.index = index
        self.total = total
    }
}

/// `layout.global.photoBatch`: how the apps show several photos posted together — one chat run item, one strip tile, the
/// viewer's pages side by side in the order they were posted. Pure functions; every surface uses these.
public enum PhotoBatches {
    /// Splits `items` (already in `created_at` order) into runs: consecutive items with the same non-nil key are one run;
    /// every other item is a run of its own. A photo of the batch that is gone leaves the rest together; anything else
    /// between two photos of a batch (another message, someone else's photo) splits it into two runs. Order is kept.
    public static func runs<Item>(_ items: [Item], key: (Item) -> PhotoBatchKey?) -> [[Item]] {
        var result: [[Item]] = []
        var previous: PhotoBatchKey?
        for item in items {
            let current = key(item)
            if let current, current == previous, !result.isEmpty {
                result[result.count - 1].append(item)
            } else {
                result.append([item])
            }
            previous = current
        }
        return result
    }

    /// `ids` with the members of one batch (`batch`, in `created_at` order) side by side in that order, where the first of
    /// them stood; ids of the batch that `ids` does not hold are not added. Fewer than two members: `ids` unchanged.
    public static func gather<ID: Hashable>(_ ids: [ID], batch: [ID]) -> [ID] {
        let present = Set(ids)
        var seen = Set<ID>()
        let members = batch.filter { present.contains($0) && seen.insert($0).inserted }
        guard members.count > 1 else { return ids }
        let memberSet = Set(members)
        guard let first = ids.firstIndex(where: { memberSet.contains($0) }) else { return ids }
        return Array(ids[..<first]) + members + ids[first...].filter { !memberSet.contains($0) }
    }

    /// The position of `id` among the members of `batch` that `ids` holds, in batch order; nil when `id` is not one of
    /// them or fewer than two are there.
    public static func position<ID: Hashable>(of id: ID, in ids: [ID], batch: [ID]) -> PhotoBatchPosition? {
        let present = Set(ids)
        var seen = Set<ID>()
        let members = batch.filter { present.contains($0) && seen.insert($0).inserted }
        guard members.count > 1, let index = members.firstIndex(of: id) else { return nil }
        return PhotoBatchPosition(index: index + 1, total: members.count)
    }
}
