package app.ui.copy

import android.content.Context

/**
 * The weekly question's text from its copy key (`question.weekly` → Platform notes: "The question text comes from the app's
 * copy (localised) by `question_key`; the server stores only the key"). Keys are `question.weekly.q01` … (the server's
 * check `^question\.weekly\.[a-z0-9]+$`, docs/API.md §14.4); each is a generated string resource named by the key with
 * dots as underscores (`R.string.question_weekly_q01`), so a key added to design/copy/account.json needs no code here.
 * Null for a malformed key or one this app version has no copy for (the card is then left out).
 */
object WeeklyQuestions {
    private val KEY = Regex("^question\\.weekly\\.[a-z0-9]+$")

    fun text(context: Context, key: String): String? {
        if (!KEY.matches(key)) return null
        @Suppress("DiscouragedApi") // the server names the copy by key; resources are looked up by that name
        val id = context.resources.getIdentifier(key.replace('.', '_'), "string", context.packageName)
        return if (id == 0) null else context.getString(id)
    }
}
