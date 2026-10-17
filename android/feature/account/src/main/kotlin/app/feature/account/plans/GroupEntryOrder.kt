package app.feature.account.plans

import java.time.LocalDate

/**
 * `groups.screen` — the order of the birthday request rows and the plans block (design/surfaces/plans.list.md "Entry on
 * groups.screen"; MERGE FV-1): date order, soonest first, as Apple Invites' "Upcoming" leads with "your next event"
 * (support.apple.com/guide/apple-invites/view-your-events-dev18a008ffb/ios). As iOS `GroupEntryOrder`.
 */
enum class GroupEntrySlot {
    /** The birthday request rows (`birthday.request` entry). */
    Birthday,

    /** The plans block (the "Plans" label and the plan row). */
    Plans,
}

object GroupEntryOrder {
    /** The slots in their declared order (birthday rows, then plans), as shown before any day is known. */
    val declared: List<GroupEntrySlot> = listOf(GroupEntrySlot.Birthday, GroupEntrySlot.Plans)

    /**
     * Soonest day first: [birthday] is the soonest birthday among the rows, [plans] the next plan's day; an entry without a
     * day goes after every dated one; the same day (or no days) keeps the declared order, so the birthday rows lead.
     */
    fun order(birthday: LocalDate?, plans: LocalDate?): List<GroupEntrySlot> = when {
        birthday != null && plans != null && plans < birthday -> listOf(GroupEntrySlot.Plans, GroupEntrySlot.Birthday)
        birthday == null && plans != null -> listOf(GroupEntrySlot.Plans, GroupEntrySlot.Birthday)
        else -> declared
    }
}
