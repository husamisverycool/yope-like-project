@file:UseSerializers(InstantSerializer::class, LocalDateSerializer::class)

package app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant
import java.time.LocalDate

/**
 * One row of `group_tributes` (docs/API.md §6.4, migration 0034): a delivered, ready birthday video of the group you may
 * watch — your own ([forMe]) or one you contributed to (VidDay: shared with the contributors after it is given). Newest
 * delivery first. The group screen's birthday video cards.
 */
@Serializable
data class GroupTribute(
    val id: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("honoree_id") val honoreeId: String,
    /** The title card frame (`g/<group_id>/tributes/<id>/…`). */
    @SerialName("poster_path") val posterPath: String?,
    /** The birthday (group-local day). */
    @SerialName("birthday_date") val birthdayDate: LocalDate,
    @SerialName("delivered_at") val deliveredAt: Instant,
    @SerialName("for_me") val forMe: Boolean,
)
