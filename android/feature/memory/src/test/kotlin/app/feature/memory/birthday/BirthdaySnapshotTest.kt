package app.feature.memory.birthday

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import app.feature.memory.SnapshotTest
import app.feature.memory.TestImages
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.Test
import java.time.Instant
import java.time.LocalDate

private val us = DateEntryPattern(listOf('M', 'd', 'y'), '/')

class BirthdayAddSnapshotTest : SnapshotTest() {
    private fun add(state: String, s: BirthdayAddState, dark: Boolean = false) =
        snap("birthday.add", state, dark = dark) { BirthdayAddScreen(s, us, {}, {}, {}, {}, {}, {}) }

    private val form = BirthdayAddState(loading = false)

    @Test fun loading() = add("loading", BirthdayAddState())
    @Test fun empty() = add("add-empty", form)
    @Test fun emptyDark() = add("add-empty", form, dark = true)
    @Test fun dateEntered() = add("add-date-entered", form.copy(digits = "07051999"))
    @Test fun partialDate() = add("add-partial", form.copy(digits = "070"))
    @Test fun saving() = add("saving", form.copy(digits = "07051999", busy = true))
    @Test fun invalid() = add("invalid", form.copy(digits = "13451999", inline = BirthdayAddState.Inline.Invalid))
    @Test fun offline() = add("offline", form.copy(digits = "07051999", inline = BirthdayAddState.Inline.Offline))
    @Test fun error() = add("error", form.copy(digits = "07051999", error = true))
    @Test fun manage() = add("manage", form.copy(saved = LocalDate.of(1999, 7, 5)))
    @Test fun manageDark() = add("manage", form.copy(saved = LocalDate.of(1999, 7, 5)), dark = true)

    @Test fun removeAsksFirst() {
        compose.mainClock.autoAdvance = false
        compose.setContent { app.feature.memory.MemoryTestContent { BirthdayAddScreen(form.copy(saved = LocalDate.of(1999, 7, 5)), us, {}, {}, {}, {}, {}, {}) } }
        compose.mainClock.advanceTimeBy(settleMillis)
        compose.onNodeWithText("Remove Birthday").performClick()
        compose.mainClock.advanceTimeBy(settleMillis)
        compose.onNodeWithText("Remove your birthday?").assertExists()
        captureScreenRoboImage("src/test/snapshots/birthday.add/remove-confirm-light.png")
    }
}

internal val sampleInfo = RequestInfo(
    requestId = "r-1",
    groupId = "g-1",
    groupName = "Sunday Lunch",
    honoreeName = "Ana",
    honoreeAvatarUrl = TestImages.url("ana-avatar", 1, 1),
    birthdayDate = LocalDate.of(2026, 12, 12),
    dueAt = Instant.parse("2026-12-11T23:00:00Z"),
)

internal val samplePhotos = listOf(
    EligiblePhoto("p1", TestImages.url("p1"), TestImages.url("p1-d"), 0.75f, LocalDate.of(2026, 11, 30)),
    EligiblePhoto("p2", TestImages.url("p2", 4, 3), TestImages.url("p2-d", 4, 3), 4f / 3, LocalDate.of(2026, 11, 12)),
    EligiblePhoto("p3", TestImages.url("p3", 9, 16), TestImages.url("p3-d", 9, 16), 9f / 16, LocalDate.of(2026, 10, 2)),
    EligiblePhoto("p4", TestImages.url("p4", 1, 1), TestImages.url("p4-d", 1, 1), 1f, LocalDate.of(2026, 9, 20)),
    EligiblePhoto("p5", TestImages.url("p5"), TestImages.url("p5-d"), 0.75f, LocalDate.of(2026, 8, 1)),
)

class BirthdayRequestSnapshotTest : SnapshotTest() {
    private fun request(state: String, s: RequestState, dark: Boolean = false) =
        snap("birthday.request", state, dark = dark) { BirthdayRequestScreen(s, RequestActions()) }

    private val ready = RequestState.Ready(sampleInfo, contribution = null, closed = false)

    @Test fun loading() = request("loading", RequestState.Loading)
    @Test fun offline() = request("offline", RequestState.Offline)
    @Test fun error() = request("error", RequestState.Failed)
    @Test fun notFound() = request("not-found", RequestState.NotFound)
    @Test fun open() = request("open", ready)
    @Test fun openDark() = request("open", ready, dark = true)
    @Test fun openNoPhoto() = request("open-no-honoree-photo", ready.copy(info = sampleInfo.copy(honoreeAvatarUrl = null)))
    @Test fun contributed() = request("contributed", ready.copy(contribution = OwnContribution("p2", TestImages.url("p2-d", 4, 3), 4f / 3, "You make every Sunday better")))
    @Test fun closed() = request("closed", ready.copy(closed = true))

