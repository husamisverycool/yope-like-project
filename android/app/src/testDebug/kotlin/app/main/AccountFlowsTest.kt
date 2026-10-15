package app.main

import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.GroupInvite
import app.data.model.MemberRole
import app.feature.account.AccountEnvironment
import app.feature.account.groups.GroupsListViewModel
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.FakeStores
import app.feature.account.testing.fakeEnvironment
import app.model.AppRoute
import app.model.DeepLink
import app.ui.theme.AppTheme
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableSharedFlow
import androidx.compose.runtime.CompositionLocalProvider
import app.feature.memory.common.LocalMemoryBackend
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.UnconfiguredMemoryBackend
import app.data.model.OnThisDayItem
import app.model.OnThisDayRoute
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * The account group's flows through the real navigation graph and shell (Robolectric Compose):
 * sign-up → onboarding → home; create a group; join from an App Link and from the Play install
 * referrer; leave a group; delete the account (confirmation). Text matches use the screens' own copy
 * (en); field values are test data.
 */
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class AccountFlowsTest {
    @get:Rule val compose = createComposeRule()
    private val links = MutableSharedFlow<DeepLink>(extraBufferCapacity = 4)
    private lateinit var nav: NavHostController

    @After fun clear() = GroupsListViewModel.Details.byGroup.clear()

    private companion object {
        const val WAIT_MS = 5_000L
    }

    private fun start(env: AccountEnvironment, memory: MemoryBackend? = null) {
        compose.setContent {
            nav = rememberNavController()
            CompositionLocalProvider(LocalMemoryBackend provides memory) {
                AppTheme { AppNavHost(links, nav, env) }
            }
        }
        compose.waitForIdle()
    }

    private fun text(value: String): SemanticsNodeInteraction = compose.onNode(hasText(value), useUnmergedTree = true)
    private fun field(label: String) = compose.onNode(hasContentDescription(label) and hasSetTextAction())
    private inline fun <reified T : Any> at() = assertTrue("at ${nav.currentDestination?.route}", nav.currentDestination!!.hasRoute<T>())

    private fun invite(backend: FakeAccountBackend, token: String = "AbCdEfGhIjKlMnOpQrStUvWx") = backend.apply {
        profile("u-sam", "Sam Lee")
        group("g9", "Book club", createdBy = "u-sam")
        member("g9", "u-sam", MemberRole.Admin)
        invites += GroupInvite("i9", "g9", token, "u-sam", now, now.plusSeconds(3600), null)
    }

    /** auth.phone → auth.code → auth.agegate → auth.profile → notifications → widget. */
    private fun signUp(backend: FakeAccountBackend) {
        text("sign up or log in").assertExists()
        field("phone number").performTextInput(" 415 555 0100")
        text("continue").performClick()
        compose.waitForIdle()
        at<AppRoute.AuthCode>()
        field("verification code").performTextInput(backend.validCode)
        text("continue").performClick()
        compose.waitForIdle()
        at<AppRoute.AuthAgeGate>()
        field("birthday").performTextInput("03142001")
        text("continue").performClick()
        compose.waitForIdle()
        at<AppRoute.AuthProfile>()
        field("your name").performTextInput("Ana Lima")
        text("continue").performClick()
        compose.waitForIdle()
        at<AppRoute.PermissionNotifications>()
        text("maybe later").performClick()
        compose.waitForIdle()
        at<AppRoute.OnboardingWidget>()
        text("Continue").performClick()
        compose.waitForIdle()
    }

    @Test fun signUpThenOnboardingThenHome() {
        val backend = FakeAccountBackend()
        val stores = FakeStores()
        start(fakeEnvironment(backend, stores))
        at<AppRoute.AuthPhone>()
        signUp(backend)
        at<AppRoute.GroupsList>()
        text("create group").assertExists()
        assertEquals(listOf("requestOtp", "verifyOtp"), backend.calls.filter { it == "requestOtp" || it == "verifyOtp" })
        assertTrue(backend.ageConfirmed)
        assertEquals("Ana Lima", backend.profiles.getValue(backend.meId).displayName)
        assertTrue(stores.isOnboardingDone(backend.meId))
        // Sign-up steps cannot be returned to with Back once home.
        assertFalse(nav.popBackStack())
    }

    @Test fun createAGroupFromTheEmptyHome() {
        val backend = FakeAccountBackend().apply { signIn(); ageConfirmed = true; profile(meId, "Ana Lima") }
        start(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }))
        at<AppRoute.GroupsList>()
        text("create group").performClick()
        compose.waitForIdle()
        at<AppRoute.GroupCreate>()
        field("group name").performTextInput("Book club")
        text("family").performClick()
        text("create group").performClick()
        compose.waitForIdle()
        at<AppRoute.Group>()
        text("you created group").assertExists()
        text("invite more family").assertExists()
        assertEquals("Book club", backend.groups.values.single().name)
        // Back from the new group returns home (the create sheet closed).
        nav.popBackStack()
        compose.waitForIdle()
        at<AppRoute.GroupsList>()
        text("Book club").assertExists()
    }

    @Test fun inviteAppLinkJoinsAndOpensTheGroup() {
        val backend = invite(FakeAccountBackend().apply { signIn(); ageConfirmed = true; profile(meId, "Ana Lima") })
        val stores = FakeStores().apply { onboarded += backend.meId }
        start(fakeEnvironment(backend, stores))
        links.tryEmit(DeepLink.Invite("AbCdEfGhIjKlMnOpQrStUvWx"))
        compose.waitForIdle()
        at<AppRoute.Group>()
        text("Book club").assertExists()
        assertTrue(backend.members.getValue("g9").any { it.userId == backend.meId })
        assertNull(stores.pendingInviteToken)
        nav.popBackStack()
        compose.waitForIdle()
        at<AppRoute.GroupsList>()
    }

    @Test fun installReferrerInviteJoinsAfterSignUp() {
        val backend = invite(FakeAccountBackend())
        // What App.readInstallReferrerOnce stores from `invite_token=<token>`.
        val stores = FakeStores().apply { pendingInviteToken = "AbCdEfGhIjKlMnOpQrStUvWx" }
        start(fakeEnvironment(backend, stores))
        signUp(backend)
        at<AppRoute.Group>()
        text("Book club").assertExists()
        assertTrue(backend.members.getValue("g9").any { it.userId == backend.meId })
    }

    @Test fun expiredInviteShowsTheLinkState() {
        val backend = FakeAccountBackend().apply { signIn(); ageConfirmed = true; profile(meId, "Ana Lima") }
        start(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }, preview = app.feature.account.invite.InvitePreviewResult.Unavailable))
        links.tryEmit(DeepLink.Invite("AbCdEfGhIjKlMnOpQrStUvWx"))
        compose.waitForIdle()
        at<AppRoute.InviteJoin>()
        text("THIS LINK NO LONGER WORKS").assertExists()
    }

    @Test fun leaveAGroupFromItsSettings() {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana Lima"); profile("u-sam", "Sam Lee")
            group("g1", "Sunday dinners"); member("g1", meId, MemberRole.Admin); member("g1", "u-sam")
            group("g2", "Roomies"); member("g2", meId, MemberRole.Admin)
        }
        start(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }))
        text("Sunday dinners").assertExists()
        compose.runOnIdle { nav.navigate(AppRoute.GroupSettings("g1")) }
        compose.waitForIdle()
        compose.onNode(hasScrollAction()).performScrollToNode(hasText("leave group"))
        compose.onNode(hasText("leave group")).performClick()
        compose.waitForIdle()
        text("Leave Sunday dinners?").assertExists()
        text("Leave").performClick()
        compose.waitForIdle()
        at<AppRoute.GroupsList>()
        text("Sunday dinners").assertDoesNotExist()
        text("Roomies").assertExists()
        assertTrue("leaveGroup" in backend.calls)
    }

    @Test fun deleteAccountAsksThenSignsOut() {
        val backend = FakeAccountBackend().apply { signIn(); ageConfirmed = true; profile(meId, "Ana Lima") }
        start(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }))
        compose.runOnIdle { nav.navigate(AppRoute.SettingsAccount) }
        compose.waitForIdle()
        text("Delete Account").performClick()
        compose.waitForIdle()
        text("Delete your account?").assertExists()
        // Cancel keeps everything.
        text("Cancel").performClick()
        compose.waitForIdle()
        assertFalse(backend.accountDeleted)
        text("Delete Account").performClick()
        compose.waitForIdle()
        text("Delete").performClick()
        compose.waitForIdle()
        assertTrue(backend.accountDeleted)
        at<AppRoute.AuthPhone>()
        text("sign up or log in").assertExists()
    }

    /** camera.capture → In: "app launch (the app opens to the camera)", over groups.list. */
    @Test fun launchWithAGroupOpensTheCameraOverHome() {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana Lima")
            group("g1", "Sunday dinners"); member("g1", meId, MemberRole.Admin)
        }
        start(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }, launchToCamera = true))
        at<AppRoute.Camera>()
        assertTrue(nav.previousBackStackEntry!!.destination.hasRoute<AppRoute.GroupsList>())
        // The tab bar sits under the camera; Groups goes home.
        compose.onNode(hasContentDescription("groups")).performClick()
        compose.waitForIdle()
        at<AppRoute.GroupsList>()
    }

    @Test fun launchWithoutGroupsStaysHome() {
        val backend = FakeAccountBackend().apply { signIn(); ageConfirmed = true; profile(meId, "Ana Lima") }
        start(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }, launchToCamera = true))
        at<AppRoute.GroupsList>()
    }

    /** The memory pass's entry sits above the feed and opens the day (onthisday.md → A). */
    @Test fun onThisDayEntryOpensTheDay() {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana Lima")
            group("g1", "Sunday dinners"); member("g1", meId, MemberRole.Admin)
        }
        backend.post("g1", backend.meId, backend.now)
        val group = backend.groups.getValue("g1")
        val memory = object : MemoryBackend by UnconfiguredMemoryBackend {
            override suspend fun group(groupId: String) = group
            override suspend fun onThisDay(groupId: String, localDate: java.time.LocalDate) =
                listOf(OnThisDayItem("p0", "m0", backend.meId, backend.now.minus(java.time.Duration.ofDays(365)), 1))
        }
        start(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }), memory)
        compose.runOnIdle { nav.navigate(AppRoute.Group("g1")) }
        compose.waitForIdle()
        compose.waitUntil(WAIT_MS) { compose.onAllNodes(hasText("Day in History", substring = true)).fetchSemanticsNodes().isNotEmpty() }
        compose.onNode(hasText("Day in History", substring = true)).performClick()
        compose.waitForIdle()
        assertTrue("at ${nav.currentDestination?.route}", nav.currentBackStack.value.any { it.destination.hasRoute<OnThisDayRoute>() })
    }

    @Test fun cachedGroupsShowWithoutASpinnerWhileRefreshing() {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana Lima")
            group("g1", "Sunday dinners"); member("g1", meId, MemberRole.Admin)
            cachedGroups = groups.values.toList()
            gates["myGroups"] = CompletableDeferred()
        }
        start(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }))
        // Network still pending: the cached card is already there and no Loading HUD shows.
        text("Sunday dinners").assertExists()
        text("Loading").assertDoesNotExist()
        backend.gates.getValue("myGroups").complete(Unit)
        compose.waitForIdle()
        text("Sunday dinners").assertExists()
    }
}
