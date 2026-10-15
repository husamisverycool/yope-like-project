package app.ui.format

import app.designsystem.generated.Tokens
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Time and date formats of Yope's voice (`yope.voice.formats`), from tokens:
 * - time `h:mm AM/PM` — `Tokens.Layouts.ChatThreadLayoutTimeFormat.pattern` ("h:mm a");
 * - date "Mmm d yyyy" — `Tokens.Layouts.PhotoViewerLayoutDateFormat.pattern` ("MMM d yyyy").
 */
object Formats {
    fun time(instant: Instant, zone: ZoneId = ZoneId.systemDefault(), locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofPattern(Tokens.Layouts.ChatThreadLayoutTimeFormat.pattern, locale).format(instant.atZone(zone))

    fun time(time: LocalTime, locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofPattern(Tokens.Layouts.ChatThreadLayoutTimeFormat.pattern, locale).format(time)

    fun date(instant: Instant, zone: ZoneId = ZoneId.systemDefault(), locale: Locale = Locale.getDefault()): String =
        DateTimeFormatter.ofPattern(Tokens.Layouts.PhotoViewerLayoutDateFormat.pattern, locale).format(instant.atZone(zone))
}
