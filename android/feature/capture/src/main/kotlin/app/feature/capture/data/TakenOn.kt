package app.feature.capture.data

import android.content.Context
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * The day a library photo was taken, for `media.taken_on` (migration 0050; docs/RESEARCH_FEATURES_2026-10-17.md #5,
 * Retro's "backfill the weeks"): the date only, in the device's time zone — MediaStore `DATE_TAKEN` of the picked or
 * shared item, else the file's own EXIF `DateTimeOriginal` (photos) or MP4 creation date (videos). Never a time and never
 * a place: no location column or tag is read (the app strips GPS tags from library files, `ImageEncoder.stripLocation`,
 * and holds no media-location permission). Camera captures send nothing.
 */
object TakenOn {
    /** The first day the server accepts (`media.taken_on` check, migration 0050). */
    val EARLIEST: LocalDate = LocalDate.of(1900, 1, 1) // provenance-ok: the server's taken_on range (migration 0050)

    private val EXIF_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy:MM:dd HH:mm:ss")
    private val MP4_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss")

    /** Only days the server accepts: not before 1900, not after today on the device. */
    fun valid(day: LocalDate?, today: LocalDate): LocalDate? = day?.takeIf { !it.isBefore(EARLIEST) && !it.isAfter(today) }

    /** MediaStore `DATE_TAKEN` (milliseconds since the epoch) on the device's day; null for 0 / unknown. */
    fun fromEpochMillis(millis: Long?, zone: ZoneId = ZoneId.systemDefault(), today: LocalDate = LocalDate.now(zone)): LocalDate? {
        if (millis == null || millis <= 0) return null
        return valid(Instant.ofEpochMilli(millis).atZone(zone).toLocalDate(), today)
    }

    /**
     * EXIF `DateTimeOriginal` (`yyyy:MM:dd HH:mm:ss`, the camera's wall clock): with `OffsetTimeOriginal` (`+02:00`) it is
     * an instant shown on the device's day; without one, its own calendar day.
     */
    fun fromExif(dateTimeOriginal: String?, offset: String?, zone: ZoneId = ZoneId.systemDefault(), today: LocalDate = LocalDate.now(zone)): LocalDate? {
        val text = dateTimeOriginal?.trim()?.takeIf { it.length >= EXIF_LENGTH } ?: return null
        val wall = runCatching { LocalDateTime.parse(text.substring(0, EXIF_LENGTH), EXIF_FORMAT) }.getOrNull() ?: return null
        val day = offset?.trim()?.takeIf { it.isNotEmpty() }
            ?.let { runCatching { ZoneOffset.of(it) }.getOrNull() }
            ?.let { wall.atOffset(it).atZoneSameInstant(zone).toLocalDate() }
            ?: wall.toLocalDate()
        return valid(day, today)
    }

    /** `MediaMetadataRetriever.METADATA_KEY_DATE` (`20260914T183000.000Z`, UTC) on the device's day. */
    fun fromMp4Date(text: String?, zone: ZoneId = ZoneId.systemDefault(), today: LocalDate = LocalDate.now(zone)): LocalDate? {
        val value = text?.trim()?.takeIf { it.length >= MP4_LENGTH } ?: return null
        val wall = runCatching { LocalDateTime.parse(value.substring(0, MP4_LENGTH), MP4_FORMAT) }.getOrNull() ?: return null
        // 1904-01-01 is the MP4 epoch: a file whose creation time was never set.
        if (wall.year <= MP4_EPOCH_YEAR) return null
        return valid(wall.atOffset(ZoneOffset.UTC).atZoneSameInstant(zone).toLocalDate(), today)
    }

    /** The day [uri] (copied to [file]) was taken: MediaStore first, then the file's own metadata; null when unknown. */
    fun read(context: Context, uri: Uri?, file: File, video: Boolean): LocalDate? {
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now(zone)
        uri?.let { fromEpochMillis(dateTaken(context, it, video), zone, today) }?.let { return it }
        return if (video) {
            runCatching {
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(file.absolutePath)
                    fromMp4Date(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE), zone, today)
                } finally {
                    retriever.release()
                }
            }.getOrNull()
        } else {
            runCatching {
                val exif = ExifInterface(file.path)
                fromExif(exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL), exif.getAttribute(TAG_OFFSET_TIME_ORIGINAL), zone, today)
            }.getOrNull()
        }
    }

    /** `DATE_TAKEN` of a MediaStore / Photo Picker uri (other providers may not have the column: null). */
    private fun dateTaken(context: Context, uri: Uri, video: Boolean): Long? = runCatching {
        val column = if (video) MediaStore.Video.VideoColumns.DATE_TAKEN else MediaStore.Images.ImageColumns.DATE_TAKEN
        context.contentResolver.query(uri, arrayOf(column), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(column)
            if (index >= 0 && cursor.moveToFirst() && !cursor.isNull(index)) cursor.getLong(index) else null
        }
    }.getOrNull()

    private const val EXIF_LENGTH = 19 // provenance-ok: "yyyy:MM:dd HH:mm:ss"
    private const val MP4_LENGTH = 15 // provenance-ok: "yyyyMMddTHHmmss"
    private const val MP4_EPOCH_YEAR = 1904 // provenance-ok: the MP4 time epoch
    /** `ExifInterface.TAG_OFFSET_TIME_ORIGINAL` (API 28; the constant's value, read on every API level the app supports). */
    private const val TAG_OFFSET_TIME_ORIGINAL = "OffsetTimeOriginal"
}
