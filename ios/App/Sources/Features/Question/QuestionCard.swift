// Surface: question.weekly A, C, D — the week's question as a feed card in the group screen's pager. Visual reference:
// Retro's feed cards (references/auto/retro/store/retro-store-01.png, ST-01: C-18 geometry;
// references/auto/retro/apk/nux_card_what_to_share_0.webp: a prompt card with a dark bottom gradient); mechanics Retro's
// "what to share" prompt cards (references/auto/retro/apk/retro-android-2026.10.1150-strings.txt
// `nux_card_title_what_to_share_*`) and Apple Journal's reflection prompt
// (references/auto/apple-journal/store/journal-store-iPhone_2_Suggestions.png: an eyebrow over a short prompt; "touch and
// hold the suggestion, then tap Remove") (design/surfaces/question.weekly.md; MERGE WQ-1 … WQ-7).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class QuestionCardModel {
    let groupID: GroupID
    private(set) var question: GroupQuestion?
    /// The question's text from copy (nil for a key this build does not know).
    private(set) var text: String?
    /// The week's answers in this group, newest first.
    private(set) var answers: [PostWithMedia] = []

    private let services: PlansServices

    init(groupID: GroupID, services: PlansServices) {
        self.groupID = groupID
        self.services = services
    }

    /// Shown while the group has a question this week, this build knows its text and the member has not removed it.
    var isVisible: Bool {
        guard let question else { return false }
        return !question.hiddenByMe && text != nil
    }

    var newestAnswer: PostWithMedia? { answers.first }

    /// The viewer's order: the strip's, oldest first.
    var answersOldestFirst: [PostWithMedia] { answers.reversed() }

    /// `current_group_question`, then its answers. A failure hides the card (the group screen's own error line covers
    /// the screen).
    func refresh() async {
        do {
            let current = try await services.questions.currentQuestion(groupID: groupID)
            question = current
            text = current.flatMap { QuestionCopy.text(forKey: $0.questionKey) }
            if let current, !current.hiddenByMe {
                answers = try await services.questions.answers(questionID: current.id, groupID: groupID)
            } else {
                answers = []
            }
        } catch {
            question = nil
        }
    }

    /// "Remove": the card goes for this member until the next question (no confirmation).
    func hide() async {
        guard let question else { return }
        self.question?.hiddenByMe = true
        do {
            try await services.questions.hideQuestion(id: question.id)
        } catch {
            self.question?.hiddenByMe = false
        }
    }

    /// The camera context for the card's button.
    var cameraContext: QuestionCameraContext.Context? {
        guard let question, let text else { return nil }
        return QuestionCameraContext.Context(groupID: groupID.rawValue, questionID: question.id, text: text)
    }

    /// The group's posts changed (an answer arrived, a photo developed): refetch.
    func follow() async {
        for await _ in services.questions.postChanges(groupID: groupID) {
            await refresh()
        }
    }
}

/// The question card for `groups.screen`'s pager (question.weekly A): the first feed card after the friend cards, for
/// the whole group week. Renders nothing (a zero-size stack) while there is no question for the member.
@MainActor
struct QuestionCardEntry: View {
    @State private var model: QuestionCardModel
    @State private var viewerContext: PhotoViewerContext?
    @Environment(AccountDependencies.self) private var dependencies: AccountDependencies?

    init(groupID: String, model: QuestionCardModel? = nil) {
        _model = State(initialValue: model ?? QuestionCardModel(groupID: GroupID(groupID), services: .shared))
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isVisible, let text = model.text {
                QuestionCard(
                    label: Copy.questionWeeklyCardLabel,
                    question: text,
                    photo: model.newestAnswer?.media?.imagePath(for: .display).map { PhotoSource.storage($0) },
                    hasAnswers: model.newestAnswer != nil,
                    onAnswer: answer,
                    onOpenAnswers: openAnswers,
                    onRemove: { Task { await model.hide() } }
                )
                .padding(.top, Tokens.Sizes.globalSectionGap)
                .dsTransition(.opacity)
            }
        }
        .dsAnimation(ComponentMotion.fade, value: model.isVisible)
        .task(id: PlansServices.shared.revision) { await model.refresh() }
        .task { await model.follow() }
        .socialPhotoViewer($viewerContext)
    }

    /// The button → `camera.capture` for this group with the question as its context (send-to preselects only this
    /// group: the camera's group context).
    private func answer() {
        guard let context = model.cameraContext else { return }
        QuestionCameraContext.shared.prepare(context)
        dependencies?.router.modal = .camera(groupID: model.groupID.rawValue, invitationID: nil)
    }

    /// The card (outside the pill) → `photo.viewer` on the week's answers in this group, oldest first.
    private func openAnswers() {
        let answers = model.answersOldestFirst
        guard let first = answers.first else { return answer() }
        viewerContext = PhotoViewerContext(postIDs: answers.map(\.id), start: first.id, groupID: model.groupID)
    }
}

