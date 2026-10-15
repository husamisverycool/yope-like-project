// Account group — InviteJoinModel: state and actions of the screen in InviteScreen.swift.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class InviteJoinModel {
    let token: String
    private(set) var state: InvitePreviewState = .loading
    private(set) var isJoining = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let data: AccountDataSource
    private let loader: InvitePreviewLoader

    init(token: String, data: AccountDataSource, loader: InvitePreviewLoader) {
        self.token = token
        self.data = data
        self.loader = loader
    }

    /// `preview.json` (images and theme); without a configured domain the `invite_preview` RPC gives the text alone.
    func load() async {
        state = .loading
        if loader.previewURL(token: token) != nil {
            state = await loader.load(token: token)
            return
        }
        do {
            let preview = try await data.invitePreview(token: token)
            state = .valid(WebInvitePreview(
                groupName: preview.groupName,
                groupKind: preview.groupKind.rawValue,
                inviterFirstName: preview.inviterFirstName,
                cover: nil,
                members: preview.members.map { WebInvitePreview.Member(firstName: $0.firstName, avatarURL: nil) },
                theme: nil
            ))
        } catch {
            state = Self.state(for: error)
        }
    }

    /// `join_group`; returns the group to open.
    func join() async -> PhotoGroup? {
        guard !isJoining else { return nil }
        isJoining = true
        defer { isJoining = false }
        do {
            let group = try await data.joinGroup(token: token)
            successCount += 1
            return group
        } catch {
            errorCount += 1
            state = Self.state(for: error)
            return nil
        }
    }

    static func state(for error: Error) -> InvitePreviewState {
        switch DataError.from(error) {
        case .api(.groupFull, _): return .full
        case .api(.inviteExpired, _), .api(.inviteRevoked, _): return .unavailable
        case .api(.inviteNotFound, _): return .notFound
        case .offline: return .offline
        default: return .error
        }
    }
}
