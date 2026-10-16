package app.feature.social.reactions

import android.content.Context
import android.graphics.Paint
import androidx.core.content.edit
import androidx.core.graphics.PaintCompat
import app.designsystem.generated.Tokens

/**
 * The reaction picker's sections (design/surfaces/chat.reactions.md §3): the person's recently used emoji
 * (kept per device, "Frequently Used") and every emoji in the system order (androidx.emoji2 emoji picker data;
 * the first entry of each line is the base emoji).
 */
object EmojiCatalog {
    private const val PREFS = "social_reactions"
    private const val RECENT = "recent"
    private const val SEPARATOR = "\u0000"

    /** How many recently used emoji are kept: one picker row (`chat.reactions.count.pickerColumns`). */
    private val recentMax get() = Tokens.Counts.chatReactionsCountPickerColumns

    fun recent(context: Context): List<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(RECENT, null)?.split(SEPARATOR)?.filter { it.isNotEmpty() }.orEmpty()

    fun remember(context: Context, emoji: String) {
        val list = (listOf(emoji) + recent(context).filter { it != emoji }).take(recentMax)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit { putString(RECENT, list.joinToString(SEPARATOR)) }
    }

    @Volatile private var all: List<String>? = null

    /** Every emoji the device's font can draw, system order (empty when the data cannot be read). */
    fun all(context: Context): List<String> = all ?: synchronized(this) {
        all ?: load(context).also { all = it }
    }

    private fun load(context: Context): List<String> = runCatching {
        val res = context.resources
        // Emoji newer than the system font would draw as tofu: left out, as the platform emoji picker does.
        val paint = Paint()
        val ids = res.obtainTypedArray(androidx.emoji2.emojipicker.R.array.emoji_by_category_raw_resources)
        try {
            (0 until ids.length()).flatMap { i ->
                val id = ids.getResourceId(i, 0)
                if (id == 0) emptyList()
                else res.openRawResource(id).bufferedReader(Charsets.UTF_8).useLines { lines ->
                    lines.mapNotNull { line -> line.split(',').firstOrNull()?.trim()?.takeIf { it.isNotEmpty() } }.toList()
                }
            }.distinct().filter { PaintCompat.hasGlyph(paint, it) }
        } finally {
            ids.recycle()
        }
    }.getOrDefault(emptyList())
}
