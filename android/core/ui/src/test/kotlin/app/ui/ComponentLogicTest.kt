package app.ui

import androidx.compose.animation.core.SnapSpec
import androidx.compose.animation.core.TweenSpec
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.designsystem.generated.Tokens
import app.ui.components.DayTile
import app.ui.components.GroupedPosition
import app.ui.components.ViewerTaps
import app.ui.components.WaveformBars
import app.ui.components.WeekStripOrder
import app.ui.components.finePrintText
import app.ui.components.stripTileShape
import app.ui.components.subtitleWithActor
import app.ui.format.Formats
import app.ui.foundation.DsMotion
import app.ui.foundation.GlyphInk
import app.ui.theme.appColorScheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.Locale

/** Pure logic behind the C-* components (no rendering). */
@RunWith(AndroidJUnit4::class)
class ComponentLogicTest {
    @Test fun groupedRowsRoundOnlyTheGroupsOuterCorners() {
        assertEquals(GroupedPosition.Single, GroupedPosition.of(0, 1))
        assertEquals(listOf(GroupedPosition.First, GroupedPosition.Middle, GroupedPosition.Middle, GroupedPosition.Last), (0 until 4).map { GroupedPosition.of(it, 4) })
        assertEquals(listOf(GroupedPosition.First, GroupedPosition.Last), (0 until 2).map { GroupedPosition.of(it, 2) })
        val r = Tokens.Radii.globalGroupedRow
        assertEquals(RoundedCornerShape(r), GroupedPosition.Single.shape())
        assertEquals(RoundedCornerShape(topStart = r, topEnd = r), GroupedPosition.First.shape())
        assertEquals(RectangleShape, GroupedPosition.Middle.shape())
        assertEquals(RoundedCornerShape(bottomStart = r, bottomEnd = r), GroupedPosition.Last.shape())
        // A hairline only between rows.
        assertEquals(listOf(true, true, false), listOf(GroupedPosition.First, GroupedPosition.Middle, GroupedPosition.Last).map { it.dividerBelow })
        assertFalse(GroupedPosition.Single.dividerBelow)
    }

    @Test fun addTileIsFirstInAnEmptyWeekAndLastOtherwise() {
        val add = DayTile.Add("Add a photo", {})
        val empty = listOf(DayTile.Empty("a", "Oct", "20", "Mon", "Monday"), DayTile.Empty("b", "Oct", "21", "Tue", "Tuesday"))
        assertEquals(add, WeekStripOrder.withAdd(empty, add).first())
        val withPhoto = empty + DayTile.Photo("p", null, "Wed", "Wednesday, photo")
        assertEquals(add, WeekStripOrder.withAdd(withPhoto, add).last())
        assertEquals(add, WeekStripOrder.withAdd(emptyList(), add).single())
    }

    @Test fun onlyTheStripsOuterCornersRound() {
        val r = Tokens.Radii.globalCard
        val inner = Tokens.Radii.globalPhoto
        assertEquals(RoundedCornerShape(topStart = r, bottomStart = r, topEnd = inner, bottomEnd = inner), stripTileShape(0, 3))
        assertEquals(RectangleShape, stripTileShape(1, 3))
        assertEquals(RoundedCornerShape(topStart = inner, bottomStart = inner, topEnd = r, bottomEnd = r), stripTileShape(2, 3))
        assertEquals(RoundedCornerShape(r), stripTileShape(0, 1))
    }

    @Test fun viewerTapsGoBackOnlyInTheLeadingZone() {
        assertTrue(ViewerTaps.isPrevious(10f, 400f, 0.3f, rtl = false))
        assertFalse(ViewerTaps.isPrevious(200f, 400f, 0.3f, rtl = false))
        assertFalse(ViewerTaps.isPrevious(390f, 400f, 0.3f, rtl = false))
        // Right-to-left: the leading zone is on the right.
        assertTrue(ViewerTaps.isPrevious(390f, 400f, 0.3f, rtl = true))
        assertFalse(ViewerTaps.isPrevious(10f, 400f, 0.3f, rtl = true))
        assertFalse(ViewerTaps.isPrevious(10f, 0f, 0.3f, rtl = false))
    }

    @Test fun actorNameIsSemibold() {
        val text = subtitleWithActor("daniel shared photos", "daniel")
        assertEquals("daniel shared photos", text.text)
        val span = text.spanStyles.single()
        assertEquals(0, span.start)
        assertEquals("daniel".length, span.end)
        assertEquals(Tokens.FontWeights.fontWeightGlobalListTitle, span.item.fontWeight)
        assertTrue(subtitleWithActor("no actor here", "ana").spanStyles.isEmpty())
        assertNotEquals(FontWeight.Normal, span.item.fontWeight)
    }

