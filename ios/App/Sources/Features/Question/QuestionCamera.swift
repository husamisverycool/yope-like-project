// Surface: question.weekly B — answering: the camera opens with the week's question as its context (the question pill
// in the coach pill's slot, BeReal's prompt over the capture screen: design/research/bereal.md §2), and the photo
// posted to the question's group is linked to the question (`answer_question`, docs/API.md §14.4)
// (design/surfaces/question.weekly.md; MERGE WQ-1 … WQ-7).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

/// The camera hand-off of the weekly question.
///
/// The card's button `prepare`s a context and opens the camera for the group (`AppModal.camera`); the camera that then
/// appears for that group `claim`s it (its pill shows the question). The next capture sent to that group from the
/// camera's send-to carries the question in its draft (`answering`, called by `CaptureSendCenter`): the posting layer
/// links the post once it is posted — at once, or when the outbox retries the draft (`PostPublisher`) — and `didPost`
/// ends the context, once; posts to other groups are not answers. The camera's 9 AM mode (camera.overnight) `drop`s it.
/// Any later camera opening claims nothing, so the question never follows the member into an unrelated capture.
@MainActor
@Observable
final class QuestionCameraContext {
    struct Context: Equatable {
        let groupID: String
        let questionID: GroupQuestionID
        /// The question's text (app copy by its key).
        let text: String
    }

    static let shared = QuestionCameraContext()

    /// Prepared by the card, not yet claimed by a camera.
    @ObservationIgnored private var pending: Context?
    /// The context of the camera on screen.
    private(set) var active: Context?

    /// The card's "Add a photo": the next camera opening for `context.groupID` answers the question.
    func prepare(_ context: Context) {
        pending = context
    }

    /// A camera appeared for `groupID` (nil: no group context): it takes the prepared context for its group; any other
    /// camera opening ends an earlier one.
    @discardableResult
    func claim(groupID: String?) -> Context? {
        let prepared = pending
        pending = nil
        guard let prepared, prepared.groupID == groupID else {
            active = nil
            return nil
        }
        active = prepared
        return prepared
    }

    /// The camera switched to 9 AM (camera.overnight: "Switching to 9 AM drops the question context") or closed.
    func drop() {
        pending = nil
        active = nil
    }

    /// A capture about to be sent: when it goes to the active question's group, its draft carries the question
    /// (`questionID`, `questionGroupID`), so its post there becomes an answer (`answer_question`) once posted. Overnight
    /// (9 AM) photos are never answers. The context stays until `didPost` (a failed send tried again still answers).
    func answering(_ draft: PostDraft) -> PostDraft {
        guard let active, draft.overnight != true, draft.groupIDs.contains(GroupID(active.groupID)) else { return draft }
        var answer = draft
        answer.questionID = active.questionID
        answer.questionGroupID = GroupID(active.groupID)
        return answer
    }

    /// A capture was posted: when it answered the active question (the posting layer linked it), the context ends —
    /// once — and the question's card refetches.
    func didPost(_ draft: PostDraft) {
        guard let active, draft.questionID == active.questionID else { return }
        self.active = nil
        PlansServices.shared.didChange()
    }
}

/// The question on the viewfinder (question.weekly B, `question.weekly.layout.cameraPill`): a C-09 pill on media —
/// fill `color.global.controlOnDeep`, text role `pill`, `color.global.textOnMedia`, one line truncated, at most the
/// viewfinder width − 2 × `size.global.screenMargin` — centred in the coach pill's slot, its bottom
/// `camera.sendto.layout.messageField.bottomInset` above the viewfinder's bottom. Not a button; read as
/// `question.weekly.camera.a11y`. Place it as the viewfinder's bottom overlay; it claims the prepared context once, when
/// its camera first appears.
@MainActor
struct QuestionCameraPill: View {
    /// The camera's group context.
    let groupID: String?
    /// The coach pill holds the slot (first use), or the camera is in 9 AM mode.
    var isHidden = false

    @State private var claimed = false
    private var context: QuestionCameraContext { .shared }

    var body: some View {
        ZStack {
            if !isHidden, let active = context.active, active.groupID == groupID {
                QuestionCameraPillLabel(question: active.text)
                    .dsTransition(.opacity)
            }
        }
        .dsAnimation(ComponentMotion.fade, value: context.active)
        .allowsHitTesting(false)
        .onAppear {
            guard !claimed else { return }
            claimed = true
            context.claim(groupID: groupID)
        }
    }
}

/// The pill itself, placed in the viewfinder's bottom slot (also drawn alone by the snapshot tests).
struct QuestionCameraPillLabel: View {
    let question: String

    var body: some View {
        LightPillLabel(question, style: .dark)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .padding(.bottom, Tokens.Layouts.CameraSendtoLayoutMessageField.bottomInset)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Copy.questionWeeklyCameraA11y(question: question)))
            .accessibilityIdentifier("camera.capture.question")
    }
}
