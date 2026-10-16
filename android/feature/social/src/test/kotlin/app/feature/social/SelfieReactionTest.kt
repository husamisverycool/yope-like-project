package app.feature.social

import app.data.model.SelfieReaction
import app.data.realtime.GroupEvent
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.viewer.SelfieEntry
import app.feature.social.viewer.ViewerEffect
import app.feature.social.viewer.newestFirst
import app.feature.social.viewer.stackFaces
import app.model.PhotoContext
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.time.Instant

/** viewer.selfiereaction in the viewer's view model: rows, optimistic send / replace / remove, realtime, never a count. */
@OptIn(ExperimentalCoroutinesApi::class)
class SelfieReactionTest {
    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() {
        scope.cancel()
        Dispatchers.resetMain()
    }

    private fun selfie(user: String, post: String = "v-1", at: Instant = BASE) = SelfieReaction(id = "s-$user-$post", postId = post, userId = user, groupId = GROUP, imagePath = "u/$user/selfies/$user-$post.jpg", createdAt = at)

    private fun still(): File = File.createTempFile("selfie", ".jpg")

    private fun effects(vm: PhotoViewerViewModel): MutableList<ViewerEffect> = ArrayList<ViewerEffect>().also { out -> scope.launch { vm.effects.collect { out += it } } }

    private fun viewer(data: FakeSocialData, post: String = "v-1") = PhotoViewerViewModel(data, GROUP, post, PhotoContext.Single, post, null)

    @Test fun selfiesLoadWithThePhotoAndTheirPeople() {
        val data = viewerData().apply { selfies["v-1"] = mutableListOf(selfie(BEN), selfie(ME, at = BASE.plusSeconds(60))) }
        val photo = viewer(data).state.value.current!!
        assertEquals(listOf(BEN, ME), photo.selfies.map { it.userId })
        assertEquals("Ben", photo.people[BEN]?.firstName)
        assertEquals("u/$BEN/selfies/$BEN-v-1.jpg", photo.selfies.first().imagePath)
    }

    @Test fun sendingIsOptimisticReplacesYoursAndAnnounces() {
        val data = viewerData().apply { selfies["v-1"] = mutableListOf(selfie(ME), selfie(BEN, at = BASE.plusSeconds(5))) }
        val vm = viewer(data)
        val out = effects(vm)
        val gate = CompletableDeferred<Unit>()
        data.gate = gate
        val file = still()
        vm.sendSelfie(file)
        // At once: your face (the still just taken) at the leading end, replacing the earlier one; no id yet.
        val sending = vm.state.value.current!!.selfies
        assertEquals(1, sending.count { it.userId == ME })
        val mine = sending.single { it.userId == ME }
        assertNull(mine.id)
        assertEquals(file, mine.localFile)
        assertEquals(ME, stackFaces(sending).first().userId)
        gate.complete(Unit)
        val sent = vm.state.value.current!!.selfies.single { it.userId == ME }
        assertNotNull(sent.id)
        assertEquals(file, sent.localFile) // the same face stays on screen
        assertEquals(listOf<ViewerEffect>(ViewerEffect.SelfieSent), out)
        assertTrue(data.calls.contains("reactWithSelfie:v-1"))
    }

    @Test fun aFailedSendTakesYourFaceBackOutAndRestoresTheEarlierOne() {
        val data = viewerData().apply { selfies["v-1"] = mutableListOf(selfie(ME)) }
        val vm = viewer(data)
        val out = effects(vm)
        data.failNext += "reactWithSelfie:v-1"
        vm.sendSelfie(still())
        val mine = vm.state.value.current!!.selfies.single { it.userId == ME }
        assertEquals("s-$ME-v-1", mine.id)
        assertNull(mine.localFile)
        assertEquals(listOf<ViewerEffect>(ViewerEffect.SelfieFailed), out)

        // Offline: nothing was there before, so the stack is empty again.
        val fresh = viewerData()
        val vm2 = viewer(fresh)
        fresh.offline = true
        vm2.sendSelfie(still())
        assertTrue(vm2.state.value.current!!.selfies.isEmpty())
    }

