package app.feature.memory.common

/**
 * The last content each memory screen showed, kept in memory for the process so a screen opened
 * again paints at once (no loading state) and refreshes behind it; offline, the cached content
 * stays on screen. Keys carry the signed-in user, so accounts never share entries. The data
 * layer's disk cache covers feeds and chat; these screens' rows are small and change rarely.
 */
class MemoryCache(private val maxEntries: Int = DEFAULT_ENTRIES) {
    private val entries = object : LinkedHashMap<String, Any>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Any>?): Boolean = size > maxEntries
    }

    @Synchronized
    @Suppress("UNCHECKED_CAST")
    fun <T : Any> get(key: String): T? = entries[key] as? T

    @Synchronized
    fun put(key: String, value: Any) {
        entries[key] = value
    }

    @Synchronized
    fun remove(key: String) {
        entries.remove(key)
    }

    companion object {
        private const val DEFAULT_ENTRIES = 64

        /** The app's cache. */
        val shared = MemoryCache()

        /** `<user>/<screen>/<id…>`. */
        fun key(backend: MemoryBackend, vararg parts: String): String = (listOf(backend.currentUserId ?: "-") + parts).joinToString("/")
    }
}
