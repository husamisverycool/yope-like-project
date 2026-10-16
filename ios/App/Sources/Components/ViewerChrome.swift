// Shared component — C-22 photo / story viewer chrome (design/components.md). Black page in both appearances; header
// row, the photo at full width (native aspect, letterboxed), footer, hairline, comments, reply bar (C-13). Advance by tap
// (Retro: "Tap anywhere to advance", "Tap left to go back"); Retro shows no progress bars. Evidence: TC-2B phone 2
// (header box 1345–1440; '3 of 4' pill; footer; comment field), TC-R3 phone 1 (black viewer under a light sheet);
// RV §2 row 15, §3.8, §4 #15; RP §5.3.
import DesignSystem
import SwiftUI

/// The position pill ('3 of 4' — position only, never a count of views or likes; Retro's red 2023-12 variant is not
/// copied): height `size.global.positionPillHeight`, capsule `color.global.controlOnDeep`, label text role `badge` in
/// `color.global.textOnMedia`. Side inset not measured (Gap) — platform padding. Read with the header.
struct PositionPill: View {
    let label: String

    var body: some View {
        Text(label)
            .dsTextStyle(TextRole.badge)
            .monospacedDigit()
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .lineLimit(1)
            .padding(.horizontal)
            .frame(minHeight: Tokens.Sizes.globalPositionPillHeight)
            .background(Tokens.Colors.globalControlOnDeep, in: Capsule())
    }
}

/// The viewer header: avatar `size.global.avatarHeader` (Retro's white ring with a gap is not drawn — ring width not
/// measured, Gap); name (text role `listTitle`, `color.global.textOnMedia`) over the week (text role `listSubtitle`,
/// `color.global.textSecondary`); optional position pill; close circle (C-11 `.media`, `icon.global.close`) and an
/// optional '•••' circle opening a native menu (Save / Delete / Report; destructive items red). Inset
/// `size.global.screenMargin`; avatar → text spacing not measured (Gap) — platform spacing.
/// Accessibility: avatar, name, week and position read as one element; close and more are labelled buttons.
struct ViewerHeader<MenuContent: View>: View {
    let name: String
    var week: String?
    var avatar: PhotoSource?
    var position: String?
    let closeLabel: String
    let onClose: () -> Void
    var moreLabel: String?
    @ViewBuilder let menu: () -> MenuContent

    init(
        name: String,
        week: String? = nil,
        avatar: PhotoSource?,
        position: String? = nil,
        closeLabel: String,
        onClose: @escaping () -> Void,
        moreLabel: String?,
        @ViewBuilder menu: @escaping () -> MenuContent
    ) {
        self.name = name
        self.week = week
        self.avatar = avatar
        self.position = position
        self.closeLabel = closeLabel
        self.onClose = onClose
        self.moreLabel = moreLabel
        self.menu = menu
    }

