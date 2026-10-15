package app.data.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * JSON for everything the data layer reads and writes. Unknown keys are ignored so an app build
 * keeps working when the backend adds a column; `SchemaConformanceIntegrationTest` checks that the
 * models mirror the live tables exactly.
 */
val DataJson: Json = Json {
    ignoreUnknownKeys = true
    explicitNulls = true
    encodeDefaults = true
    coerceInputValues = false
}

/**
 * `timestamptz` (docs/API.md §1): ISO-8601 with an offset, e.g. `2026-10-15T13:35:09.329469+00:00`.
 * Also accepts the variants Realtime and Postgres text output produce (`+00` offsets, a space
 * instead of `T`, `Z`). Written as UTC with `Z`.
 */
object InstantSerializer : KSerializer<Instant> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("app.data.Instant", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: Instant) = encoder.encodeString(format(value))
    override fun deserialize(decoder: Decoder): Instant = parse(decoder.decodeString())

    private val SHORT_OFFSET = Regex("([+-]\\d{2})$")

    fun parse(text: String): Instant {
        var s = text.trim()
        if (s.length > DATE_LENGTH && s[DATE_LENGTH] == ' ') s = s.substring(0, DATE_LENGTH) + "T" + s.substring(DATE_LENGTH + 1)
        if (s.endsWith("Z") || s.endsWith("z")) return Instant.parse(s.dropLast(1) + "Z")
        s = s.replace(SHORT_OFFSET, "$1:00")
        return OffsetDateTime.parse(s, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant()
    }

    /** Microsecond precision (what Postgres stores), UTC. */
    fun format(value: Instant): String = DateTimeFormatter.ISO_INSTANT.format(value.truncatedTo(ChronoUnit.MICROS))

    private const val DATE_LENGTH = 10
}

/** `date`: `YYYY-MM-DD`. */
object LocalDateSerializer : KSerializer<LocalDate> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("app.data.LocalDate", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: LocalDate) = encoder.encodeString(value.toString())
    override fun deserialize(decoder: Decoder): LocalDate = LocalDate.parse(decoder.decodeString().trim())
}

/** `time`: returned as `HH:MM:SS`; sent as `HH:MM:SS` (docs/API.md §1). */
object LocalTimeSerializer : KSerializer<LocalTime> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("app.data.LocalTime", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: LocalTime) = encoder.encodeString(format(value))
    override fun deserialize(decoder: Decoder): LocalTime = LocalTime.parse(decoder.decodeString().trim())

    fun format(value: LocalTime): String = value.truncatedTo(ChronoUnit.SECONDS).format(DateTimeFormatter.ISO_LOCAL_TIME)
}
