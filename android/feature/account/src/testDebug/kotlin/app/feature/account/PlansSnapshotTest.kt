@file:OptIn(coil3.annotation.DelicateCoilApi::class, com.github.takahirom.roborazzi.ExperimentalRoborazziApi::class)

package app.feature.account

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.view.View
import android.widget.FrameLayout
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollToKey
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.mutablePreferencesOf
import androidx.glance.appwidget.compose
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.Developing
import app.data.model.Group
import app.data.model.GroupKind
import app.data.model.Plan
import app.data.model.PlanAnswerKind
import app.data.model.Post
import app.designsystem.LocalReduceMotionOverride
import app.designsystem.generated.Tokens
import app.feature.account.groups.GROUP_SCREEN_LIST_TAG
import app.feature.account.groups.GroupFeedScreen
import app.feature.account.groups.GroupFeedUiState
import app.feature.account.groups.GroupPhoto
import app.feature.account.groups.GroupScreenActions
import app.feature.account.plans.PlanCreateActions
import app.feature.account.plans.PlanCreateError
import app.feature.account.plans.PlanCreateScreen
import app.feature.account.plans.PlanCreateUiState
import app.feature.account.plans.PlanPageActions
import app.feature.account.plans.PlanPageScreen
import app.feature.account.plans.PlanPageUiState
import app.feature.account.plans.PlanPerson
import app.feature.account.plans.PlanPhoto
import app.feature.account.plans.NextPlanRow
import app.feature.account.plans.PlanFormats
import app.feature.account.plans.PlanRow
import app.feature.account.plans.developingTile
import app.feature.account.question.QuestionCard
import app.feature.account.testing.fakeEnvironment
import app.model.CountdownPlan
import app.model.CountdownSnapshot
import app.testing.SamplePhotos
import app.ui.foundation.PageRoles
import app.ui.theme.AppTheme
import app.widget.CountdownClock
import app.widget.CountdownStore
import app.widget.CountdownWidget
import app.widget.WidgetFileStore
import app.widget.WidgetGroupMeta
import app.widget.WidgetSizeClass
import coil3.SingletonImageLoader
import com.github.takahirom.roborazzi.captureRoboImage
import com.github.takahirom.roborazzi.captureScreenRoboImage
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

