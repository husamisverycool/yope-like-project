package app.feature.memory.tagging

import app.data.error.ApiError
import app.data.error.DataError
import app.designsystem.generated.Tokens
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.Scenario
import app.feature.memory.birthday.DateEntryPattern
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.util.Locale

@OptIn(ExperimentalCoroutinesApi::class)
class SelfTagControllerTest {
    private val haptics = mutableListOf<Int>()

    @Test fun readsTheTagThenTogglesOptimistically() = runTest(UnconfinedTestDispatcher()) {
        val backend = Scenario.backend()
        val c = SelfTagController("p-other", backend, this, initiallyTagged = null, haptic = { haptics += it })
        assertEquals(false, c.tagged)
        backend.gates["tagSelf"] = CompletableDeferred()
        c.toggle()
        assertEquals("on at once", true, c.tagged)
        assertTrue(c.pending)
        c.toggle()
        assertEquals("taps ignored while the call runs", 1, backend.calls.count { it == "tagSelf" })
        backend.gates.getValue("tagSelf").complete(Unit)
        assertFalse(c.pending)
        assertTrue(("p-other" to FakeMemoryBackend.ME) in backend.tags)
        c.toggle()
        assertEquals(false, c.tagged)
        assertFalse(("p-other" to FakeMemoryBackend.ME) in backend.tags)
        assertEquals(listOf(Tokens.Haptics.globalSelect, Tokens.Haptics.globalSelect), haptics)
    }

    @Test fun failureRevertsWithTheMessage() = runTest(UnconfinedTestDispatcher()) {
        val backend = Scenario.backend().apply { failNext["tagSelf"] = DataError.Unexpected("x") }
        val c = SelfTagController("p-other", backend, this, initiallyTagged = false, haptic = { haptics += it })
        c.toggle()
        assertEquals(false, c.tagged)
        assertEquals(SelfTagController.Message.Error, c.message)
        assertEquals(Tokens.Haptics.globalError, haptics.last())
        c.dismissMessage()
        assertNull(c.message)
    }

    @Test fun photoGoneRevertsAndTellsTheViewer() = runTest(UnconfinedTestDispatcher()) {
        var gone = false
        val backend = Scenario.backend().apply { failNext["tagSelf"] = FakeMemoryBackend.api(ApiError.PostNotFound) }
        val c = SelfTagController("p-other", backend, this, initiallyTagged = false, onPhotoGone = { gone = true })
        c.toggle()
        assertEquals(false, c.tagged)
        assertEquals(SelfTagController.Message.NotFound, c.message)
        assertTrue(gone)
    }

    @Test fun offlineDoesNotChangeTheToggle() = runTest(UnconfinedTestDispatcher()) {
        val backend = Scenario.backend().apply { online = false }
        val c = SelfTagController("p-other", backend, this, initiallyTagged = true)
        c.toggle()
        assertEquals(true, c.tagged)
        assertEquals(SelfTagController.Message.Offline, c.message)
        assertFalse("untagSelf" in backend.calls)
    }
}

class DateEntryPatternTest {
    @Test fun followsTheLocaleOrderWithAFourDigitYear() {
        val us = DateEntryPattern.forLocale(Locale.US)
        assertEquals(listOf('M', 'd', 'y'), us.fields)
        assertEquals("MM/dd/yyyy", us.display)
        assertEquals("05/26/1999", us.format("05261999"))
        assertEquals("05/2", us.format("052"))
        assertEquals(LocalDate.of(1999, 5, 26), us.parse("05261999"))
        val de = DateEntryPattern.forLocale(Locale.GERMANY)
        assertEquals(listOf('d', 'M', 'y'), de.fields)
        assertEquals("26.05.1999", de.format("26051999"))
        val jp = DateEntryPattern.forLocale(Locale.JAPAN)
        assertEquals('y', jp.fields.first())
        assertEquals(LocalDate.of(1999, 5, 26), jp.parse("19990526"))
    }

    @Test fun incompleteOrImpossibleDatesDoNotParse() {
        val us = DateEntryPattern.forLocale(Locale.US)
        assertNull(us.parse("0526199"))
        assertNull(us.parse("02301999"))
    }
}
