package app.feature.memory.tagging

import app.data.error.DataError
import app.designsystem.generated.Tokens
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.FakeMemoryBackend.Companion.ANA
import app.feature.memory.FakeMemoryBackend.Companion.ME
import app.feature.memory.Scenario
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.Locale

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class TagRunControllerTest {
    private fun backend() = Scenario.backend()

    @Test fun readsTheTaggedMembersInTagOrder() = runTest(UnconfinedTestDispatcher()) {
        val backend = backend().apply {
            tags.clear()
            tags += "p-other" to ANA
            tags += "p-other" to ME
        }
        val c = TagRunController("p-other", backend, this, initialPeople = null, me = null)
        assertEquals(listOf("Ana", "Jesus"), c.people?.map { it.firstName })
        assertTrue(c.isTagged)
    }

    @Test fun tagIsOptimisticAndUntagRemovesOnlyYou() = runTest(UnconfinedTestDispatcher()) {
        val backend = backend().apply { tags.clear(); tags += "p-other" to ANA; gates["tagSelf"] = CompletableDeferred() }
        val haptics = mutableListOf<Int>()
        val c = TagRunController("p-other", backend, this, initialPeople = null, me = null, haptic = { haptics += it })
        c.tag()
        assertEquals("you at once, at the end of the run", listOf(ANA, ME), c.people?.map { it.userId })
        assertTrue(c.pending)
        c.tag()
        c.untag()
        assertEquals("taps ignored while a call runs", 1, backend.calls.count { it == "tagSelf" })
        backend.gates.getValue("tagSelf").complete(Unit)
        assertFalse(c.pending)
        assertTrue(("p-other" to ME) in backend.tags)
        c.untag()
        assertEquals(listOf(ANA), c.people?.map { it.userId })
        assertFalse(("p-other" to ME) in backend.tags)
        assertTrue("Ana's tag stays", ("p-other" to ANA) in backend.tags)
        assertEquals(listOf(Tokens.Haptics.globalSelect, Tokens.Haptics.globalSelect), haptics)
    }

    @Test fun failuresRevertWithTheirMessage() = runTest(UnconfinedTestDispatcher()) {
        val backend = backend().apply { tags.clear(); failNext["tagSelf"] = DataError.Unexpected("500") }
        val c = TagRunController("p-other", backend, this, initialPeople = emptyList(), me = TaggedPerson(ME, "Jesus", null))
        c.tag()
        assertEquals(emptyList<TaggedPerson>(), c.people)
        assertEquals(TagRunController.Message.TagError, c.message)
        c.messageShown()
        assertNull(c.message)
        backend.tags += "p-other" to ME
        val tagged = TagRunController("p-other", backend, this, initialPeople = listOf(TaggedPerson(ME, "Jesus", null)), me = TaggedPerson(ME, "Jesus", null))
        backend.failNext["untagSelf"] = DataError.Unexpected("500")
        tagged.untag()
        assertEquals(listOf(ME), tagged.people?.map { it.userId })
        assertEquals(TagRunController.Message.RemoveError, tagged.message)
    }

    @Test fun offlineChangesNothingAndAGonePhotoClosesIt() = runTest(UnconfinedTestDispatcher()) {
        val backend = backend().apply { tags.clear(); online = false }
        var gone = false
        val c = TagRunController("p-missing", backend, this, initialPeople = emptyList(), me = TaggedPerson(ME, "Jesus", null), onPhotoGone = { gone = true })
        c.tag()
        assertEquals(TagRunController.Message.Offline, c.message)
        assertEquals(emptyList<TaggedPerson>(), c.people)
        backend.online = true
        c.tag()
        assertEquals(TagRunController.Message.NotFound, c.message)
        assertTrue(gone)
    }

    @Test fun namesAreJoinedByTheListFormatterAndSetInSemibold() {
        val people = listOf(TaggedPerson("a", "Ana", null), TaggedPerson("b", "Ben", null), TaggedPerson("c", "Cleo", null))
        val joined = joinNames(people, Locale.US)
        assertEquals("Ana, Ben, and Cleo", joined)
        val styled = withNames("with $joined", people)
        assertEquals("with Ana, Ben, and Cleo", styled.text)
        assertEquals(3, styled.spanStyles.size)
        assertEquals(Tokens.FontWeights.fontWeightGlobalListTitle, styled.spanStyles.first().item.fontWeight)
        assertEquals("Ana", styled.text.substring(styled.spanStyles.first().start, styled.spanStyles.first().end))
    }
}
