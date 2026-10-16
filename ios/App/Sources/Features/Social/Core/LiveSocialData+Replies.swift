// Social group — the one read AppData's repositories lack: the group-chat replies to a photo (photo.viewer comments).
// Kept apart from LiveSocialData because `import Supabase` brings its own `Message` type into scope.
import AppData
import Foundation
import Supabase

extension LiveSocialData {
    /// `from("messages").eq("reply_to_post_id", post).order(created_at)` (docs/API.md §5.9), decoded with the client's
    /// own date strategy (the shared `SupabaseClient` of `DataEnvironment`).
    func replyRows(postID: PostID) async throws -> [AppData.Message] {
        do {
            let response: PostgrestResponse<[AppData.Message]> = try await environment.client.supabase
                .from("messages")
                .select()
                .eq("reply_to_post_id", value: postID.rawValue)
                .order("created_at", ascending: true)
                .execute()
            return response.value
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                throw DataError.offline
            default:
                throw error
            }
        }
    }
}