    @Test fun yourOwnPhotoTakesNoSelfie() {
        val data = viewerData()
        val vm = viewer(data, "v-2") // mine
        assertFalse(vm.state.value.canReactWithSelfie)
        vm.sendSelfie(still())
        assertTrue(vm.state.value.current!!.selfies.isEmpty())
        assertFalse(data.calls.any { it.startsWith("reactWithSelfie") })
        assertTrue(viewer(viewerData(), "v-1").state.value.canReactWithSelfie)
    }

    @Test fun youRemoveYoursTheAuthorRemovesAnyoneElseCannot() {
        val data = viewerData().apply {
            selfies["v-1"] = mutableListOf(selfie(ME), selfie(BEN))
            selfies["v-2"] = mutableListOf(selfie(ANA, "v-2"), selfie(BEN, "v-2"))
        }
        val others = viewer(data, "v-1")
        others.removeSelfie(BEN) // not my photo, not my selfie: nothing happens
        assertEquals(2, others.state.value.current!!.selfies.size)
        others.removeSelfie(ME)
        assertEquals(listOf(BEN), others.state.value.current!!.selfies.map { it.userId })
        assertTrue(data.calls.contains("removeSelfie:v-1:")) // yours: p_user_id omitted

        val mine = viewer(data, "v-2")
        data.failNext += "removeSelfie:v-2:$ANA"
        mine.removeSelfie(ANA)
        assertEquals(listOf(ANA, BEN), mine.state.value.current!!.selfies.map { it.userId }) // back after the failure
        mine.removeSelfie(ANA)
        assertEquals(listOf(BEN), mine.state.value.current!!.selfies.map { it.userId })
        assertEquals(listOf(BEN), data.selfies["v-2"]!!.map { it.userId })
    }

    @Test fun realtimeAddsReplacesAndRefetchesAfterARemoval() = runBlocking {
        val data = viewerData()
        val vm = viewer(data)
        data.emit(GroupEvent.SelfieReactionChanged(GROUP, selfie(BEN)))
        assertEquals(listOf(BEN), vm.state.value.current!!.selfies.map { it.userId })
        val replaced = selfie(BEN, at = BASE.plusSeconds(90)).copy(id = "s-new", imagePath = "u/$BEN/selfies/new.jpg")
        data.emit(GroupEvent.SelfieReactionChanged(GROUP, replaced))
        assertEquals(listOf("s-new"), vm.state.value.current!!.selfies.map { it.id }) // one per person
        // Removals arrive as reactions_changed: the post's selfie rows are read again.
        data.selfies["v-1"] = mutableListOf()
        data.emit(GroupEvent.ReactionsChanged(GROUP, "v-1"))
        assertTrue(vm.state.value.current!!.selfies.isEmpty())
        // Another post's selfie is ignored.
        data.emit(GroupEvent.SelfieReactionChanged(GROUP, selfie(BEN, "elsewhere")))
        assertTrue(vm.state.value.current!!.selfies.isEmpty())
    }

    @Test fun theStackShowsAtMostThreeNewestLeadingAndNeverANumber() {
        val entries = listOf(ANA, BEN, ME, "u-x0").mapIndexed { i, u -> SelfieEntry("s$i", u, "u/$u/selfies/$i.jpg", BASE.plusSeconds(i * 60L)) }
        assertEquals(listOf("u-x0", ME, BEN), stackFaces(entries).map { it.userId })
        val sending = entries + SelfieEntry(null, "u-x1", null, null)
        assertEquals("u-x1", stackFaces(sending).first().userId)
        assertEquals(listOf(null, BASE.plusSeconds(60), BASE), listOf<Instant?>(BASE, null, BASE.plusSeconds(60)).sortedWith(newestFirst { it }))
    }
}
