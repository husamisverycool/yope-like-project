package app.data.media

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Clock
import java.time.Instant
import kotlin.time.Duration
import kotlin.time.Duration.Companion.hours
import kotlin.time.Duration.Companion.minutes
import kotlin.time.toJavaDuration

/**
 * Signed read URLs, cached until shortly before they expire. Files are private and read only
 * through short-lived signed URLs (docs/API.md §1, §7: 1 h for the app and widgets). Re-signing
 * the same path within its lifetime returns the cached URL, so image caches keyed by URL keep
 * hitting. Paths the caller cannot read are never cached (a later grant, e.g. joining, works).
 */
class SignedUrlCache(
    private val signer: UrlSigner,
    private val clock: Clock = Clock.systemUTC(),
    private val ttl: Duration = 1.hours,
    /** A URL is refreshed once less than this is left, so a consumer always gets a usable one. */
    private val refreshMargin: Duration = 5.minutes,
    private val maxEntries: Int = 2_000,
) {
    data class Entry(val url: String, val expiresAt: Instant)

    private val mutex = Mutex()
    private val entries = object : LinkedHashMap<String, Entry>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Entry>?): Boolean = size > maxEntries
    }

    /** The URL for [path], or null when the caller cannot read it. */
    suspend fun url(path: String): String? = urls(listOf(path))[path]

    /** URLs for [paths] (unreadable ones absent). Only the missing / expiring ones are signed. */
    suspend fun urls(paths: Collection<String>): Map<String, String> {
        val wanted = paths.distinct()
        val now = clock.instant()
        val fresh = mutex.withLock {
            wanted.mapNotNull { path -> entries[path]?.takeIf { it.isUsable(now) }?.let { path to it.url } }.toMap()
        }
        val missing = wanted.filter { it !in fresh }
        if (missing.isEmpty()) return fresh
        val signedAt = clock.instant()
        val signed = signer.sign(missing, ttl)
        val expiresAt = signedAt.plus(ttl.toJavaDuration())
        mutex.withLock { signed.forEach { (path, url) -> entries[path] = Entry(url, expiresAt) } }
        return wanted.mapNotNull { path -> (fresh[path] ?: signed[path])?.let { path to it } }.toMap()
    }

    /** Drops [path] (e.g. after `post_deleted`: its objects are gone). */
    suspend fun invalidate(path: String) = mutex.withLock { entries.remove(path); Unit }

    suspend fun invalidatePrefix(prefix: String) = mutex.withLock { entries.keys.removeAll { it.startsWith(prefix) }; Unit }

    /** On sign-out. */
    suspend fun clear() = mutex.withLock { entries.clear() }

    internal suspend fun peek(path: String): Entry? = mutex.withLock { entries[path] }

    private fun Entry.isUsable(now: Instant): Boolean = now.plus(refreshMargin.toJavaDuration()).isBefore(expiresAt)
}
