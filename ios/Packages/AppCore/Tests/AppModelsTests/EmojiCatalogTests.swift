@testable import AppModels
import Foundation
import XCTest

/// chat.reactions §3: the picker's Unicode catalog — groups, skin-tone variants under their base, names, search, the
/// device filter — read from the generated file the app bundles (tools/emoji-catalog.mjs).
final class EmojiCatalogTests: XCTestCase {
    private let sample = """
    # comment
    @Smileys & Emotion
    😀\t1.0\tgrinning face
    ❤️\t1.0\tred heart
    @People & Body
    +👋🏻\t1.0\torphan variant is dropped
    👋\t0.6\twaving hand
    +👋🏻\t1.0\twaving hand: light skin tone
    +👋🏿\t1.0\twaving hand: dark skin tone
    🧑‍🤝‍🧑\t12.0\tpeople holding hands
    @Flags
    🇯🇵\t0.6\tflag: Japan
    broken line without tabs
    """

    func testParsesGroupsEntriesAndVariants() {
        let catalog = EmojiCatalog(text: sample)
        XCTAssertEqual(catalog.groups.map(\.name), ["Smileys & Emotion", "People & Body", "Flags"])
        XCTAssertEqual(catalog.groups[0].entries.map(\.base.emoji), ["😀", "❤️"])
        let wave = catalog.groups[1].entries[0]
        XCTAssertEqual(wave.base.emoji, "👋")
        XCTAssertEqual(wave.variants.map(\.emoji), ["👋🏻", "👋🏿"])
        XCTAssertEqual(wave.choices.count, 3)
        XCTAssertEqual(catalog.groups[1].entries[1].base.name, "people holding hands")
        XCTAssertEqual(catalog.groups[2].entries.map(\.base.emoji), ["🇯🇵"])
    }

    func testNamesSearchAndLookup() {
        let catalog = EmojiCatalog(text: sample)
        XCTAssertEqual(catalog.names["👋🏿"], "waving hand: dark skin tone")
        XCTAssertEqual(catalog.names["❤️"], "red heart")
        XCTAssertEqual(catalog.search("HEART").map(\.base.emoji), ["❤️"])
        XCTAssertEqual(catalog.search("japan").map(\.base.emoji), ["🇯🇵"])
        XCTAssertTrue(catalog.search("  ").isEmpty)
        XCTAssertEqual(catalog.entry(containing: "👋🏻")?.base.emoji, "👋")
        XCTAssertNil(catalog.entry(containing: "🦖"))
    }

    func testFilterDropsUnsupportedBasesAndVariants() {
        let catalog = EmojiCatalog(text: sample).filtered { $0 != "😀" && $0 != "👋🏿" }
        XCTAssertEqual(catalog.groups[0].entries.map(\.base.emoji), ["❤️"])
        XCTAssertEqual(catalog.groups[1].entries[0].variants.map(\.emoji), ["👋🏻"])
    }

    /// The bundled file: Unicode's nine non-component groups, ❤️ with its variation selector, skin tones, ZWJ sequences,
    /// flags and keycaps all present.
    func testBundledCatalog() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/EmojiCatalog.txt")
        let catalog = EmojiCatalog(text: try String(contentsOf: url, encoding: .utf8))
        XCTAssertEqual(catalog.groups.map(\.name), [
            "Smileys & Emotion", "People & Body", "Animals & Nature", "Food & Drink", "Travel & Places",
            "Activities", "Objects", "Symbols", "Flags",
        ])
        let names = catalog.names
        XCTAssertGreaterThan(names.count, 3900)
        for emoji in ["❤️", "👋🏽", "🫱🏻‍🫲🏿", "👨‍👩‍👧‍👦", "🏳️‍🌈", "🇺🇳", "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "#️⃣", "1️⃣"] {
            XCTAssertNotNil(names[emoji], emoji)
        }
        XCTAssertEqual(catalog.entry(containing: "👋🏽")?.base.emoji, "👋")
        XCTAssertEqual(catalog.entry(containing: "🧑🏻‍🤝‍🧑🏿")?.variants.count, 25)
    }
}
