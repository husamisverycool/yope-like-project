// Surface: tagging — Retro's tagged-people affordances in the media viewer: the footer run (" · with {names}" /
// "Tag friends" → ours "I'm in this") and the "In this photo" sheet (design/surfaces/tagging.md; Retro strings
// `media_viewer_footer_tagged_users_*`, `media_viewer_tagged_user_*`, `media_viewer_view_tagged_users_empty`;
// `references/auto/retro/press/tc-2023-07-retro-2b.jpg` phone 2 footer, `tc-2023-07-retro-1b.webp` people rows).
// Composition of components C-22 (viewer footer line), C-16 (people rows), C-29 (sheet), C-05 / C-06 (capsules),
// C-27 (empty title). The `photo.viewer` pass (social) places the run in its footer's second line (MERGE RM-9):
//
//     TagRunControl(postID: post.id.rawValue, taggedUserIDs: tags, leadingText: dateLine,
//                   onPostGone: { closePhoto() })
//
// or, when the viewer keeps the tag state itself, draws `TagRun` / `TagRunLine` and presents `TaggingSheet`.
import AppData
import DesignSystem
import SwiftUI

/// The run alone: one button, text role `listSubtitle`, one line, tail-truncated — never a count.
///
/// - Nobody tagged: `tagging.toggle` ("I'm in this") in `color.global.textOnMedia` (the tappable part, as Retro's
///   "Tag friends" run) — tapping tags you at once.
/// - Someone tagged: `tagging.with` ("with {names}") in `color.global.textSecondary`, the names in the `listTitle`
///   weight (`fontWeight.global.listTitle`, as Retro sets actor names in grey lines) — tapping opens the sheet.
///
/// Hit area at least `size.global.minTouchTarget.ios` tall. VoiceOver: a button; untagged label `tagging.toggle`, tagged
/// label `tagging.a11y.people` with the run as its value; selected when you are tagged. Taps are ignored while a call
/// runs. The text change cross-fades (`duration.global.crossfade`, `easing.global.standard`).
struct TagRun: View {
    /// Tagged members' first names in tag order (yours included); empty = nobody tagged.
    let names: [String]
    /// You are among them.
    let isTagged: Bool
    var isPending: Bool = false
    let action: () -> Void

    init(names: [String], isTagged: Bool, isPending: Bool = false, action: @escaping () -> Void) {
        self.names = names
        self.isTagged = isTagged
        self.isPending = isPending
        self.action = action
    }

    var body: some View {
        Button {
            guard !isPending else { return }
            action()
        } label: {
            label
                .dsTextStyle(TextRole.listSubtitle)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dsAnimation(ComponentMotion.crossfade, value: names)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(names.isEmpty ? Copy.taggingToggle : Copy.taggingA11yPeople))
        .accessibilityValue(Text(names.isEmpty ? "" : Copy.taggingWith(names: MemoryFormat.names(names))))
        .accessibilityAddTraits(isTagged ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("tagging.run")
    }

    @ViewBuilder
    private var label: some View {
        if names.isEmpty {
            Text(Copy.taggingToggle)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
        } else {
            Self.withNames(names)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
        }
    }

    /// `tagging.with` with each first name in the `listTitle` weight.
    static func withNames(_ names: [String]) -> Text {
        let full = Copy.taggingWith(names: MemoryFormat.names(names))
        var result = Text(verbatim: "")
        var rest = Substring(full)
        // Names in tag order: each one is found after the previous, so a name inside another word earlier on is skipped.
        for name in names where !name.isEmpty {
            guard let range = rest.range(of: name) else { continue }
            let before = Text(verbatim: String(rest[..<range.lowerBound]))
            let emphasis = Text(verbatim: String(rest[range])).fontWeight(Tokens.FontWeights.fontWeightGlobalListTitle)
            result = Text("\(result)\(before)\(emphasis)") // provenance-ok: concatenates copy and data, no literal text
            rest = rest[range.upperBound...]
        }
        return Text("\(result)\(Text(verbatim: String(rest)))") // provenance-ok: concatenates copy and data, no literal text
    }
}

/// The viewer footer's second line with the run: the leading text (the date, text role `listSubtitle`,
/// `color.global.textSecondary`), Retro's separator " · " and the run. The date keeps its width; the run truncates.
struct TagRunLine: View {
    let leadingText: String?
    let run: TagRun

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let leadingText {
                // Retro's footer separator (`media_viewer_footer_tagged_users_divider` " · with "), punctuation only.
                Text(verbatim: leadingText + " · ") // provenance-ok: Retro's separator punctuation between the date and the run
                    .dsTextStyle(TextRole.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            run
        }
    }
}

/// A row of the "In this photo" sheet.
struct TaggingSheetPerson: Identifiable, Equatable {
    let id: String
    let firstName: String
    var avatar: PhotoSource?
    /// Your own row carries "Remove tag".
    var isMe: Bool

