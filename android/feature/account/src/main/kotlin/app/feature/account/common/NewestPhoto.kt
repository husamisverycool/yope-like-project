package app.feature.account.common

import app.data.model.Media
import app.feature.account.AccountEnvironment
import kotlinx.coroutines.flow.first

/** The newest photo across the person's groups (display rendition, signed) and its sender's first name. */
data class NewestPhoto(val url: String?, val firstName: String?)

/**
 * Reads the newest post across the person's groups (cached list first) — the onboarding.widget preview and the paywall's
 * media card / backdrop ("the person's newest group photo", MERGE RA-18). Null when there is none or the read fails.
 */
suspend fun newestGroupPhoto(env: AccountEnvironment): NewestPhoto? = runCatching {
    val groups = env.backend.observeMyGroups().first { it.value != null || !it.refreshing }.value.orEmpty()
    val newest = groups.mapNotNull { g -> runCatching { env.backend.newestPost(g.id) }.getOrNull() }.maxByOrNull { it.createdAt } ?: return@runCatching null
    val media = env.backend.media(listOf(newest.mediaId)).firstOrNull() ?: return@runCatching null
    val path = media.imagePath(Media.Rendition.Display)
    val url = env.backend.signedUrls(listOf(path))[path]
    val name = env.backend.profiles(listOf(newest.authorId)).firstOrNull()?.firstName
    NewestPhoto(url, name)
}.getOrNull()