    @Test fun finePrintLinksEachLabel() {
        val text = finePrintText("By continuing, I confirm I have read the Terms and Privacy Policy", listOf("Terms" to {}, "Privacy Policy" to {}))
        val links = text.getLinkAnnotations(0, text.length)
        assertEquals(listOf("Terms", "Privacy Policy"), links.map { text.text.substring(it.start, it.end) })
        assertTrue(links.all { it.item is LinkAnnotation.Clickable })
    }

    @Test fun formatsFollowTheLocaleFormatter() {
        val utc = ZoneOffset.UTC
        // Range: the month once inside a month, both months across a boundary (retro.voice.formats).
        val inMonth = Formats.weekRange(LocalDate.of(2023, 7, 3), LocalDate.of(2023, 7, 9), utc, Locale.US)
        assertTrue(inMonth, inMonth.startsWith("Jul 3") && inMonth.endsWith("9") && inMonth.count { it == 'J' } == 1)
        val across = Formats.weekRange(LocalDate.of(2024, 4, 29), LocalDate.of(2024, 5, 5), utc, Locale.US)
        assertTrue(across, across.startsWith("Apr 29") && across.endsWith("May 5"))
        val now = Instant.parse("2026-10-15T12:00:00Z")
        assertEquals("2h", Formats.elapsed(now.minusSeconds(2 * 3600), now, Locale.US))
        assertEquals("1d", Formats.elapsed(now.minusSeconds(26 * 3600), now, Locale.US))
        assertEquals("May 1, 2019", Formats.date(Instant.parse("2019-05-01T12:00:00Z"), utc, Locale.US))
        assertEquals("January 25, 2024", Formats.longDate(LocalDate.of(2024, 1, 25), Locale.US))
        // A day inside a sentence keeps the sentence's case ("…for these groups tomorrow at 9:00 AM.").
        val tomorrow = Formats.dayAndTimeInSentence(Instant.parse("2026-10-16T09:00:00Z"), "9:00 AM", utc, now, Locale.US)
        assertTrue(tomorrow, tomorrow.startsWith("tomorrow") && tomorrow.endsWith("9:00 AM"))
        val today = Formats.dayAndTimeInSentence(now.plusSeconds(3600), "1:00 PM", utc, now, Locale.US)
        assertTrue(today, today.startsWith("today"))
    }

    @Test fun glyphInkIsInsideTheViewport() {
        val back = Tokens.Icons.globalBack
        val ink = GlyphInk.bounds(back)
        assertTrue(ink.left > 0f && ink.right < back.viewportWidth && ink.width > 0f)
        val box = Tokens.Sizes.globalIcon
        assertEquals(box.value, (GlyphInk.leading(back, box) + GlyphInk.width(back, box) + GlyphInk.trailing(back, box)).value, 0.001f)
    }

    @Test fun reduceMotionSnapsMovementAndKeepsFades() {
        val spec = DsMotion.stripInsert<IntOffset>()
        assertTrue(DsMotion.movement(spec, reduceMotion = true) is SnapSpec)
        assertTrue(DsMotion.movement(spec, reduceMotion = false) is TweenSpec)
        assertEquals(Tokens.Durations.globalStripInsert, (DsMotion.stripInsert<Float>() as TweenSpec).durationMillis)
        assertEquals(Tokens.Durations.globalFade, (DsMotion.fade<Float>() as TweenSpec).durationMillis)
        assertNotEquals(DsMotion.pageEnter(reduceMotion = true), DsMotion.pageEnter(reduceMotion = false))
    }

    @Test fun nativeSchemeIsRetrosInEachAppearance() {
        val light = appColorScheme(dark = false)
        val dark = appColorScheme(dark = true)
        assertEquals(Tokens.ColorsLight.globalSystemPrimary, light.primary)
        assertEquals(Tokens.ColorsLight.globalSystemSurface, light.surface)
        assertEquals(Tokens.ColorsLight.globalSystemSurface, light.background)
        assertEquals(Tokens.ColorsLight.globalSystemSecondaryContainer, light.secondaryContainer)
        assertEquals(Tokens.ColorsLight.globalSystemSurfaceContainerHigh, light.surfaceContainerHigh)
        assertEquals(Tokens.ColorsDark.globalSystemSurface, dark.surface)
        assertEquals(Tokens.ColorsDark.globalSystemOnSurface, dark.onSurface)
        assertEquals(Tokens.ColorsDark.globalSystemError, dark.error)
        assertEquals(Tokens.ColorsDark.globalSystemSurfaceContainerLow, dark.surfaceContainerLow)
        assertEquals(Tokens.ColorsDark.globalSystemOutline, dark.outline)
        assertNotEquals(light.surface, dark.surface)
        assertTrue(Tokens.Sizes.globalMinTouchTargetAndroid >= 48.dp)
    }

