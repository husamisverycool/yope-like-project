// Surface: plans.page — "Add to Calendar" (Apple Invites: "Add an event to the Calendar app: Select an event, then select
// the Add to Calendar button", support.apple.com/guide/apple-invites/view-your-events-dev18a008ffb/ios). The calendar
// app's own new-event screen through `Intent.ACTION_INSERT` on `CalendarContract.Events.CONTENT_URI` (PLATFORM:
// developer.android.com/identity/providers/calendar-provider#intents — "Using the INSERT Intent lets your application
// hand off the event insertion task to the Calendar itself. With this approach, your application doesn't even need to
// have the WRITE_CALENDAR permission"), prefilled with the plan's title, time (or day) and place.
package app.feature.account.plans

import android.content.Intent
import android.provider.CalendarContract
import app.data.model.Plan
import java.time.ZoneId

/** What the new event is filled with: begin and end in epoch milliseconds (end null = the calendar app's own length). */
data class PlanCalendarFields(
    val title: String,
    val beginMillis: Long,
    val endMillis: Long?,
    val allDay: Boolean,
    val location: String?,
) {
    companion object {
        /**
         * [plan] as a new event. All-day: the plan's day from midnight to the next midnight in [zone] (the device's, where
         * the calendar app shows it); timed: its start and, when the server set one, its end.
         */
        fun of(plan: Plan, zone: ZoneId = ZoneId.systemDefault()): PlanCalendarFields {
            val location = plan.place?.takeIf { it.isNotBlank() }
            return if (plan.allDay) {
                PlanCalendarFields(
                    title = plan.title,
                    beginMillis = plan.localDate.atStartOfDay(zone).toInstant().toEpochMilli(),
                    endMillis = plan.localDate.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli(),
                    allDay = true,
                    location = location,
                )
            } else {
                PlanCalendarFields(
                    title = plan.title,
                    beginMillis = plan.startsAt.toEpochMilli(),
                    endMillis = plan.endsAt?.takeIf { it.isAfter(plan.startsAt) }?.toEpochMilli(),
                    allDay = false,
                    location = location,
                )
            }
        }
    }

    /** The insert intent; no permission (the calendar app saves the event). */
    fun intent(): Intent = Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI).apply {
        putExtra(CalendarContract.Events.TITLE, title)
        putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, beginMillis)
        endMillis?.let { putExtra(CalendarContract.EXTRA_EVENT_END_TIME, it) }
        putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, allDay)
        location?.let { putExtra(CalendarContract.Events.EVENT_LOCATION, it) }
    }
}
