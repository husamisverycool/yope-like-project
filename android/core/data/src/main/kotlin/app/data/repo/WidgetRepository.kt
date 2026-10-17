package app.data.repo

import app.data.model.DayMemory
import app.data.model.PersonPhoto
import app.data.model.WidgetPerson
import app.data.remote.Api
import app.data.remote.Rpc
import java.time.LocalDate
import java.time.ZoneId

/**
 * The friend and memories widgets' server functions (migrations 0036, 0038; docs/API.md §6.4; design/surfaces/
 * widget.friend.md, widget.memories.md). The iOS `WidgetRepository`.
 */
class WidgetRepository(private val api: Api) {
    /** Everyone who shares a group with the caller, minus blocks in either direction, by display name. */
    suspend fun people(): List<WidgetPerson> = api.rpcList(Rpc.WidgetPeople, WidgetPerson.serializer())

    /**
     * [userId]'s newest photos the caller may see, newest first ([limit] 1–10): their posts and the photos they tagged
     * themselves in, in groups both share, never across a block; nothing once they share no group.
     */
    suspend fun newestPhotosOf(userId: String, limit: Int = NEWEST_LIMIT): List<PersonPhoto> =
        api.rpcList(Rpc.NewestPhotosOf, PersonPhoto.serializer()) {
            put("p_user_id", userId)
            put("p_limit", limit)
        }

    /** The caller's own memory per day from [from] for [days] days (1–14), the days counted in [zone] (the device's). */
    suspend fun memories(from: LocalDate, days: Int, zone: ZoneId): List<DayMemory> =
        api.rpcList(Rpc.MyMemories, DayMemory.serializer()) {
            put("p_from", from)
            put("p_days", days)
            put("p_time_zone", zone.id)
        }

    companion object {
        /** As iOS `newestPhotos(of:limit:)`: renditions can lag a fresh post, so a few rows to find one that has one. */
        const val NEWEST_LIMIT = 3

        /** Days of memories stored ahead, today included (`widget.memories.layout.content` → days: today and the next 6). */
        const val MEMORY_DAYS = 7
    }
}
