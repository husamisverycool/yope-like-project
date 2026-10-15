package app.data

import app.data.error.DataError
import app.data.error.DataException
import app.data.media.SignedUrlCache
import app.data.media.StoragePaths
import app.data.media.UrlSigner
import app.data.model.Post
import app.data.offline.CacheKey
import app.data.offline.DataState
import app.data.offline.OfflineCache
import app.data.offline.cachedFlow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlin.time.Duration
import kotlin.time.Duration.Companion.hours
import kotlin.time.Duration.Companion.minutes

/** Signed URL cache, offline page cache and cache-then-network flows; storage path rules. */
class CachingTest {
    @get:Rule val tmp = TemporaryFolder()

    private class MutableClock(var now: Instant) : Clock() {
        override fun getZone() = ZoneOffset.UTC
        override fun withZone(zone: java.time.ZoneId?) = this
        override fun instant() = now
    }

    private class CountingSigner(private val readable: (String) -> Boolean = { true }) : UrlSigner {
        val calls = mutableListOf<List<String>>()
        var serial = 0
        override suspend fun sign(paths: List<String>, ttl: Duration): Map<String, String> {
            calls += paths
            return paths.filter(readable).associateWith { "https://s/$it?token=${++serial}&ttl=${ttl.inWholeSeconds}" }
        }
    }

    @Test fun signedUrlsAreReusedUntilShortlyBeforeTheyExpire() = runBlocking {
        val clock = MutableClock(Instant.parse("2026-10-15T12:00:00Z"))
        val signer = CountingSigner()
        val cache = SignedUrlCache(signer, clock, ttl = 1.hours, refreshMargin = 5.minutes)
        val first = cache.url("u/a/m/original.jpg")!!
        assertTrue(first.endsWith("ttl=3600"))
        clock.now = clock.now.plusSeconds(54 * 60)
        assertEquals(first, cache.url("u/a/m/original.jpg"))
        assertEquals(1, signer.calls.size)
        clock.now = clock.now.plusSeconds(60 + 1) // 55 min + 1 s: inside the 5-minute margin
        assertNotEquals(first, cache.url("u/a/m/original.jpg"))
        assertEquals(2, signer.calls.size)
    }

    @Test fun batchSigningAsksOnlyForMissingPathsAndNeverCachesUnreadableOnes() = runBlocking {
        val signer = CountingSigner(readable = { !it.contains("hidden") })
        val cache = SignedUrlCache(signer, Clock.systemUTC())
        cache.url("a.jpg")
        val urls = cache.urls(listOf("a.jpg", "b.jpg", "hidden.jpg", "b.jpg"))
        assertEquals(setOf("a.jpg", "b.jpg"), urls.keys)
        assertEquals(listOf(listOf("a.jpg"), listOf("b.jpg", "hidden.jpg")), signer.calls)
        assertNull(cache.url("hidden.jpg"))
        assertEquals(listOf("hidden.jpg"), signer.calls.last()) // asked again: a later grant may allow it
        cache.invalidate("a.jpg")
        cache.url("a.jpg")
        assertEquals(listOf("a.jpg"), signer.calls.last())
        cache.clear()
        cache.url("b.jpg")
        assertEquals(listOf("b.jpg"), signer.calls.last())
    }

    private fun post(id: String, at: Long) = Post(id, "m$id", "g", "u", null, null, null, null, false, null, Instant.ofEpochSecond(at))

