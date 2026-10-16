package app.feature.social

import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.data.SocialData
import app.feature.social.viewer.PhotoViewerViewModel
import app.model.PhotoContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/** `question.weekly`: the card opens the week's answers in the viewer, oldest first, and only those (`question_answers`). */
@OptIn(ExperimentalCoroutinesApi::class)
class QuestionViewerTest {
    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun theQuestionContextIsItsAnswersOldestFirst() {
        val fake = FakeSocialData().apply { seedAlbums() }
        val data = object : SocialData by fake {
            override suspend fun questionAnswers(questionId: String): List<String> = if (questionId == "q-1") listOf("w-2", "w-5", "w-6") else emptyList()
        }
        val vm = PhotoViewerViewModel(data, GROUP, "w-2", PhotoContext.Question, "q-1", null)
        assertEquals(listOf("w-2", "w-5", "w-6"), vm.state.value.photos.map { it.postId })
        assertEquals(0, vm.state.value.index)
    }
}
