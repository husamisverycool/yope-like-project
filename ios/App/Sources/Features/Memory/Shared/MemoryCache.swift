// Cache-first loading for the memory screens: the last content of each screen stays in memory for
// the session, so reopening shows it at once and the fresh read replaces it in place.
// Memory only (nothing on disk); entries belong to one account and are dropped when another account
// reads; an entry that shows a deleted photo is dropped on `post_deleted`.
import AppData
import Foundation

@MainActor
final class MemoryCache {
    static let shared = MemoryCache()

    private struct Entry {
        let value: Any
        let postIDs: Set<PostID>
    }

    private var owner: UserID?
    private var entries: [String: Entry] = [:]

    /// The value stored under `key` for `user`, if any.
    func value<Value>(_ type: Value.Type, key: String, user: UserID?) -> Value? {
        guard let user else { return nil }
        if owner != user {
            removeAll()
            owner = user
            return nil
        }
        return entries[key]?.value as? Value
    }

    /// Stores `value` for `user`; `postIDs` are the photos it shows (dropped when one is deleted).
    func set<Value>(_ value: Value, key: String, user: UserID?, postIDs: Set<PostID> = []) {
        guard let user else { return }
        if owner != user {
            removeAll()
            owner = user
        }
        entries[key] = Entry(value: value, postIDs: postIDs)
    }

    func remove(key: String) {
        entries[key] = nil
    }

    /// Drops every entry that shows `postID`.
    func purge(postID: PostID) {
        entries = entries.filter { !$0.value.postIDs.contains(postID) }
    }

    func removeAll() {
        entries.removeAll()
    }
}