    @Test fun offlineCacheIsPerUserAtomicAndClearedOnSignOut() = runBlocking {
        val cache = OfflineCache(tmp.root)
        val posts = ListSerializer(Post.serializer())
        val key = CacheKey.feed("g")
        cache.put(key, posts, listOf(post("1", 1))) // signed out: nothing stored
        assertNull(cache.get(key, posts))
        cache.setUser("user-a")
        cache.put(key, posts, listOf(post("1", 1), post("2", 2)))
        assertEquals(listOf("1", "2"), cache.get(key, posts)!!.value.map { it.id })
        cache.update(key, posts) { list -> list.filterNot { it.id == "1" } }
        assertEquals(listOf("2"), cache.get(key, posts)!!.value.map { it.id })
        assertEquals(listOf(key), cache.keys("feed/"))
        cache.setUser("user-b")
        assertNull(cache.get(key, posts)) // another person's cache is invisible
        cache.setUser("user-a")
        // A file that does not decode reads as absent and is removed.
        File(tmp.root, "user-a/feed/g.json").writeText("{not json")
        assertNull(cache.get(key, posts))
        assertFalse(File(tmp.root, "user-a/feed/g.json").exists())
        cache.put(key, posts, listOf(post("3", 3)))
        cache.clearAll()
        assertNull(cache.get(key, posts))
        assertThrows(IllegalArgumentException::class.java) { CacheKey("../escape") }
        Unit
    }

    @Test fun cachedFlowEmitsCacheThenNetworkAndKeepsCacheWhenOffline() = runBlocking {
        val clock = MutableClock(Instant.parse("2026-10-15T12:00:00Z"))
        val cache = OfflineCache(tmp.root, clock).apply { setUser("u") }
        val key = CacheKey.Groups
        val ids = ListSerializer(String.serializer())

        val firstLoad = cachedFlow(cache, key, ids, clock) { listOf("g1") }.toList()
        assertEquals(listOf(DataState.Source.None, DataState.Source.Network), firstLoad.map { it.source })
        assertTrue(firstLoad.first().refreshing)
        assertEquals(listOf("g1"), firstLoad.last().value)

        val offline = cachedFlow(cache, key, ids, clock) { throw DataException(DataError.Network) }.toList()
        assertEquals(listOf(DataState.Source.Cache, DataState.Source.Cache), offline.map { it.source })
        assertEquals(listOf("g1"), offline.last().value)
        assertTrue(offline.last().isOffline)
        assertFalse(offline.last().refreshing)
        assertEquals(clock.now, offline.last().savedAt)

        val nothingCached = cachedFlow(cache, CacheKey.chat("g9"), ids, clock) { throw DataException(DataError.NotSignedIn) }.toList()
        assertEquals(DataError.NotSignedIn, nothingCached.last().error)
        assertNull(nothingCached.last().value)
    }

    @Test fun storagePathsFollowTheConventions() {
        val uid = "9f0c2b7e-1111-4111-8111-111111111111"
        val media = "1c2d3e4f-2222-4222-8222-222222222222"
        assertEquals("u/$uid/$media/original.jpg", StoragePaths.original(uid, media, "JPG"))
        assertEquals("u/$uid/$media/front.jpg", StoragePaths.front(uid, media))
        assertEquals("u/$uid/$media/motion.mov", StoragePaths.motion(uid, media))
        assertEquals("u/$uid/$media/motion.mp4", StoragePaths.motion(uid, media, "mp4"))
        assertEquals("u/$uid/$media/voice.m4a", StoragePaths.postVoice(uid, media))
        assertEquals("u/$uid/voice/$media.m4a", StoragePaths.chatVoice(uid, media))
        assertEquals("u/$uid/covers/$media.jpg", StoragePaths.cover(uid, media))
        assertEquals("avatars/$uid/$media.jpg", StoragePaths.avatar(uid, media))
        assertTrue(StoragePaths.isSafe("u/$uid/$media/r/thumb_1.jpg"))
        assertFalse(StoragePaths.isSafe("u/$uid/../x.jpg"))
        assertFalse(StoragePaths.isSafe("u//x.jpg"))
        assertFalse(StoragePaths.isSafe("u/x y.jpg"))
        assertThrows(IllegalArgumentException::class.java) { StoragePaths.original("../$uid", media, "jpg") }
        assertEquals("video/quicktime", StoragePaths.contentTypeFor("mov"))
        assertEquals("audio/mp4", StoragePaths.contentTypeFor("m4a"))
        assertTrue(StoragePaths.ALLOWED_CONTENT_TYPES.containsAll(listOf("image/jpeg", "video/mp4", "audio/mp4")))
    }
}
