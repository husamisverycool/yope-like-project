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

    /// `preview.json` (signed image URLs); without a configured domain the `invite_preview` RPC (storage paths).
    func load() async {
        state = .loading
        if loader.previewURL(token: token) != nil {
            state = await loader.load(token: token)
            return
        }
        do {
            state = .valid(WebInvitePreview(try await data.invitePreview(token: token)))
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
        InvitePreviewState.state(for: error)
    }
}
