package app.feature.memory.birthday

import app.feature.memory.SnapshotTest
import app.feature.memory.TestImages
import org.junit.Test
import java.time.Instant
import java.time.LocalDate

private val us = DateEntryPattern(listOf('M', 'd', 'y'), '/')

class BirthdayAddSnapshotTest : SnapshotTest() {
    private fun add(state: String, s: BirthdayAddState, settle: Long = settleMillis) =
        snap("birthday.add", state, settle = settle) { BirthdayAddScreen(s, us, {}, {}, {}, {}, {}, {}) }

    private val form = BirthdayAddState(loading = false)

    @Test fun loading() = add("loading", BirthdayAddState())
    @Test fun empty() = add("add-empty", form)
    @Test fun dateEntered() = add("add-date-entered", form.copy(digits = "05261999"))
    @Test fun partialDate() = add("add-partial", form.copy(digits = "052"))
    @Test fun saving() = add("saving", form.copy(digits = "05261999", busy = true))
    @Test fun invalid() = add("invalid", form.copy(digits = "13451999", inline = BirthdayAddState.Inline.Invalid))
    @Test fun offline() = add("offline", form.copy(digits = "05261999", inline = BirthdayAddState.Inline.Offline))
    @Test fun error() = add("error", form.copy(digits = "05261999", error = true))
    @Test fun manage() = add("manage", form.copy(saved = LocalDate.of(1999, 5, 26)))

    /** Added: the toast shows for `safety.block.duration.toast`, then the screen closes. */
    @Test fun addedToast() = add("toast-added", form.copy(saved = LocalDate.of(1999, 5, 26), toast = BirthdayAddState.Toast.Added, finished = true), settle = toastSettle)
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
    private fun request(state: String, s: RequestState) = snap("birthday.request", state) { BirthdayRequestScreen(s, {}, {}, {}, {}, {}) }

    private val ready = RequestState.Ready(sampleInfo, contribution = null, closed = false)

    @Test fun loading() = request("loading", RequestState.Loading)
    @Test fun offline() = request("offline", RequestState.Offline)
    @Test fun error() = request("error", RequestState.Failed)
    @Test fun notFound() = request("not-found", RequestState.NotFound)
    @Test fun open() = request("open", ready)
    @Test fun openNoPhoto() = request("open-no-honoree-photo", ready.copy(info = sampleInfo.copy(honoreeAvatarUrl = null)))
    @Test fun contributed() = request("contributed", ready.copy(contribution = OwnContribution("p2", TestImages.url("p2-d", 4, 3), 4f / 3, "you make every Sunday better")))
    @Test fun closed() = request("closed", ready.copy(closed = true))
}

class BirthdayContributeSnapshotTest : SnapshotTest() {
    private fun step(state: String, page: RequestPage, s: ContributeState) =
        snap("birthday.contribute", state) { BirthdayContributeScreen(page, sampleInfo, s, {}, {}, {}, {}, {}, {}, {}, {}, {}) }

    private val loaded = ContributeState(photos = PhotosState.Loaded(samplePhotos))
    private val chosen = loaded.copy(selected = "p2", line = "you make every Sunday better")

    @Test fun photoLoading() = step("photo-loading", RequestPage.Photo, ContributeState())
    @Test fun photoEmpty() = step("photo-empty", RequestPage.Photo, ContributeState(photos = PhotosState.Empty))
    @Test fun photoOffline() = step("photo-offline", RequestPage.Photo, ContributeState(photos = PhotosState.Failed(offline = true)))
    @Test fun photoError() = step("photo-error", RequestPage.Photo, ContributeState(photos = PhotosState.Failed(offline = false)))
    @Test fun photoNoneSelected() = step("photo-grid", RequestPage.Photo, loaded)
    @Test fun photoSelected() = step("photo-selected", RequestPage.Photo, loaded.copy(selected = "p2"))
    @Test fun photoNotEligible() = step("photo-not-eligible", RequestPage.Photo, loaded.copy(inline = ContributeState.Inline.NotEligible))
    @Test fun messageEmpty() = step("message-empty", RequestPage.Message, chosen.copy(line = ""))
    @Test fun message() = step("message", RequestPage.Message, chosen)
    @Test fun messageError() = step("message-error", RequestPage.Message, chosen.copy(inline = ContributeState.Inline.Error))
    @Test fun messageOffline() = step("message-offline", RequestPage.Message, chosen.copy(inline = ContributeState.Inline.Offline))
    @Test fun done() = step("done", RequestPage.Done, chosen)
    @Test fun closed() = step("closed", RequestPage.Message, chosen.copy(closed = true))
}

class TributeSnapshotTest : SnapshotTest() {
    private fun tribute(state: String, s: TributeState, settle: Long = settleMillis) =
        snap("birthday.tribute", state, settle = settle) { TributeScreen(s, autoplay = false, player = null, {}, {}, {}, {}, {}) }

    private val ready = TributeState(TributeContent.Ready("https://video.test/t.mp4", TestImages.url("poster", 16, 9)), groupName = "Sunday Lunch")

    @Test fun loading() = tribute("loading", TributeState())
    @Test fun rendering() = tribute("rendering", TributeState(TributeContent.Rendering, groupName = "Sunday Lunch"))
    @Test fun ready() = tribute("ready", ready)
    @Test fun saving() = tribute("saving", ready.copy(saving = true))
    @Test fun offline() = tribute("offline", TributeState(TributeContent.Offline))
    @Test fun notFound() = tribute("not-found", TributeState(TributeContent.NotFound))
    @Test fun error() = tribute("error", TributeState(TributeContent.Failed))

    @Test fun savedToast() = tribute("toast-saved", ready.copy(toast = TributeState.Toast.Saved), settle = toastSettle)
    @Test fun saveFailedToast() = tribute("toast-save-failed", ready.copy(toast = TributeState.Toast.SaveFailed), settle = toastSettle)
}
