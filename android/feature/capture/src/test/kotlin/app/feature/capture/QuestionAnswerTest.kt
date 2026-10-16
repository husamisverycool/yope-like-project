package app.feature.capture

import android.content.Context
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.MediaKind
import app.designsystem.LocalReduceMotionOverride
import app.feature.capture.camera.CameraQuestion
import app.feature.capture.camera.CameraScreen
import app.feature.capture.camera.CameraViewModel
import app.feature.capture.camera.OvernightChrome
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CapturedMedia
import app.feature.capture.sendto.SendToViewModel
import app.model.SessionPromptGate
import app.ui.copy.WeeklyQuestions
import app.ui.theme.AppTheme
import com.github.takahirom.roborazzi.captureScreenRoboImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

/**
 * `question.weekly` B (answering) on the capture side: the camera opened from the question card carries the question to
 * send-to, which links only the post to the camera's group (the upload pipeline calls `answer_question` after posting);
 * the camera shows the question pill on the viewfinder. Snapshot at the capture group's 393 × 852 dp, 3×.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xxhdpi")
class QuestionAnswerTest {
    @get:Rule val compose = createComposeRule()
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val dir = File(context.cacheDir, "question-test").apply { deleteRecursively(); mkdirs() }
    private val data = FakeCaptureData()
    private val handoff = CaptureHandoff()

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    private fun media() = CapturedMedia(MediaKind.Photo, Images.photoFile(dir, "q-${System.nanoTime()}.jpg"), 300, 400, null, fromLibrary = false)

    @Test fun onlyThePostToTheQuestionsGroupAnswersIt() {
        data.loaded(group("g1", "Family"), group("g2", "Roommates"))
        handoff.put(media(), "g1", questionId = "q1")
        val vm = SendToViewModel(data, handoff, SessionPromptGate(), voiceRecorderAvailable = false)
        vm.toggle("g2")
        vm.send()
        val post = data.enqueued.single()
        assertEquals(setOf("g1", "g2"), post.groupIds.toSet())
        assertEquals("q1", post.questionId)
        assertEquals("g1", post.questionGroupId)
    }

    @Test fun anOrdinaryCaptureAnswersNothing() {
        data.loaded(group("g1", "Family"))
        handoff.put(media(), "g1")
        SendToViewModel(data, handoff, SessionPromptGate(), voiceRecorderAvailable = false).send()
        assertNull(data.enqueued.single().questionId)
        assertNull(data.enqueued.single().questionGroupId)
    }

    @Test fun theQuestionNeedsBothItsIdAndAKeyWithCopy() {
        assertEquals(CameraQuestion("q1", "question.weekly.q01"), CameraQuestion.from("q1", "question.weekly.q01"))
        assertNull(CameraQuestion.from("q1", null))
        assertNull(CameraQuestion.from(null, "question.weekly.q01"))
        assertEquals("What made you laugh this week?", WeeklyQuestions.text(context, "question.weekly.q01"))
        assertNull(WeeklyQuestions.text(context, "question.weekly.zz99"))
        assertNull(WeeklyQuestions.text(context, "auth.phone.title"))
    }

    @Test fun cameraShowsTheQuestionPill() {
        val question = "What made you laugh this week?"
        val live = CameraViewModel.UiState(permission = CameraViewModel.Permission.Granted, session = CameraViewModel.Session.Live, hasFlash = true, coachDone = false, videoAvailable = true)
        val photo = Images.photo(900, 1200, 0).asImageBitmap()
        compose.mainClock.autoAdvance = false
        compose.setContent {
            CompositionLocalProvider(LocalReduceMotionOverride provides false) {
                AppTheme(dark = false) {
                    CameraScreen(
                        state = live,
                        viewfinder = { Image(photo, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) },
                        title = "Week 42",
                        onShutterTap = {}, onShutterLongPress = {}, onShutterRelease = {}, onFlash = {}, onFlip = {}, onLibrary = {},
                        onCoachClose = {}, onOpenSettings = {}, onRetry = {},
                        questionText = question,
                        overnight = OvernightChrome(time = "9:00 AM"),
                    )
                }
            }
        }
        compose.mainClock.advanceTimeBy(SETTLE_MS)
        // Not a button; read as "Answering: {question}". The coach pill gives way to it.
        compose.onNodeWithContentDescription("Answering: $question").assertExists()
        captureScreenRoboImage("src/test/snapshots/question.weekly_camera-pill.png")
    }

    private companion object {
        const val SETTLE_MS = 1_000L
    }
}
