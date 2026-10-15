package app.data.offline

import app.data.error.DataError
import app.data.error.DataException
import app.data.error.ErrorMapping
import app.data.model.DataJson
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import java.io.File
import java.io.FileOutputStream
import java.time.Clock
import java.time.Instant

/**
 * The last loaded page per group / screen, as JSON files, so screens render cached content while
 * offline. One directory per signed-in user (`<root>/<userId>/<key>.json`); everything is deleted
 * on sign-out and account deletion. Writes are atomic (temp file + rename). A file that does not
 * decode (an older app version's shape) reads as absent.
 *
 * Kept in app-private storage, not in a database: pages are small, read whole and replaced whole.
 */
class OfflineCache(private val root: File, private val clock: Clock = Clock.systemUTC()) {

    @Serializable
    private data class Envelope(val version: Int, val savedAtMillis: Long, val data: JsonElement)

    data class Entry<T>(val value: T, val savedAt: Instant)

    private val mutex = Mutex()
    @Volatile private var userId: String? = null

    /** Selects whose cache is read and written; null (signed out) disables the cache. */
    fun setUser(id: String?) {
        userId = id?.takeIf(KEY::matches)
    }

    suspend fun <T> put(key: CacheKey, serializer: KSerializer<T>, value: T) {
        val file = fileFor(key) ?: return
        val envelope = Envelope(VERSION, clock.millis(), DataJson.encodeToJsonElement(serializer, value))
        val bytes = DataJson.encodeToString(Envelope.serializer(), envelope).toByteArray(Charsets.UTF_8)
        mutex.withLock { withContext(Dispatchers.IO) { writeAtomically(file, bytes) } }
    }

    suspend fun <T> get(key: CacheKey, serializer: KSerializer<T>): Entry<T>? {
        val file = fileFor(key) ?: return null
        return mutex.withLock {
            withContext(Dispatchers.IO) {
                if (!file.isFile) return@withContext null
                try {
                    val envelope = DataJson.decodeFromString(Envelope.serializer(), file.readText(Charsets.UTF_8))
                    if (envelope.version != VERSION) null
                    else Entry(DataJson.decodeFromJsonElement(serializer, envelope.data), Instant.ofEpochMilli(envelope.savedAtMillis))
                } catch (_: Exception) {
                    file.delete()
                    null
                }
            }
        }
    }

    /** Read–modify–write of one entry (e.g. drop a deleted post from a cached feed page). */
    suspend fun <T> update(key: CacheKey, serializer: KSerializer<T>, transform: (T) -> T) {
        val current = get(key, serializer) ?: return
        put(key, serializer, transform(current.value))
    }

    suspend fun remove(key: CacheKey) {
        val file = fileFor(key) ?: return
        mutex.withLock { withContext(Dispatchers.IO) { file.delete() } }
    }

    /** Keys stored for the current user that start with [prefix] (e.g. every `feed/`). */
    suspend fun keys(prefix: String = ""): List<CacheKey> {
        val dir = userDir() ?: return emptyList()
        return mutex.withLock {
            withContext(Dispatchers.IO) {
                dir.walkTopDown().filter { it.isFile && it.name.endsWith(EXT) }
                    .map { it.relativeTo(dir).invariantSeparatorsPath.removeSuffix(EXT) }
                    .filter { it.startsWith(prefix) }
                    .map(::CacheKey).toList()
            }
        }
    }

    /** Deletes every user's cache (sign-out / account deletion). */
    suspend fun clearAll() = mutex.withLock { withContext(Dispatchers.IO) { root.deleteRecursively(); Unit } }

    private fun userDir(): File? = userId?.let { File(root, it) }

    private fun fileFor(key: CacheKey): File? = userDir()?.let { File(it, key.value + EXT) }

    private fun writeAtomically(target: File, bytes: ByteArray) {
        target.parentFile?.mkdirs()
        val tmp = File(target.parentFile, ".${target.name}.tmp")
        FileOutputStream(tmp).use { it.write(bytes); it.fd.sync() }
        if (!tmp.renameTo(target)) {
            target.delete()
            tmp.renameTo(target)
        }
    }

    companion object {
        private const val VERSION = 1
        private const val EXT = ".json"
        private val KEY = Regex("[A-Za-z0-9_-]+")
    }
}

/** A cache key: `/`-separated segments of letters, digits, `_` and `-` (ids are UUIDs). */
@JvmInline
value class CacheKey(val value: String) {
    init {
        require(value.isNotEmpty() && value.split('/').all { SEGMENT.matches(it) }) { "invalid cache key" }
    }

    companion object {
        private val SEGMENT = Regex("[A-Za-z0-9_-]+")

        val Groups = CacheKey("groups")
        fun feed(groupId: String) = CacheKey("feed/$groupId")
        fun chat(groupId: String) = CacheKey("chat/$groupId")
        fun members(groupId: String) = CacheKey("members/$groupId")
        fun albums(groupId: String) = CacheKey("albums/$groupId")
        fun history(groupId: String) = CacheKey("history/$groupId")
        fun recaps(groupId: String) = CacheKey("recaps/$groupId")
        fun wall(userId: String) = CacheKey("wall/$userId")
        fun reactions(groupId: String) = CacheKey("reactions/$groupId")
    }
}

/**
 * One emission of a cached screen query: what to render now. Cached content comes first
 * ([source] = [Source.Cache], [refreshing] = true), then the network result, or the cached content
 * again with the [error] (e.g. [DataError.Network]: show the offline state over it).
 */
data class DataState<T>(
    val value: T?,
    val source: Source,
    val savedAt: Instant?,
    val refreshing: Boolean,
    val error: DataError?,
) {
    enum class Source { None, Cache, Network }

    val isOffline: Boolean get() = error == DataError.Network
}

/** Cache-then-network: emits the cached page (if any), fetches, stores, emits the fresh page. */
fun <T> cachedFlow(cache: OfflineCache, key: CacheKey, serializer: KSerializer<T>, clock: Clock = Clock.systemUTC(), fetch: suspend () -> T): Flow<DataState<T>> = flow {
    val cached = cache.get(key, serializer)
    emit(
        if (cached != null) DataState(cached.value, DataState.Source.Cache, cached.savedAt, refreshing = true, error = null)
        else DataState(null, DataState.Source.None, null, refreshing = true, error = null),
    )
    val fresh = try {
        fetch()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Throwable) {
        val error = (e as? DataException)?.error ?: ErrorMapping.map(e)
        emit(DataState(cached?.value, if (cached != null) DataState.Source.Cache else DataState.Source.None, cached?.savedAt, refreshing = false, error = error))
        return@flow
    }
    cache.put(key, serializer, fresh)
    emit(DataState(fresh, DataState.Source.Network, clock.instant(), refreshing = false, error = null))
}
