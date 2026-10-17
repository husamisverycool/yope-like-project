package app.feature.account

import android.content.Intent
import android.provider.CalendarContract
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.Plan
import app.feature.account.plans.PlanCalendarFields
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** plans.page "Add to Calendar": the insert intent's prefilled title, time (or day) and place. */
@RunWith(AndroidJUnit4::class)
class PlanCalendarTest {
    private val start = Instant.parse("2026-10-24T18:30:00Z")
    private val plan = Plan(
        id = "p1", groupId = "g1", createdBy = "u1", title = "Dinner at ours", startsAt = start, endsAt = null,
        allDay = false, localDate = LocalDate.parse("2026-10-24"), place = "Our kitchen", note = null, coverPath = null,
        canceledAt = null, canceledBy = null, createdAt = start, updatedAt = start,
    )

    @Test fun aTimedPlanFillsTitleStartAndPlace() {
        val intent = PlanCalendarFields.of(plan).intent()
        assertEquals(Intent.ACTION_INSERT, intent.action)
        assertEquals(CalendarContract.Events.CONTENT_URI, intent.data)
        assertEquals("Dinner at ours", intent.getStringExtra(CalendarContract.Events.TITLE))
        assertEquals(start.toEpochMilli(), intent.getLongExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, 0))
        assertFalse("no end: the calendar app's own length", intent.hasExtra(CalendarContract.EXTRA_EVENT_END_TIME))
        assertFalse(intent.getBooleanExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, true))
        assertEquals("Our kitchen", intent.getStringExtra(CalendarContract.Events.EVENT_LOCATION))
    }

    @Test fun anAllDayPlanSpansItsDay() {
        val zone = ZoneId.of("Europe/Lisbon")
        val fields = PlanCalendarFields.of(plan.copy(allDay = true, place = null), zone)
        assertTrue(fields.allDay)
        assertNull(fields.location)
        assertEquals(LocalDate.parse("2026-10-24").atStartOfDay(zone).toInstant().toEpochMilli(), fields.beginMillis)
        assertEquals(LocalDate.parse("2026-10-25").atStartOfDay(zone).toInstant().toEpochMilli(), fields.endMillis)
    }
}