    init(id: String, firstName: String, avatar: PhotoSource?, isMe: Bool) {
        self.id = id
        self.firstName = firstName
        self.avatar = avatar
        self.isMe = isMe
    }
}

/// B. "In this photo" (C-29 page sheet, medium detent, follows the appearance): sheet header `tagging.sheet.title` with
/// the C-11 close circle on the page; people rows (C-16: avatar `size.global.avatarPicker`, first name text role
/// `listTitle`, `size.global.screenMargin` margins) — your row with the outline medium capsule (C-06)
/// `tagging.remove`; empty: the C-27 title `tagging.sheet.empty`; when you are not tagged, the primary capsule (C-05)
/// `tagging.toggle` at the bottom (`size.global.buttonMarginH`). Rows appear and leave with `duration.global.fade`.
/// Present it with `.sheet { … }.presentationDetents([.medium]).dsSheetBackground()`.
struct TaggingSheet: View {
    let people: [TaggingSheetPerson]
    let isTagged: Bool
    var isPending: Bool = false
    let onRemove: () -> Void
    let onTag: () -> Void
    let onClose: () -> Void

    init(
        people: [TaggingSheetPerson],
        isTagged: Bool,
        isPending: Bool = false,
        onRemove: @escaping () -> Void,
        onTag: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.people = people
        self.isTagged = isTagged
        self.isPending = isPending
        self.onRemove = onRemove
        self.onTag = onTag
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: Copy.taggingSheetTitle, closeAccessibilityLabel: Copy.photoViewerA11yClose, onClose: onClose)
            if people.isEmpty {
                EmptyStateView(title: Copy.taggingSheetEmpty)
                    .frame(maxHeight: .infinity)
                    .dsTransition(.opacity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Tokens.Sizes.globalListGap) {
                        ForEach(people) { person in
                            PeopleRow(name: person.firstName, avatar: person.avatar) {
                                if person.isMe {
                                    CapsuleButton(Copy.taggingRemove, style: .outline, isEnabled: !isPending, action: onRemove)
                                        .accessibilityIdentifier("tagging.remove")
                                }
                            }
                            .dsTransition(.opacity)
                        }
                    }
                    .padding(.top, Tokens.Sizes.globalListGap)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            if !isTagged {
                PrimaryButton(Copy.taggingToggle, height: .sheet, isEnabled: !isPending, action: onTag)
                    .padding(.horizontal, Tokens.Sizes.globalButtonMarginHSheet)
                    .accessibilityIdentifier("tagging.sheet.tag")
            }
        }
        .padding(.top, Tokens.Sizes.globalScreenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .dsAnimation(ComponentMotion.fade, value: people.map(\.id))
        .accessibilityIdentifier("tagging.sheet")
    }
}

/// The run with its own state: reads and writes your tag (`tag_self` / `untag_self`, optimistic, one call at a time,
/// reverted on failure — `haptic.global.select` when applied, `haptic.global.error` on failure, the failure announced
/// via C-26) and presents the sheet when someone is tagged. Not for collages.
///
/// - Parameters:
///   - taggedUserIDs: the post's tags in tag order from the host's `post_tags` read; nil = the control reads them.
///   - leadingText: the footer line's date, drawn before Retro's " · " separator (nil: the run alone).
///   - onMessage: the failure line (`tagging.error`, `.removeError`, `.notFound`, `.offline`) for the host.
///   - onPostGone: the photo no longer exists (`post_not_found`): the viewer closes it.
///   - onChange: your tag state after each change (optimistic while the call runs).
@MainActor
struct TagRunControl: View {
    @State private var model: TagRunModel
    @State private var showsSheet = false
    @State private var sheetScheme: ColorScheme = .light
    private let leadingText: String?
    private let onMessage: ((String) -> Void)?
    private let onPostGone: (() -> Void)?
    private let onChange: ((Bool) -> Void)?

