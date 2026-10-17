package app.data.model

/**
 * The batch a photo belongs to (migration 0051, docs/API.md `posts.batch_id`): the same author and the same `batch_id`.
 * The composer gives every photo of one selection the same id; each photo stays its own post. uuids compare without
 * regard to case.
 */
class PhotoBatchKey(val authorId: String, batchId: String) {
    val batchId: String = batchId.lowercase()

    override fun equals(other: Any?): Boolean = other is PhotoBatchKey && other.authorId == authorId && other.batchId == batchId
    override fun hashCode(): Int = 31 * authorId.hashCode() + batchId.hashCode()
    override fun toString(): String = "PhotoBatchKey($authorId, $batchId)"
}

/** The photo's batch; null for a photo posted alone. */
val Post.batchKey: PhotoBatchKey? get() = batchId?.let { PhotoBatchKey(authorId, it) }

/**
 * Where a photo stands among the photos of its batch (the viewer's page dots, `photo.viewer.layout.batchDots`): 1-based
 * [index] of [total]. Positions, never a count shown as a number.
 */
data class PhotoBatchPosition(val index: Int, val total: Int)

/**
 * `layout.global.photoBatch`: how the apps show several photos posted together — one chat run item, one strip tile, the
 * viewer's pages side by side in the order they were posted. Pure functions; every surface uses these.
 */
object PhotoBatches {
    /**
     * Splits [items] (already in `created_at` order) into runs: consecutive items with the same non-null key are one run;
     * every other item is a run of its own. A photo of the batch that is gone leaves the rest together; anything else
     * between two photos of a batch (another message, someone else's photo) splits it into two runs. Order is kept.
     */
    fun <T> runs(items: List<T>, key: (T) -> PhotoBatchKey?): List<List<T>> {
        val result = ArrayList<MutableList<T>>()
        var previous: PhotoBatchKey? = null
        for (item in items) {
            val current = key(item)
            if (current != null && current == previous && result.isNotEmpty()) result.last().add(item) else result.add(mutableListOf(item))
            previous = current
        }
        return result
    }

    /**
     * [ids] with the members of one batch ([batch], in `created_at` order) side by side in that order, where the first of
     * them stood; ids of the batch that [ids] does not hold are not added. Fewer than two members: [ids] unchanged.
     */
    fun <T> gather(ids: List<T>, batch: List<T>): List<T> {
        val members = members(ids, batch)
        if (members.size < 2) return ids
        val memberSet = members.toSet()
        val first = ids.indexOfFirst { it in memberSet }
        if (first < 0) return ids
        return ids.subList(0, first) + members + ids.subList(first, ids.size).filter { it !in memberSet }
    }

    /** The position of [id] among the members of [batch] that [ids] holds, in batch order; null when it is not one or fewer than two are there. */
    fun <T> position(id: T, ids: List<T>, batch: List<T>): PhotoBatchPosition? {
        val members = members(ids, batch)
        val index = members.indexOf(id)
        if (members.size < 2 || index < 0) return null
        return PhotoBatchPosition(index + 1, members.size)
    }

    private fun <T> members(ids: List<T>, batch: List<T>): List<T> {
        val present = ids.toSet()
        return batch.filter { it in present }.distinct()
    }
}
