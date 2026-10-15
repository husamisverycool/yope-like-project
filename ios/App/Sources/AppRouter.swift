import AppModels
import Foundation
import Observation

/// A pushed screen in the main navigation stack.
enum AppRoute: Hashable {
    case group(id: String)
    case post(groupID: String, postID: String)
    case chat(groupID: String, messageID: String?)
    case recap(groupID: String, recapID: String)
    case birthdayRequest(requestID: String, groupID: String?)
    case tribute(tributeID: String, groupID: String?)
    case yearStory(groupID: String, year: Int)
}

/// A screen presented over the navigation stack.
enum AppModal: Hashable, Identifiable {
    /// `camera.capture` / `camera.fromwidget`; with an invitation id: `daily.capture`.
    case camera(groupID: String?, invitationID: String?)
    /// `groups.invite` join flow for an invite link opened inside the app.
    case invite(token: String)

    var id: Self { self }

    var isCapture: Bool {
        if case .camera = self { return true }
        return false
    }
}

/// Navigation state, driven by `DeepLink`s from widgets, notifications and universal links.
///
/// Links that arrive before the user is signed in and onboarded are held in `pendingLink` and
/// applied when `setReady(true)` is called (the invite token stays readable meanwhile, so
/// onboarding can show which group is being joined).
@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = []
    var modal: AppModal?
    private(set) var isReady = false
    private(set) var pendingLink: DeepLink?
    private(set) var promptGate = SessionPromptGate()

    let parser: DeepLinkParser

    init(parser: DeepLinkParser) {
        self.parser = parser
    }

    /// The invite being followed, if any (pending during onboarding, or presented).
    var inviteToken: String? {
        if case let .invite(token)? = pendingLink { return token }
        if case let .invite(token)? = modal { return token }
        return nil
    }

    // MARK: Links

    /// Opens a URL from `onOpenURL` (widgets, custom scheme) or a universal link. Unknown URLs are ignored.
    func open(_ url: URL) {
        guard let link = parser.parse(url) else { return }
        handle(link)
    }

    func handle(_ link: DeepLink) {
        guard isReady else {
            pendingLink = link
            return
        }
        apply(link)
    }

    /// Called when sign-in and onboarding complete (true) or the user signs out (false).
    func setReady(_ ready: Bool) {
        isReady = ready
        guard ready else {
            path = []
            modal = nil
            return
        }
        if let link = pendingLink {
            pendingLink = nil
            apply(link)
        }
    }

    private func apply(_ link: DeepLink) {
        switch link {
        case let .invite(token):
            modal = .invite(token: token)
        case let .camera(groupID):
            modal = .camera(groupID: groupID, invitationID: nil)
        case let .dailyInvitation(groupID, invitationID):
            path = [.group(id: groupID)]
            modal = .camera(groupID: groupID, invitationID: invitationID)
        case let .post(groupID, postID):
            show([.group(id: groupID), .post(groupID: groupID, postID: postID)])
        case let .chatMessage(groupID, messageID):
            show([.group(id: groupID), .chat(groupID: groupID, messageID: messageID)])
        case let .recap(groupID, recapID):
            show([.group(id: groupID), .recap(groupID: groupID, recapID: recapID)])
        case let .birthdayRequest(requestID, groupID):
            show([.birthdayRequest(requestID: requestID, groupID: groupID)])
        case let .tribute(tributeID, groupID):
            show([.tribute(tributeID: tributeID, groupID: groupID)])
        case let .yearStory(groupID, year):
            show([.group(id: groupID), .yearStory(groupID: groupID, year: year)])
        }
    }

    private func show(_ routes: [AppRoute]) {
        modal = nil
        path = routes
    }

    func dismissModal() {
        modal = nil
    }

    // MARK: Premium prompt (at most once per session; never during capture or onboarding)

    func startSession() {
        promptGate.startSession()
    }

    var activePromptBlockers: Set<SessionPromptGate.Blocker> {
        var blockers: Set<SessionPromptGate.Blocker> = []
        if modal?.isCapture == true { blockers.insert(.capture) }
        if !isReady { blockers.insert(.onboarding) }
        return blockers
    }

    /// True (once per session) when the premium prompt may be shown now.
    func consumePremiumPrompt() -> Bool {
        promptGate.consumePrompt(activeBlockers: activePromptBlockers)
    }
}
