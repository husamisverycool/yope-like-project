package app.feature.social

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.feature.social.common.EmojiNames
import app.feature.social.reactions.EmojiCatalog
import app.feature.social.reactions.EmojiCatalogData
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** chat.reactions §3: the picker's Unicode catalog — groups, skin tones under their base, names, search, device filter. */
@RunWith(AndroidJUnit4::class)
class EmojiCatalogTest {
    private val sample = listOf(
        "# comment",
        "@Smileys & Emotion",
        "😀\t1.0\tgrinning face",
        "❤️\t1.0\tred heart",
        "@People & Body",
        "+👋🏻\t1.0\torphan variant is dropped",
        "👋\t0.6\twaving hand",
        "+👋🏻\t1.0\twaving hand: light skin tone",
        "+👋🏿\t1.0\twaving hand: dark skin tone",
        "@Flags",
        "🇯🇵\t0.6\tflag: Japan",
        "broken line",
    ).joinToString("\n")

    @Test fun parsesGroupsEntriesAndVariants() {
        val catalog = EmojiCatalogData.parse(sample)
        assertEquals(listOf("Smileys & Emotion", "People & Body", "Flags"), catalog.groups.map { it.name })
        assertEquals(listOf("😀", "❤️"), catalog.groups[0].entries.map { it.base.emoji })
        val wave = catalog.groups[1].entries.single()
        assertEquals(listOf("👋🏻", "👋🏿"), wave.variants.map { it.emoji })
        assertEquals(3, wave.choices.size)
        assertEquals("waving hand: dark skin tone", catalog.names["👋🏿"])
        assertEquals(listOf("❤️"), catalog.search("HEART").map { it.base.emoji })
        assertEquals("👋", catalog.entryContaining("👋🏻")?.base?.emoji)
        assertNull(catalog.entryContaining("🦖"))
        val filtered = catalog.filtered { it != "😀" && it != "👋🏿" }
        assertEquals(listOf("❤️"), filtered.groups[0].entries.map { it.base.emoji })
        assertEquals(listOf("👋🏻"), filtered.groups[1].entries.single().variants.map { it.emoji })
    }

    /** The bundled raw resource: Unicode's nine groups; ❤️, skin tones, ZWJ sequences, flags, keycaps; CLDR names spoken. */
    @Test fun bundledCatalog() {
        val catalog = EmojiCatalog.bundled(ApplicationProvider.getApplicationContext())
        assertEquals(
            listOf("Smileys & Emotion", "People & Body", "Animals & Nature", "Food & Drink", "Travel & Places", "Activities", "Objects", "Symbols", "Flags"),
            catalog.groups.map { it.name },
        )
        assertTrue(catalog.names.size > 3900)
        for (emoji in listOf("❤️", "👋🏽", "🫱🏻‍🫲🏿", "👨‍👩‍👧‍👦", "🏳️‍🌈", "🇺🇳", "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "#️⃣")) assertNotNull(emoji, catalog.names[emoji])
        assertEquals(25, catalog.entryContaining("🧑🏻‍🤝‍🧑🏿")?.variants?.size)
        assertEquals("flag: Japan", EmojiNames.name("🇯🇵"))
    }
}
