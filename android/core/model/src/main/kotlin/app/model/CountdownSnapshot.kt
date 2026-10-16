package app.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * What the countdown widget (`widget.countdown`) knows: the upcoming plans of your groups (`next_plans()`, soonest
 * first), written by the app on foreground and after plan changes. The widget only reads it, so it works offline and
 * changes its day count at local midnight without the network. [coverFile] names the plan's downloaded cover in the
 * widget's directory (null: no cover, the group's newest photo or the plain background is used).
 */
@Serializable
data class CountdownSnapshot(val plans: List<CountdownPlan>, val savedAtMillis: Long) {
    fun toJson(): String = json.encodeToString(serializer(), this)

    /**
     * The plan the widget shows on [today] (the device's date): the soonest plan of [groupId] (null = all groups) whose
     * day has not passed. A cancelled plan never appears (`next_plans` leaves it out), so the following one shows.
     */
    fun next(groupId: String?, today: LocalDate): CountdownPlan? =
        plans.firstOrNull { (groupId == null || it.groupId == groupId) && !it.day.isBefore(today) }

    companion object {
        private val json = Json { ignoreUnknownKeys = true; encodeDefaults = false }

        fun fromJson(text: String): CountdownSnapshot? = try {
            json.decodeFromString(serializer(), text)
        } catch (_: Exception) {
            null
        }
    }
}

/** One upcoming plan; [localDate] is the plan's day in its group's time zone (ISO `yyyy-MM-dd`). */
@Serializable
data class CountdownPlan(
    val planId: String,
    val groupId: String,
    val groupName: String,
    val title: String,
    val localDate: String,
    val coverFile: String? = null,
) {
    val day: LocalDate get() = LocalDate.parse(localDate)

    /**
     * Days from [today] (the device's calendar) to the plan's day: calendar dates, not 24-hour spans, so a plan 30 hours
     * away on the day after tomorrow is 2 (`widget.countdown` → The countdown line).
     */
    fun daysFrom(today: LocalDate): Long = ChronoUnit.DAYS.between(today, day)
}
