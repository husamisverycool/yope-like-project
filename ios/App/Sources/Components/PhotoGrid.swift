// Shared component — C-21 grids (design/components.md): the album photo grid (dated sections of square cells), the
// composer picker grid, and the people grid. The profile / history week list is `WeekSectionList` of `WeekStripSection`s
// (SectionHeader.swift). Evidence: TC-J1 (row y=1950 white run x2751–2754), VID-COMP, TC-1B (avatars (1391–1569),
// (1666–1843)); RV §3.4, §3.5, §3.8, §4 #24.
//
// Column counts (album 3, composer 4, people 3) and the people grid's 125 pt column pitch are in design/components.md
// but have no global tokens yet — callers pass the count from their surface's tokens.
import DesignSystem
import SwiftUI

/// One cell of a photo grid.
struct PhotoGridItem: Identifiable, Hashable {
    let id: String
    var source: PhotoSource?
    /// From copy: the date / person the cell shows.
    let accessibilityLabel: String

    init(id: String, source: PhotoSource?, accessibilityLabel: String) {
        self.id = id
        self.source = source
        self.accessibilityLabel = accessibilityLabel
    }
}

/// A grid of square photo cells (`radius.global.photo` square corners), `size.global.stripGap` apart in both
/// directions, full width inside the margins (`size.global.screenMargin`, applied here): the album grid (3 columns,
/// TC-J1) and the composer picker (4 columns, VID-COMP — its 1–2 pt gap read as `size.global.stripGap`).
/// Pressed: platform default. Accessibility: each cell is a button labelled from copy; the grid is a list container.
struct PhotoGrid: View {
    let items: [PhotoGridItem]
    let columns: Int
    var onSelect: (PhotoGridItem) -> Void = { _ in }

    init(items: [PhotoGridItem], columns: Int, onSelect: @escaping (PhotoGridItem) -> Void = { _ in }) {
        self.items = items
        self.columns = columns
        self.onSelect = onSelect
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Sizes.globalStripGap), count: max(1, columns)),
            spacing: Tokens.Sizes.globalStripGap
        ) {
            ForEach(items) { item in
                Button {
                    onSelect(item)
                } label: {
                    PhotoView(source: item.source)
                        .aspectRatio(1, contentMode: .fit) // provenance-ok: square cells (C-21)
                        .clipShape(Rectangle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.accessibilityLabel))
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .contain)
    }
}

/// A dated section of the album grid: the C-20 header in its dated variant ('January 25, 2024' + '•••'), then the
/// grid `size.global.sectionHeaderToContent` below the header's baseline.
struct DatedPhotoSection<MenuContent: View>: View {
    let header: SectionHeader<MenuContent>
    let grid: PhotoGrid

    var body: some View {
        WeekStripSection {
            header
        } content: {
            grid
        }
    }
}

/// One person of the people grid.
struct PeopleGridItem: Identifiable {
    let id: String
    let name: String
    var avatar: PhotoSource?

    init(id: String, name: String, avatar: PhotoSource?) {
        self.id = id
        self.name = name
        self.avatar = avatar
    }
}

/// The people grid (Retro Friends, TC-1B 2023): `columns` columns of `size.global.avatarGrid` avatars with the name
/// (text role `listTitle`, `color.global.textPrimary`) centred below; columns share the width inside
/// `size.global.screenMargin` (Retro's 125 pt pitch has no token — Gap); vertical spacing is the platform's (not
/// measured). Accessibility: each person is a button labelled with the name.
struct PeopleGrid: View {
    let people: [PeopleGridItem]
    let columns: Int
    var onSelect: (PeopleGridItem) -> Void = { _ in }

    init(people: [PeopleGridItem], columns: Int, onSelect: @escaping (PeopleGridItem) -> Void = { _ in }) {
        self.people = people
        self.columns = columns
        self.onSelect = onSelect
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: max(1, columns))) {
            ForEach(people) { person in
                Button {
                    onSelect(person)
                } label: {
                    VStack {
                        AvatarView(source: person.avatar, diameter: Tokens.Sizes.globalAvatarGrid)
                        Text(person.name)
                            .dsTextStyle(TextRole.listTitle)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(person.name))
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}