    /** Settings → True Black (owner decision 21): Retro's d42.w changes the dark background / surface only. */
    @Test fun trueBlackChangesTheDarkSchemesSurfaceOnly() {
        val dark = appColorScheme(dark = true)
        val trueBlack = appColorScheme(dark = true, trueBlack = true)
        assertEquals(Tokens.ColorsDark.globalSystemSurfaceTrueBlack, trueBlack.surface)
        assertEquals(Tokens.ColorsDark.globalSystemSurfaceTrueBlack, trueBlack.background)
        assertEquals(androidx.compose.ui.graphics.Color(0xFF000000), trueBlack.background) // provenance-ok: asserts the token's sourced value (d42.w)
        listOf<(androidx.compose.material3.ColorScheme) -> Any>(
            { it.primary }, { it.onSurface }, { it.secondaryContainer }, { it.primaryContainer }, { it.error },
            { it.surfaceContainerHigh }, { it.surfaceContainerLow }, { it.outline }, { it.onSurfaceVariant },
        ).forEach { role -> assertEquals(role(dark), role(trueBlack)) }
        // Light is untouched: the option names the dark theme.
        assertEquals(appColorScheme(dark = false), appColorScheme(dark = false, trueBlack = true))
        assertEquals(Tokens.ColorsLight.globalBackgroundAndroid, Tokens.ColorsLight.globalBackgroundAndroidTrueBlack)
        assertNotEquals(Tokens.ColorsDark.globalBackgroundAndroid, Tokens.ColorsDark.globalBackgroundAndroidTrueBlack)
    }

    // C-36 voice waveform (owner decision 16)

    @Test fun waveformBarCountFollowsTheWidth() {
        // 154 pt at 2.0 + 2.1: 38 bars (Apple Messages draws 38).
        assertEquals(38, WaveformBars.count(154f, 2f, 2.1f))
        assertEquals(1, WaveformBars.count(2f, 2f, 2.1f))
        assertEquals(0, WaveformBars.count(0f, 2f, 2.1f))
        assertEquals(38, WaveformBars(List(100) { 5 }, 154f, 2f, 2.1f, 2f, 20f).heights.size)
        assertEquals("never more bars than stored levels", 3, WaveformBars(listOf(1, 2, 3), 1000f, 2f, 2.1f, 2f, 20f).heights.size)
    }

    @Test fun waveformBarsTakeTheBucketPeakAndScaleToTheNotesLargestLevel() {
        val levels = MutableList(100) { 0 }
        levels[3] = 10
        levels[50] = 20
        val bars = WaveformBars(levels, 4 * 4.1f - 2.1f, 2f, 2.1f, 2f, 22f)
        assertEquals(4, bars.heights.size)
        assertEquals(12f, bars.heights[0], 1e-4f)
        assertEquals(2f, bars.heights[1], 1e-4f)
        assertEquals(22f, bars.heights[2], 1e-4f)
    }

    @Test fun waveformWithoutLevelsDrawsDots() {
        val bars = WaveformBars(null, 154f, 2f, 2.1f, 2f, 20f)
        assertEquals(38, bars.heights.size)
        assertTrue(bars.heights.all { it == 2f })
        assertEquals(bars.heights, WaveformBars(emptyList(), 154f, 2f, 2.1f, 2f, 20f).heights)
    }

    @Test fun waveformProgressSplitsTheBarUnderTheEdge() {
        val total = 10 * 4.1f - 2.1f
        val bars = WaveformBars(List(100) { 9 }, total, 2f, 2.1f, 2f, 20f)
        val progress = (3 * 4.1f + 1f) / total
        assertEquals(1f, bars.playedShare(2, progress))
        assertEquals(0.5f, bars.playedShare(3, progress), 1e-4f)
        assertEquals(0f, bars.playedShare(4, progress))
        assertEquals(0f, bars.playedShare(9, 0f))
        assertEquals(1f, bars.playedShare(9, 1f))
    }
}