    @Test fun removeAsksFirst() {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            app.feature.memory.MemoryTestContent {
                BirthdayRequestScreen(ready.copy(contribution = OwnContribution("p2", TestImages.url("p2-d", 4, 3), 4f / 3, "You make every Sunday better")), RequestActions())
            }
        }
        compose.mainClock.advanceTimeBy(settleMillis)
        compose.onNodeWithTag(BirthdayRequestTags.REMOVE).performScrollTo().performClick()
        compose.mainClock.advanceTimeBy(settleMillis)
        compose.onNodeWithText("Remove your photo?").assertExists()
        captureScreenRoboImage("src/test/snapshots/birthday.request/remove-confirm-light.png")
    }
}

class BirthdayContributeSnapshotTest : SnapshotTest() {
    private fun photoStep(state: String, s: ContributeState, dark: Boolean = false) =
        snap("birthday.contribute", state, dark = dark) { ChoosePhotoStep(sampleInfo, s, {}, {}, {}, {}, {}) }

    private fun composer(state: String, s: ContributeState, dark: Boolean = false) =
        snap("birthday.contribute", state, dark = dark) { ComposerStep(sampleInfo, s, {}, {}, {}, {}) }

    private val loaded = ContributeState(photos = PhotosState.Loaded(samplePhotos))
    private val chosen = loaded.copy(selected = "p1", line = "You make every Sunday better")

    @Test fun photoLoading() = photoStep("photo-loading", ContributeState())
    @Test fun photoEmpty() = photoStep("photo-empty", ContributeState(photos = PhotosState.Empty))
    @Test fun photoOffline() = photoStep("photo-offline", ContributeState(photos = PhotosState.Failed(offline = true)))
    @Test fun photoError() = photoStep("photo-error", ContributeState(photos = PhotosState.Failed(offline = false)))
    @Test fun photoNoneSelected() = photoStep("photo-grid", loaded)
    @Test fun photoSelected() = photoStep("photo-selected", loaded.copy(selected = "p2"))
    @Test fun photoSelectedDark() = photoStep("photo-selected", loaded.copy(selected = "p2"), dark = true)
    @Test fun photoNotEligible() = photoStep("photo-not-eligible", loaded.copy(inline = ContributeState.Inline.NotEligible))
    @Test fun composerEmpty() = composer("composer-empty", chosen.copy(line = ""))
    @Test fun composerEmptyDark() = composer("composer-empty", chosen.copy(line = ""), dark = true)
    @Test fun composerLine() = composer("composer-line", chosen)
    @Test fun composerLandscape() = composer("composer-landscape", chosen.copy(selected = "p2"))
    @Test fun sending() = composer("sending", chosen.copy(sending = true))
    @Test fun composerError() = composer("composer-error", chosen.copy(inline = ContributeState.Inline.Error))
    @Test fun composerOffline() = composer("composer-offline", chosen.copy(inline = ContributeState.Inline.Offline))
    @Test fun closed() = composer("closed", chosen.copy(closed = true))
    @Test fun messageModal() = snap("birthday.contribute", "message") { MessageModal("You make every Sunday better", {}, {}) }
    @Test fun messageModalDark() = snap("birthday.contribute", "message", dark = true) { MessageModal("You make every Sunday better", {}, {}) }
    @Test fun messageModalEmpty() = snap("birthday.contribute", "message-empty") { MessageModal("", {}, {}) }

    /** The page sheet over the request (C-29). */
    @OptIn(ExperimentalMaterial3Api::class)
    @Test fun sheetOverTheRequest() = snap("birthday.contribute", "sheet", screen = true) {
        Box(Modifier.fillMaxSize()) {
            BirthdayRequestScreen(RequestState.Ready(sampleInfo, null, false), RequestActions())
            ModalBottomSheet(onDismissRequest = {}, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
                ChoosePhotoStep(sampleInfo, loaded.copy(selected = "p2"), {}, {}, {}, {}, {})
            }
        }
    }
}

class TributeSnapshotTest : SnapshotTest() {
    private fun tribute(state: String, s: TributeState, dark: Boolean = false, screen: Boolean = false) =
        snap("birthday.tribute", state, dark = dark, screen = screen) { TributeScreen(s, autoplay = false, player = null, actions = TributeActions()) }

    private val ready = TributeState(TributeContent.Ready("https://video.test/t.mp4", TestImages.url("poster", 16, 9)), groupName = "Sunday Lunch", honoreeName = "Ana")

    @Test fun loading() = tribute("loading", TributeState())
    @Test fun rendering() = tribute("rendering", TributeState(TributeContent.Rendering, groupName = "Sunday Lunch", honoreeName = "Ana"))
    @Test fun ready() = tribute("ready", ready)
    @Test fun readyDark() = tribute("ready", ready, dark = true)
    @Test fun honoree() = tribute("honoree", ready.copy(forMe = true, honoreeName = null))
    @Test fun saving() = tribute("saving", ready.copy(saving = true))
    @Test fun offline() = tribute("offline", TributeState(TributeContent.Offline))
    @Test fun notFound() = tribute("not-found", TributeState(TributeContent.NotFound))
    @Test fun error() = tribute("error", TributeState(TributeContent.Failed))
    @Test fun saveDenied() = tribute("save-denied", ready.copy(saveDenied = true), screen = true)
}
