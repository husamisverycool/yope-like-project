package app.feature.memory.onthisday

import androidx.compose.ui.geometry.Offset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** `layout.onthisday.dial`: slots, angles and drag stepping (design/surfaces/onthisday.md B.6). */
class DialGeometryTest {
    @Test fun fortyFourSlotsFromSixDegreesAtTheMeasuredPitch() {
        assertEquals(44, DialGeometry.slots)
        assertEquals(6f, DialGeometry.angle(0), 0.001f)
        assertEquals(6f + 21 * 8.18f, DialGeometry.angle(21), 0.001f)
        assertTrue("even slots long", DialGeometry.isLong(0))
        assertFalse("odd slots short", DialGeometry.isLong(21))
    }

    @Test fun theIndicatorSitsOnTheMemorysSlotModuloTheRing() {
        assertEquals(0, DialGeometry.slotOf(0))
        assertEquals(43, DialGeometry.slotOf(43))
        assertEquals(1, DialGeometry.slotOf(45))
    }

    @Test fun clockwiseIsPositiveWithScreenYDown() {
        val centre = Offset(75f, 75f)
        assertEquals(0f, DialGeometry.angleOf(Offset(150f, 75f), centre), 0.001f)
        assertEquals("6 o'clock is a quarter turn clockwise", 90f, DialGeometry.angleOf(Offset(75f, 150f), centre), 0.001f)
        assertEquals("across ±180° the delta stays small", 20f, DialGeometry.delta(170f, -170f), 0.001f)
        assertEquals(-20f, DialGeometry.delta(-170f, 170f), 0.001f)
    }

    @Test fun oneStepPerSlotCrossedAndTheRestIsKept() {
        assertEquals(0, DialGeometry.slotsCrossed(8f).first)
        val (steps, rest) = DialGeometry.slotsCrossed(8.18f * 2 + 1f)
        assertEquals(2, steps)
        assertEquals(1f, rest, 0.001f)
        assertEquals(-1, DialGeometry.slotsCrossed(-9f).first)
    }
}