/// The card's look (question.weekly A, `question.weekly.layout.card`): above the card, in the friend card's name slot,
/// the label `question.weekly.card.label` (text role `listTitle`, `color.global.textPrimary`, no glyph) with
/// `size.global.cardHeaderGap` to the card; the card `size.global.friendCardWidth` × `.friendCardHeight`,
/// `radius.global.card` (continuous). Inside `size.global.screenMargin` at the bottom: the question (text role
/// `displaySmall` in `font.global.displayNarrow`, up to 4 lines), `size.global.pillGap`, then the action.
/// - No answers: fill `color.global.control`, question `color.global.textPrimary`, C-06 primary capsule.
/// - With answers: the newest answer's photo under `layout.global.photoScrim`, question `color.global.textOnMedia`, C-09
///   light pill. No names, no number of answers, no "you answered" mark.
/// One element (button trait) labelled `question.weekly.card.a11y`; with answers a custom action opens them; the
/// context menu's Remove is a custom action too.
struct QuestionCard: View {
    let label: String
    let question: String
    var photo: PhotoSource?
    let hasAnswers: Bool
    let onAnswer: () -> Void
    let onOpenAnswers: () -> Void
    let onRemove: () -> Void

    /// question.weekly A.2: "up to 4 lines, then truncation".
    static let questionLines = 4 // provenance-ok: line count named by the spec

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Sizes.globalCardHeaderGap) {
            Text(label)
                .dsTextStyle(TextRole.listTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .lineLimit(1)
                .frame(minHeight: Tokens.Sizes.globalAvatarList)
            card
        }
        .frame(width: Tokens.Sizes.globalFriendCardWidth, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { hasAnswers ? onOpenAnswers() : onAnswer() }
        .contextMenu {
            Button(Copy.questionWeeklyMenuRemove, action: onRemove)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.questionWeeklyCardA11y(question: question)))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onAnswer() }
        .accessibilityActions {
            if hasAnswers {
                Button(Copy.questionWeeklyCardA11yAnswers, action: onOpenAnswers)
            }
            Button(Copy.questionWeeklyMenuRemove, action: onRemove)
        }
        .accessibilityIdentifier("question.weekly.card")
    }

    private var card: some View {
        ZStack(alignment: .bottomLeading) {
            Tokens.Colors.globalControl
            if hasAnswers {
                PhotoView(source: photo)
                PhotoScrim()
            }
            VStack(alignment: .leading, spacing: Tokens.Sizes.globalPillGap) {
                Text(question)
                    .dsTextStyle(TextRole.displaySmall)
                    .foregroundStyle(hasAnswers ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.globalTextPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(Self.questionLines)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onAnswer) {
                    if hasAnswers {
                        LightPillLabel(Copy.questionWeeklyCardButton)
                    } else {
                        CapsuleLabel(title: Copy.questionWeeklyCardButton, style: .primary)
                    }
                }
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityIdentifier("question.weekly.button")
            }
            .padding(Tokens.Sizes.globalScreenMargin)
        }
        .frame(width: Tokens.Sizes.globalFriendCardWidth, height: Tokens.Sizes.globalFriendCardHeight)
        .clipShape(DSShape.rounded(Tokens.Radii.globalCard))
        .dsAnimation(ComponentMotion.crossfade, value: hasAnswers)
    }
}