    var body: some View {
        HStack {
            HStack {
                AvatarView(source: avatar, diameter: Tokens.Sizes.globalAvatarHeader)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .dsTextStyle(TextRole.listTitle)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    if let week {
                        Text(week)
                            .dsTextStyle(TextRole.listSubtitle)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                if let position {
                    PositionPill(label: position)
                }
            }
            .accessibilityElement(children: .combine)
            if let moreLabel {
                CircleMenu(icon: Tokens.Icons.globalMore, accessibilityLabel: moreLabel, style: .media, content: menu)
            }
            CircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: closeLabel, style: .media, action: onClose)
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

extension ViewerHeader where MenuContent == EmptyView {
    init(name: String, week: String? = nil, avatar: PhotoSource?, position: String? = nil, closeLabel: String, onClose: @escaping () -> Void) {
        self.init(
            name: name, week: week, avatar: avatar, position: position,
            closeLabel: closeLabel, onClose: onClose, moreLabel: nil
        ) { EmptyView() }
    }
}

/// The viewer footer: location (text role `listTitle`, `color.global.textOnMedia`) over the date (text role
/// `listSubtitle`, `color.global.textSecondary`), and a trailing reaction slot (mechanics: Locket reactions — Retro's
/// heart like is not copied). Inset `size.global.screenMargin`.
struct ViewerFooter<Reaction: View>: View {
    var location: String?
    var date: String?
    @ViewBuilder let reaction: () -> Reaction

    init(location: String? = nil, date: String? = nil, @ViewBuilder reaction: @escaping () -> Reaction) {
        self.location = location
        self.date = date
        self.reaction = reaction
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                if let location {
                    Text(location)
                        .dsTextStyle(TextRole.listTitle)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                }
                if let date {
                    Text(date)
                        .dsTextStyle(TextRole.listSubtitle)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            reaction()
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

extension ViewerFooter where Reaction == EmptyView {
    init(location: String? = nil, date: String? = nil) {
        self.init(location: location, date: date) { EmptyView() }
    }
}

/// The viewer's photo: full width at its native aspect (letterboxed on the black page), square corners
/// (`radius.global.photo`). `aspectRatio` is the photo's width ÷ height when known (else the image's own). Accessibility:
/// an image labelled from copy (who, when, place).
struct ViewerPhoto: View {
    let source: PhotoSource?
    var aspectRatio: CGFloat?
    let accessibilityLabel: String

    init(source: PhotoSource?, aspectRatio: CGFloat? = nil, accessibilityLabel: String) {
        self.source = source
        self.aspectRatio = aspectRatio
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        PhotoView(source: source, contentMode: .fit)
            .aspectRatio(aspectRatio ?? imageAspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Tokens.Colors.globalBackgroundDeep)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityAddTraits(.isImage)
    }

    private var imageAspect: CGFloat? {
        guard case let .image(image)? = source, image.size.height > 0 else { return nil }
        return image.size.width / image.size.height
    }
}

/// The viewer page: `color.global.backgroundDeep` in both appearances, header, photo, footer, a hairline
/// (`color.global.separator` in its dark value #4D4D4D, `size.global.hairline`) and the rest (comments, reply bar) from
/// `content`. Open from a card / tile with `ComponentMotion.photoOpen`; advance and close motion were not captured (Gap).
/// Sheets presented over it follow the appearance.
struct ViewerPage<Header: View, Footer: View, Content: View>: View {
    @ViewBuilder let header: () -> Header
    let photo: ViewerPhoto
    @ViewBuilder let footer: () -> Footer
    @ViewBuilder let content: () -> Content

    init(
        @ViewBuilder header: @escaping () -> Header,
        photo: ViewerPhoto,
        @ViewBuilder footer: @escaping () -> Footer,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.header = header
        self.photo = photo
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack {
            header()
            photo
            footer()
            HairlineDivider(color: Tokens.Colors.globalSeparator.darkAppearanceValue)
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
    }
}

extension View {
    /// The viewer's tap navigation: a tap in the leading `previousFraction` of the width goes back, anywhere else
    /// advances ("Tap left to go back", "Tap anywhere to advance"; mirrored right-to-left). The split is a mechanics value
    /// the viewer spec supplies (not measured on Retro — Gap). VoiceOver gets the same as named actions labelled from copy.
    func viewerTapNavigation(
        previousFraction: CGFloat,
        previousLabel: String,
        nextLabel: String,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) -> some View {
        modifier(ViewerTapNavigation(
            previousFraction: previousFraction, previousLabel: previousLabel, nextLabel: nextLabel,
            onPrevious: onPrevious, onNext: onNext
        ))
    }
}

private struct ViewerTapNavigation: ViewModifier {
    let previousFraction: CGFloat
    let previousLabel: String
    let nextLabel: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let fromLeading = layoutDirection == .rightToLeft ? proxy.size.width - location.x : location.x
                            if fromLeading < proxy.size.width * previousFraction {
                                onPrevious()
                            } else {
                                onNext()
                            }
                        }
                }
            }
            .accessibilityAction(named: Text(nextLabel), onNext)
            .accessibilityAction(named: Text(previousLabel), onPrevious)
    }
}
