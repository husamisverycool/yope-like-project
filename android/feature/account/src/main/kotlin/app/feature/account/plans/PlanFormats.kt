package app.feature.account.plans

import android.icu.text.DateFormat
import android.icu.text.ListFormatter
import android.icu.util.TimeZone
import android.icu.util.ULocale
import app.data.model.NextPlan
import app.data.model.Plan
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Date
import java.util.Locale

/**
 * Plan dates, times and names as the platform writes them (PLATFORM, design/surfaces/plans.page.md → Platform notes): the
 * meta line in the locale's full date + short time (all-day: the date alone), the create sheet's medium date and short
 * time, and first names joined by the ICU list formatter ("Ana, Ben, and Chloe"). Times are the plan's, in the group's
 * time zone. The "today" word for a plan of today is BLOCKED (plans.md §12 item 2): the date is written out instead.
 */
object PlanFormats {
    /** Meta line 1: "Saturday, October 24, 2026 at 7:30 PM"; an all-day plan: "Saturday, October 24, 2026". */
    fun whenLine(startsAt: Instant, allDay: Boolean, zone: ZoneId, locale: Locale = Locale.getDefault()): String {
        val format = if (allDay) {
            DateFormat.getDateInstance(DateFormat.FULL, ULocale.forLocale(locale))
        } else {
            DateFormat.getDateTimeInstance(DateFormat.FULL, DateFormat.SHORT, ULocale.forLocale(locale))
        }
        format.timeZone = TimeZone.getTimeZone(zone.id)
        return format.format(Date.from(startsAt))
    }

    fun whenLine(plan: Plan, zone: ZoneId, locale: Locale = Locale.getDefault()): String = whenLine(plan.startsAt, plan.allDay, zone, locale)

    fun whenLine(plan: NextPlan, zone: ZoneId, locale: Locale = Locale.getDefault()): String = whenLine(plan.startsAt, plan.allDay, zone, locale)

    /**
     * The `groups.screen` plan row's second line (as iOS `PlanFormats.rowLine`): the locale's medium date and short time
     * in the group's zone ("Oct 24, 2026, 6:30 PM"); an all-day plan: its day alone.
     */
    fun rowLine(startsAt: Instant, allDay: Boolean, localDate: LocalDate, zone: ZoneId, locale: Locale = Locale.getDefault()): String {
        if (allDay) return dateValue(localDate, locale)
        val format = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT, ULocale.forLocale(locale))
        format.timeZone = TimeZone.getTimeZone(zone.id)
        return format.format(Date.from(startsAt))
    }

    /** The Date row's value: the locale's medium date ("Oct 24, 2026"). */
    fun dateValue(date: LocalDate, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale).format(date)

    /** The Time row's value: the locale's short time ("7:30 PM"). */
    fun timeValue(time: LocalTime, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale).format(time)

    /** First names joined by the platform list formatter. */
    fun names(names: List<String>, locale: Locale = Locale.getDefault()): String = ListFormatter.getInstance(locale).format(names)
}