    init(
        postID: String,
        taggedUserIDs: [String]? = nil,
        leadingText: String? = nil,
        model: TagRunModel? = nil,
        onMessage: ((String) -> Void)? = nil,
        onPostGone: (() -> Void)? = nil,
        onChange: ((Bool) -> Void)? = nil
    ) {
        _model = State(initialValue: model ?? TagRunModel(
            postID: PostID(postID), taggedUserIDs: taggedUserIDs?.map { UserID($0) }, dependencies: .current
        ))
        self.leadingText = leadingText
        self.onMessage = onMessage
        self.onPostGone = onPostGone
        self.onChange = onChange
    }

    var body: some View {
        MemoryImageScope { images in
            TagRunLine(
                leadingText: leadingText,
                run: TagRun(names: model.people.map(\.firstName), isTagged: model.isTagged, isPending: model.isPending) {
                    if model.people.isEmpty {
                        Task { await model.tag() }
                    } else {
                        sheetScheme = SystemAppearance.colorScheme
                        showsSheet = true
                    }
                }
            )
            .disabled(!model.isKnown)
            .sheet(isPresented: $showsSheet) {
                TaggingSheet(
                    people: model.people.map { person in
                        TaggingSheetPerson(
                            id: person.id.rawValue, firstName: person.firstName,
                            avatar: images.source(person.avatarURL), isMe: person.id == model.me?.id
                        )
                    },
                    isTagged: model.isTagged,
                    isPending: model.isPending,
                    onRemove: { Task { await model.untag() } },
                    onTag: { Task { await model.tag() } },
                    onClose: { showsSheet = false }
                )
                .presentationDetents([.medium])
                .dsSheetBackground()
                .environment(\.colorScheme, sheetScheme)
            }
        }
        .task { await model.load() }
        .onChange(of: model.isTagged) { _, value in onChange?(value) }
        .onChange(of: model.message) { _, message in
            if let message { onMessage?(message.text) }
        }
        .onChange(of: model.isGone) { _, gone in
            if gone {
                showsSheet = false
                onPostGone?()
            }
        }
    }
}

// MARK: - Yope-era signature (the photo.viewer pass replaces the call site)

/// The Yope-era white "i'm in this" capsule is gone (tagging.md, MERGE RM-9): this draws the Retro run in its untagged /
/// tagged-by-you look from the host's on / off state, so the viewer keeps compiling until it hosts `TagRunControl` or
/// `TagRun` with the tagged names.
@available(*, deprecated, message: "Retro's tag run: TagRunControl (or TagRun + TaggingSheet) in the viewer footer's second line")
struct SelfTagToggleControl: View {
    let isOn: Bool
    var isPending = false
    var showsCoach = false
    let onToggle: () -> Void
    var onDismissCoach: () -> Void = {}

    var body: some View {
        TagRun(names: [], isTagged: isOn, isPending: isPending, action: onToggle)
    }
}