/**
 * plans.create, plans.page, the weekly question card, the developing tile (in groups.screen) and the countdown widget, per
 * state (docs/SCREENS_BRIEF.md rule 7), rendered from the stateless composables at 393 × 852 dp, xhdpi, Reduce Motion off,
 * real sample photos (`fixtures/photos`). Baselines: `src/test/snapshots/<surface-id>/<state>-<light|dark>.png`
 * (`./gradlew :feature:account:recordRoborazziDebug`). Debug build: BLOCKED copy shows ("Went", the widget's empty line)
 * and the plan row is placed (release leaves them out). Names, dates and places are test data.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class PlansSnapshotTest {
    @get:Rule val compose = createComposeRule()

    private val context get() = ApplicationProvider.getApplicationContext<Context>()
    private val utc = ZoneId.of("UTC")

    /** Thursday 15 October 2026, 17:00 UTC. */
    private val now = Instant.parse("2026-10-15T17:00:00Z")

    @Before fun photos() = SingletonImageLoader.setUnsafe(SamplePhotos.imageLoader(ApplicationProvider.getApplicationContext()))

    @After fun resetPhotos() = SingletonImageLoader.reset()

    private fun photo(name: String) = SamplePhotos.url(name)

    private fun snap(surface: String, state: String, dark: Boolean = false, settleMs: Long = FRAME_MS, act: (() -> Unit)? = null, content: @Composable () -> Unit) {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            CompositionLocalProvider(LocalAccountEnvironment provides fakeEnvironment(), LocalReduceMotionOverride provides false) {
                AppTheme(dark = dark) { content() }
            }
        }
        compose.mainClock.advanceTimeBy(FRAME_MS)
        if (act != null) {
            compose.mainClock.autoAdvance = true
            act()
            compose.waitForIdle()
            compose.mainClock.autoAdvance = false
            compose.mainClock.advanceTimeBy(SHEET_MS)
        }
        compose.mainClock.advanceTimeBy(settleMs)
        captureScreenRoboImage("src/test/snapshots/$surface/$state-${if (dark) "dark" else "light"}.png")
    }

    // plans.create -----------------------------------------------------------------------------------------
    private val empty = PlanCreateUiState(groupId = "g1", zone = utc, today = LocalDate.parse("2026-10-15"))
    private val filled = empty.copy(
        title = "Picnic at the lake",
        date = LocalDate.parse("2026-10-24"),
        time = LocalTime.of(18, 30),
        place = "Lake Park, north lawn",
        note = "Bring a blanket and something to share.",
        currentCoverUrl = photo("picnic-spread-3x4"),
    )
    private fun create(state: PlanCreateUiState) = @Composable { PlanCreateScreen(state, PlanCreateActions()) }
    @Test fun createEmpty() = snap("plans.create", "empty", content = create(empty))
    @Test fun createEmptyDark() = snap("plans.create", "empty", dark = true, content = create(empty))
    @Test fun createReady() = snap("plans.create", "ready", content = create(filled))
    @Test fun createReadyDark() = snap("plans.create", "ready", dark = true, content = create(filled))
    @Test fun createAllDay() = snap("plans.create", "ready-allDay", content = create(filled.copy(allDay = true, currentCoverUrl = null)))
    @Test fun createBusy() = snap("plans.create", "busy", content = create(filled.copy(working = true)))
    @Test fun createError() = snap("plans.create", "error", content = create(filled.copy(error = PlanCreateError.Failed)))
    @Test fun createCoverError() = snap("plans.create", "error-cover", content = create(filled.copy(error = PlanCreateError.Cover, currentCoverUrl = null)))
    @Test fun createOffline() = snap("plans.create", "offline", content = create(filled.copy(error = PlanCreateError.Offline)))
    @Test fun createTooLong() = snap("plans.create", "tooLong", content = create(empty.copy(title = "Picnic at the lake ".repeat(6))))
    @Test fun createEdit() = snap("plans.create", "edit", content = create(filled.copy(editPlanId = "p1")))

    // plans.page -------------------------------------------------------------------------------------------
    private fun plan(day: String = "2026-10-24", canceled: Boolean = false, cover: String? = "covers/p1.jpg") = Plan(
        "p1", "g1", "u-sam", "Picnic at the lake", LocalDate.parse(day).atTime(18, 30).atZone(utc).toInstant(), null, false, LocalDate.parse(day),
        "Lake Park, north lawn", "Bring a blanket and something to share. We'll be by the big oak.", cover, if (canceled) now else null, null, now, now,
    )
    private val sam = PlanPerson("u-sam", "Sam", photo("avatar-02"))
    private val ana = PlanPerson("u-me", "Ana", photo("avatar-01"))
    private val rui = PlanPerson("u-rui", "Rui", photo("avatar-06"))
    private val zoe = PlanPerson("u-zoe", "Zoe", photo("avatar-04"))
    private val ben = PlanPerson("u-ben", "Ben", null)
    private val page = PlanPageUiState(
        plan = plan(), zone = utc, coverUrl = photo("picnic-spread-3x4"), maker = sam,
        going = listOf(sam, ana, rui), maybe = listOf(zoe), myAnswer = PlanAnswerKind.Going,
    )
    private fun planPage(state: PlanPageUiState) = @Composable { PlanPageScreen(state, now, PlanPageActions()) }
    @Test fun pageLoading() = snap("plans.page", "loading", content = planPage(PlanPageUiState()))
    @Test fun pageGoing() = snap("plans.page", "upcoming-going", content = planPage(page))
    @Test fun pageGoingDark() = snap("plans.page", "upcoming-going", dark = true, content = planPage(page))
    @Test fun pageNoAnswer() = snap("plans.page", "upcoming-noAnswer", content = planPage(page.copy(myAnswer = null, going = listOf(sam, rui), coverUrl = null, plan = plan(cover = null))))
    @Test fun pageMaybe() = snap("plans.page", "upcoming-maybe", content = planPage(page.copy(myAnswer = PlanAnswerKind.Maybe, going = listOf(sam, rui), maybe = listOf(zoe, ana))))
    @Test fun pageCantGo() = snap("plans.page", "upcoming-cantGo", content = planPage(page.copy(myAnswer = PlanAnswerKind.CantGo, going = listOf(sam, rui), cantGo = listOf(ana))))
    @Test fun pageCantGoSheet() = snap(
        "plans.page", "peopleSheet-cantGo",
        act = { compose.onNodeWithText("Sam and Rui", substring = true).performClick() },
        content = planPage(page.copy(myAnswer = PlanAnswerKind.CantGo, going = listOf(sam, rui), maybe = listOf(zoe), cantGo = listOf(ana))),
    )
    @Test fun pageManagerMenu() = snap(
        "plans.page", "upcoming-menu",
        act = { compose.onNodeWithContentDescription(context.getString(app.designsystem.R.string.plans_page_more_accessibilitylabel)).performClick() },
        content = planPage(page.copy(canManage = true)),
    )
    @Test fun pageNobodyAnswered() = snap("plans.page", "upcoming-nobodyAnswered", content = planPage(page.copy(myAnswer = null, going = emptyList(), maybe = emptyList())))
    @Test fun pageCanceled() = snap("plans.page", "canceled", content = planPage(page.copy(plan = plan(canceled = true), canManage = true)))
    @Test fun pageCanceledDark() = snap("plans.page", "canceled", dark = true, content = planPage(page.copy(plan = plan(canceled = true), canManage = true)))
    private val pastPhotos = listOf("picnic-spread-3x4", "friends-picnic-blanket-3x4", "dinner-toast-candles-3x4", "campfire-woods-3x4", "autumn-path-3x4").mapIndexed { i, name ->
        PlanPhoto(Post("ph$i", "m$i", "g1", "u-sam", null, null, null, null, false, null, now), photo(name))
    }
    @Test fun pagePast() = snap("plans.page", "past", content = planPage(page.copy(plan = plan(day = "2026-10-10"), photos = pastPhotos)))
    @Test fun pagePastNoPhotos() = snap("plans.page", "past-noPhotos", content = planPage(page.copy(plan = plan(day = "2026-10-10", cover = null), coverUrl = null)))
    @Test fun pageOffline() = snap("plans.page", "offline", content = planPage(page.copy(online = false)))
    @Test fun pageNotFound() = snap("plans.page", "notFound", content = planPage(PlanPageUiState(notFound = true)))
    @Test fun pageError() = snap("plans.page", "error", content = planPage(PlanPageUiState(error = true)))

    // question.weekly --------------------------------------------------------------------------------------
    private val question = "What made you laugh this week?"
    private fun card(answers: Boolean) = @Composable {
        Box(Modifier.fillMaxSize().background(PageRoles.page).padding(start = Tokens.Sizes.globalScreenMargin)) {
            QuestionCard(question, if (answers) photo("friends-floor-laughing-3x4") else null, hasAnswers = answers, onAnswer = {}, onOpenAnswers = {}, onRemove = {})
        }
    }
    @Test fun questionNoAnswers() = snap("question.weekly", "card-noAnswers", content = card(false))
    @Test fun questionNoAnswersDark() = snap("question.weekly", "card-noAnswers", dark = true, content = card(false))
    @Test fun questionAnswers() = snap("question.weekly", "card-answers", content = card(true))
    @Test fun questionAnswersDark() = snap("question.weekly", "card-answers", dark = true, content = card(true))
    @Test fun questionLong() = snap("question.weekly", "card-longQuestion", content = @Composable {
        Box(Modifier.fillMaxSize().background(PageRoles.page).padding(start = Tokens.Sizes.globalScreenMargin)) {
            QuestionCard(context.getString(app.designsystem.R.string.question_weekly_q08), null, hasAnswers = false, onAnswer = {}, onOpenAnswers = {}, onRemove = {})
        }
    })

    // groups.screen with the new entries ---------------------------------------------------------------------
    private val group = Group("g1", "Sunday Dinners", GroupKind.Friends, "covers/g1.jpg", "UTC", null, null, false, "u-me", now.minusSeconds(40 * 86400L), now)
    private fun item(id: String, author: String, first: String, face: String, at: String, picture: String) =
        GroupPhoto(Post(id, "m$id", "g1", author, null, null, null, null, true, null, Instant.parse(at)), photo(picture), first, photo(face), mine = author == "u-me")
    private val photos = listOf(
        item("p1", "u-sam", "Sam", "avatar-02", "2026-10-15T14:00:00Z", "dinner-pizza-cheers-3x4"),
        item("p2", "u-me", "Ana", "avatar-01", "2026-10-14T19:30:00Z", "friends-picnic-blanket-3x4"),
        item("p3", "u-rui", "Rui", "avatar-06", "2026-10-13T09:10:00Z", "coffee-latte-heart-3x4"),
        item("p5", "u-rui", "Rui", "avatar-06", "2026-10-10T20:00:00Z", "campfire-woods-3x4"),
    )
    private val feed = GroupFeedUiState(group = group, coverUrl = photo("dinner-long-table-3x4"), photos = photos, isCreator = true, memberAvatars = listOf(photo("avatar-01"), photo("avatar-02"), photo("avatar-06")))
    private fun groupScreen(state: GroupFeedUiState, developing: Boolean = false, planRow: Boolean = false, questionCard: Boolean = false) = @Composable {
        GroupFeedScreen(
            state, now, utc, GroupScreenActions(),
            developing = if (developing) developingTile(Developing(true, Instant.parse("2026-10-16T09:00:00Z"))) else null,
            planRows = {
                if (planRow) PlanRow(NextPlanRow("p1", "Picnic at the lake", PlanFormats.rowLine(plan().startsAt, false, plan().localDate, utc)), onOpen = {}, onCreate = {})
            },
            feedCards = { if (questionCard) QuestionCard(question, null, hasAnswers = false, onAnswer = {}, onOpenAnswers = {}, onRemove = {}) },
        )
    }
    @Test fun groupDeveloping() = snap("groups.screen", "developing", content = groupScreen(feed, developing = true))
    @Test fun groupDevelopingDark() = snap("groups.screen", "developing", dark = true, content = groupScreen(feed, developing = true))
    @Test fun groupDevelopingEmptyWeek() = snap("groups.screen", "developing-emptyWeek", content = groupScreen(feed.copy(photos = photos.takeLast(1)), developing = true))
    @Test fun groupMakeAPlanRow() = snap(
        "groups.screen", "planRow-none",
        content = @Composable { GroupFeedScreen(feed, now, utc, GroupScreenActions(), planRows = { PlanRow(null, onOpen = {}, onCreate = {}) }) },
    )
    @Test fun groupPlanRowDark() = snap("groups.screen", "planRow", dark = true, content = groupScreen(feed, planRow = true))
    @Test fun groupPlanRowAndQuestion() = snap(
        "groups.screen", "planRow-question",
        // Brings the question card into view (one merged element labelled with the question), then the pager to the top.
        act = {
            compose.onNodeWithTag(GROUP_SCREEN_LIST_TAG).performScrollToNode(hasContentDescription(question, substring = true))
            compose.onNodeWithTag(GROUP_SCREEN_LIST_TAG).performScrollToKey("pager")
        },
        content = groupScreen(feed, planRow = true, questionCard = true),
    )

    // widget.countdown -------------------------------------------------------------------------------------
    private val widgetStore get() = CountdownStore.default(context)
    private val widgetMeta get() = WidgetGroupMeta.of(WidgetFileStore.default(context))
    private val small = DpSize(158.dp, 158.dp)
    private val medium = WidgetSizeClass.Medium.minSize

    private fun writeCountdown(vararg plans: CountdownPlan) = widgetStore.write(CountdownSnapshot(plans.toList(), 0))

    private fun coverPlan(day: String): CountdownPlan {
        val name = CountdownStore.coverName("u/u-sam/covers/picnic.jpg")
        widgetStore.writeCover(name, SamplePhotos.file("picnic-spread-3x4").readBytes())
        return CountdownPlan("p1", "g1", "Sunday Dinners", "Picnic at the lake", day, name)
    }

    private fun renderWidget(size: DpSize): Bitmap = runBlocking {
        val views = CountdownWidget().compose(context, size = size, state = mutablePreferencesOf())
        val view: View = views.apply(context, FrameLayout(context))
        val density = context.resources.displayMetrics.density
        val w = (size.width.value * density).toInt()
        val h = (size.height.value * density).toInt()
        view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
        view.layout(0, 0, w, h)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bitmap))
        cornerMask(bitmap)
    }

    /** Android 12+ clips the widget root to `widget.android.radius.widget`; a software draw does not, so the test applies it. */
    private fun cornerMask(src: Bitmap): Bitmap {
        val r = Tokens.Radii.widgetAndroidRadiusWidget.value * context.resources.displayMetrics.density
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        c.drawColor(0xFF808080.toInt()) // test backdrop (a neutral home screen), not app UI
        val layer = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val lc = Canvas(layer)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        lc.drawRoundRect(RectF(0f, 0f, src.width.toFloat(), src.height.toFloat()), r, r, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        lc.drawBitmap(src, 0f, 0f, paint)
        c.drawBitmap(layer, 0f, 0f, null)
        return out
    }

    private fun widget(name: String, bitmap: Bitmap) = bitmap.captureRoboImage("src/test/snapshots/widget.countdown/$name.png")

    @Before fun countdownSetUp() {
        widgetStore.clear()
        WidgetFileStore.default(context).root.deleteRecursively()
        widgetMeta.root.deleteRecursively()
        CountdownClock.today = { LocalDate.parse("2026-10-15") }
    }

    @After fun countdownTearDown() {
        CountdownClock.today = { LocalDate.now() }
    }

    @Test fun countdownInDays() {
        writeCountdown(coverPlan("2026-10-24"))
        widget("small_inDays", renderWidget(small))
        widget("medium_inDays", renderWidget(medium))
    }

    @Test fun countdownInDaysDark() {
        RuntimeEnvironment.setQualifiers("+night")
        writeCountdown(coverPlan("2026-10-24"))
        widget("small_inDays-dark", renderWidget(small))
    }

    @Test fun countdownTomorrowWithoutAPhoto() {
        writeCountdown(CountdownPlan("p2", "g2", "Lima Family", "Grandma's birthday lunch", "2026-10-16"))
        widget("small_tomorrow-noPhoto", renderWidget(small))
        widget("medium_tomorrow-noPhoto", renderWidget(medium))
    }

    @Test fun countdownToday() {
        writeCountdown(coverPlan("2026-10-15"))
        widget("small_today", renderWidget(small))
    }

    @Test fun countdownFallsThroughToTheNextPlanAfterItsDay() {
        writeCountdown(CountdownPlan("p0", "g1", "Sunday Dinners", "Yesterday's dinner", "2026-10-14"), coverPlan("2026-10-18"))
        widget("small_nextAfterPast", renderWidget(small))
    }

    @Test fun countdownStates() {
        widget("small_loading", renderWidget(small))
        writeCountdown()
        widget("small_noPlans", renderWidget(small))
        widget("medium_noPlans", renderWidget(medium))
        widgetMeta.setSignedOut(true)
        widget("small_signedOut", renderWidget(small))
    }

    private companion object {
        const val FRAME_MS = 16L
        const val SHEET_MS = 1_000L
    }
}
