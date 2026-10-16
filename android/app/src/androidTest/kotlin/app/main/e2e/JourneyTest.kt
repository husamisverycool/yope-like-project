package app.main.e2e

import android.Manifest
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.annotation.StringRes
import androidx.compose.ui.test.ComposeTimeoutException
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasScrollToNodeAction
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
import androidx.compose.ui.test.performTouchInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import app.designsystem.R
import app.main.MainActivity
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.rules.TestWatcher
import org.junit.runner.Description
import org.junit.runner.RunWith
import java.time.LocalDate
import java.time.chrono.IsoChronology
import java.time.format.DateTimeFormatterBuilder
import java.time.format.FormatStyle
import java.util.Locale

/**
 * The app end to end on a device against a real Supabase stack (CI job "android e2e": the emulator reaches the job's
 * `supabase start` at 10.0.2.2). Nothing in the app is faked except the camera's image (the emulator camera cannot take
 * a real photo) and the invite-link host (`config/app.json` `domain` is BLOCKED): see [E2eRunner].
 *
 * Journey, as two people on one device:
 * 1. Maya signs up with a test phone number (the stack's test OTP), passes the age gate, gives her name, skips the photo,
 *    notification and widget steps; creates a family group; opens the invite sheet, turns link sharing on and copies the
 *    link; posts a photo from the camera through send-to; sees it in the group, opens it in the viewer and reacts; sends
 *    a chat message; sees the photo on her wall; opens settings and signs out.
 * 2. Theo opens Maya's invite link, signs up from the invite card, joins the group at the end of onboarding and sees
 *    Maya's photo in the group and in the viewer.
 * Each step leaves a screenshot and the semantics tree (see [Evidence]) for the CI artifact.
 *
 * The stack needs: the test OTPs below (`[auth.sms.test_otp]`, added by the CI job; never in backend/supabase/config.toml,
 * which `supabase config push` sends to the hosted project) and `min_age_years` set (the age gate fails closed without
 * it). Run locally: `supabase start` (with those two settings), an emulator, then
 * `./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.supabaseUrl=http://10.0.2.2:54321
 * -Pandroid.testInstrumentationRunnerArguments.supabaseAnonKey=<anon key>` on a fresh stack (the accounts are created).
 * Text is matched through the app's own string resources, so copy edits do not break the journey.
 */
@RunWith(AndroidJUnit4::class)
class JourneyTest {
    private val compose = createAndroidComposeRule<MainActivity>()
    private val evidence = Evidence(compose)
    private val watcher = object : TestWatcher() {
        override fun failed(e: Throwable?, description: Description) {
            Log.e(E2eRunner.TAG, "failed: ${description.methodName}", e)
            evidence.failure(description.methodName)
            Log.e(E2eRunner.TAG, evidence.semantics())
        }
    }

    // The camera permission is the system dialog the test cannot answer (camera.capture asks on first open, with no
    // pre-prompt); notifications keep their in-app pre-prompt and are skipped with "Maybe later".
    @get:Rule val rules: RuleChain = RuleChain
        .outerRule(GrantPermissionRule.grant(Manifest.permission.CAMERA))
        .around(compose)
        .around(watcher)

    private val context: Context get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Before fun requireStack() {
        assumeTrue("no supabaseUrl / supabaseAnonKey instrumentation arguments: nothing to run against", E2eRunner.configured)
    }

    @Test fun signUpPostChatReactAndAFriendJoinsByInvite() {
        // ---- Maya ----
        signUp(MAYA, "maya")
        evidence.step("maya-groups-empty")

        tap(text(R.string.groups_list_empty_button))
        waitFor(text(R.string.groups_create_type_family))
        evidence.step("maya-create-kind")
        tap(text(R.string.groups_create_type_family))
        type(field(R.string.groups_create_name_accessibilitylabel), GROUP)
        evidence.step("maya-create-name")
        tap(text(R.string.groups_create_cta))
        waitFor(text(R.string.groups_screen_created_title), LONG)
        evidence.step("maya-group-created")

        // Invite sheet: link sharing on, the link copied.
        tap(text(R.string.groups_screen_created_invite_family))
        waitFor(text(R.string.groups_invite_link_turnon), LONG)
        evidence.step("maya-invite-off")
        tap(text(R.string.groups_invite_link_turnon))
        waitFor(text(R.string.groups_invite_link_copy), LONG)
        evidence.step("maya-invite-on")
        tap(text(R.string.groups_invite_link_copy))
        val link = clipboardText()
        assertTrue("invite link copied: $link", link?.startsWith("https://${E2eRunner.E2E_INVITE_HOST}/i/") == true)
        tap(desc(R.string.groups_invite_close_accessibilitylabel))
        waitFor(text(R.string.groups_screen_created_title))

        // A photo: group → camera → send-to → posted.
        tap(desc(R.string.groups_screen_week_add_accessibilitylabel))
        waitFor(hasTestTag("camera.shutter"), LONG)
        evidence.step("maya-camera")
        // The shutter ignores taps until the session is live (camera.capture): tap again while send-to has not opened.
        retry(attempts = 3, until = hasTestTag("camera.sendto")) { tap(hasTestTag("camera.shutter")) }
        waitFor(hasText(GROUP))
        evidence.step("maya-sendto")
        tap(hasTestTag("sendto.send"))
        waitGone(hasTestTag("camera.sendto"), UPLOAD)
        val mayaPhoto = descContaining(after(R.string.groups_screen_photo_accessibilitylabel, 2, "Maya"))
        waitFor(mayaPhoto, UPLOAD)
        evidence.step("maya-group-with-post")

        // Viewer + a reaction from the photo's menu.
        tap(mayaPhoto)
        waitFor(hasTestTag("photo.viewer"), LONG)
        waitFor(descContaining(before(R.string.photo_viewer_a11y_photomine, 1)), LONG)
        evidence.step("maya-viewer")
        node(hasTestTag("viewer.photo")).performTouchInput { longClick() }
        val react = descContaining(before(R.string.chat_reactions_a11y_quick, 1))
        waitFor(react)
        evidence.step("maya-viewer-react-menu")
        compose.onAllNodes(react).onFirst().performClick()
        waitFor(descContaining(before(R.string.chat_reactions_a11y_cluster, 1)), LONG)
        evidence.step("maya-viewer-reacted")
        tap(desc(R.string.photo_viewer_a11y_close))
        waitFor(mayaPhoto)

        // Chat: a message.
        tap(desc(R.string.groups_screen_chat))
        // The thread's only text field is the composer.
        val composer = hasSetTextAction()
        waitFor(composer, LONG)
        evidence.step("maya-chat")
        type(composer, MESSAGE)
        tap(desc(R.string.chat_composer_a11y_send))
        waitFor(desc(context.getString(R.string.chat_thread_a11y_messagemine, MESSAGE)), LONG)
        evidence.step("maya-chat-sent")
        tap(desc(R.string.chat_thread_a11y_back))

        // Home, then the wall (Profile tab).
        tap(desc(R.string.groups_screen_back_accessibilitylabel))
        waitFor(hasText(GROUP), LONG)
        evidence.step("maya-groups")
        tap(desc(R.string.groups_list_tab_me_accessibilitylabel))
        waitFor(hasTestTag("walls.mine"), LONG)
        waitFor(descContaining(before(R.string.photo_viewer_a11y_photomine, 1)), LONG)
        evidence.step("maya-wall")

        // Settings → sign out.
        tap(desc(R.string.walls_mine_a11y_settings))
        waitFor(text(R.string.settings_root_title), LONG)
        evidence.step("maya-settings")
        scrollTo(text(R.string.settings_root_signout))
        tap(text(R.string.settings_root_signout))
        waitFor(text(R.string.settings_root_signout_confirm))
        evidence.step("maya-signout-confirm")
        tap(text(R.string.settings_root_signout_confirm))
        waitFor(text(R.string.auth_phone_getstarted), LONG)
        evidence.step("maya-signed-out")

        // ---- Theo, from Maya's invite link ----
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(link)).setClassName(context, MainActivity::class.java.name).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        waitFor(text(R.string.invite_web_cta), LONG)
        evidence.step("theo-invite-card")
        tap(text(R.string.invite_web_cta))
        signUp(THEO, "theo")
        // The pending invite joins at the end of onboarding and opens the group.
        waitFor(mayaPhoto, LONG)
        evidence.step("theo-group")
        tap(mayaPhoto)
        waitFor(descContaining(context.getString(R.string.photo_viewer_a11y_photo, "Maya", "\u0000").substringBefore('\u0000')), LONG)
        evidence.step("theo-viewer")
    }

    // ---- Sign-up: auth.phone → auth.code → auth.agegate → auth.profile → onboarding ----

    private fun signUp(person: Person, who: String) {
        waitFor(text(R.string.auth_phone_getstarted), LONG)
        evidence.step("$who-landing")
        tap(text(R.string.auth_phone_getstarted))
        val phone = field(R.string.auth_phone_field_accessibilitylabel)
        waitFor(phone)
        node(phone).performTextReplacement(person.phone)
        evidence.step("$who-phone")
        tap(text(R.string.auth_phone_continue))

        val code = field(R.string.auth_code_field_accessibilitylabel)
        waitFor(code, LONG)
        type(code, TEST_OTP)
        evidence.step("$who-code")
        tapIfPresent(text(R.string.auth_code_continue))

        val birthday = field(R.string.auth_agegate_field_accessibilitylabel)
        waitFor(birthday, LONG)
        type(birthday, birthdayDigits(BIRTHDAY))
        evidence.step("$who-agegate")
        tap(text(R.string.auth_agegate_continue))

        val name = field(R.string.auth_profile_field_accessibilitylabel)
        waitFor(name, LONG)
        type(name, person.name)
        evidence.step("$who-name")
        tap(text(R.string.auth_profile_continue))
        waitFor(text(R.string.auth_profile_photo_skip), LONG)
        evidence.step("$who-photo-step")
        tap(text(R.string.auth_profile_photo_skip))

        // Android 13+: the notifications pre-prompt (its "Maybe later" never opens the system dialog).
        val notificationsSkip = text(R.string.onboarding_permission_notifications_skip)
        val widgetSkip = text(R.string.onboarding_widget_skip)
        waitForAny(LONG, notificationsSkip, widgetSkip)
        if (exists(text(R.string.onboarding_permission_notifications_title))) {
            evidence.step("$who-notifications")
            tap(notificationsSkip)
        }
        waitFor(text(R.string.onboarding_widget_title), LONG)
        evidence.step("$who-widget")
        tap(widgetSkip)
    }

    // ---- Finders ----

    private fun text(@StringRes id: Int): SemanticsMatcher = hasText(context.getString(id))
    private fun desc(@StringRes id: Int): SemanticsMatcher = hasContentDescription(context.getString(id))
    private fun desc(value: String): SemanticsMatcher = hasContentDescription(value)
    private fun descContaining(part: String): SemanticsMatcher = hasContentDescription(part, substring = true)
    private fun field(@StringRes label: Int): SemanticsMatcher = hasSetTextAction() and hasContentDescription(context.getString(label))

    /** The text of a format string before its first argument (args filled with a marker). */
    private fun before(@StringRes id: Int, args: Int): String = context.getString(id, *Array(args) { MARK }).substringBefore(MARK)

    /** The text of a format string after its first argument, the remaining arguments filled in order. */
    private fun after(@StringRes id: Int, args: Int, vararg rest: String): String {
        val values = Array(args) { i -> if (i == 0) MARK else rest.getOrElse(i - 1) { "" } }
        return context.getString(id, *values).substringAfter(MARK)
    }

    private fun node(matcher: SemanticsMatcher): SemanticsNodeInteraction = compose.onAllNodes(matcher).onFirst()

    private fun exists(matcher: SemanticsMatcher): Boolean =
        compose.onAllNodes(matcher).fetchSemanticsNodes(atLeastOneRootRequired = false).isNotEmpty()

    // ---- Actions and waits ----

    private fun tap(matcher: SemanticsMatcher, timeout: Long = SHORT) {
        waitFor(matcher, timeout)
        node(matcher).performClick()
        compose.waitForIdle()
    }

    private fun tapIfPresent(matcher: SemanticsMatcher) {
        compose.waitForIdle()
        if (exists(matcher)) runCatching { node(matcher).performClick() }
        compose.waitForIdle()
    }

    private fun type(matcher: SemanticsMatcher, value: String) {
        waitFor(matcher)
        node(matcher).performTextInput(value)
        compose.waitForIdle()
    }

    /** Scrolls the node into view: inside a scrolling column, or through the lazy list that holds it. */
    private fun scrollTo(matcher: SemanticsMatcher) {
        if (runCatching { node(matcher).performScrollTo() }.isSuccess) return
        compose.onAllNodes(hasScrollToNodeAction()).onFirst().performScrollToNode(matcher)
    }

    /** Runs [action] until [until] is on screen (each attempt waits [SHORT]). */
    private fun retry(attempts: Int, until: SemanticsMatcher, action: () -> Unit) {
        repeat(attempts) { attempt ->
            action()
            try {
                compose.waitUntil(SHORT) { exists(until) }
                compose.waitForIdle()
                return
            } catch (e: ComposeTimeoutException) {
                Log.w(E2eRunner.TAG, "attempt ${attempt + 1}: ${until.description} not on screen yet")
            }
        }
        throw AssertionError("not on screen after $attempts attempts: ${until.description}")
    }

    private fun waitFor(matcher: SemanticsMatcher, timeout: Long = SHORT) {
        try {
            compose.waitUntil(timeout) { exists(matcher) }
        } catch (e: ComposeTimeoutException) {
            throw AssertionError("not on screen after ${timeout / 1000} s: ${matcher.description}", e)
        }
        compose.waitForIdle()
    }

    private fun waitForAny(timeout: Long, vararg matchers: SemanticsMatcher) {
        try {
            compose.waitUntil(timeout) { matchers.any(::exists) }
        } catch (e: ComposeTimeoutException) {
            throw AssertionError("none on screen after ${timeout / 1000} s: ${matchers.joinToString { it.description }}", e)
        }
        compose.waitForIdle()
    }

    private fun waitGone(matcher: SemanticsMatcher, timeout: Long) {
        try {
            compose.waitUntil(timeout) { !exists(matcher) }
        } catch (e: ComposeTimeoutException) {
            throw AssertionError("still on screen after ${timeout / 1000} s: ${matcher.description}", e)
        }
        compose.waitForIdle()
    }

    /** The clipboard as the app sees it (read on the main thread while the app has focus). */
    private fun clipboardText(): String? {
        compose.waitForIdle()
        var text: String? = null
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val clip = context.getSystemService(ClipboardManager::class.java)?.primaryClip
            text = clip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(context)?.toString()
        }
        return text
    }

    /** [date] as the age gate's field takes it: the digits in the device locale's short-date order. */
    private fun birthdayDigits(date: LocalDate): String {
        val pattern = DateTimeFormatterBuilder.getLocalizedDateTimePattern(FormatStyle.SHORT, null, IsoChronology.INSTANCE, Locale.getDefault())
        val order = pattern.filter { it == 'y' || it == 'M' || it == 'd' }.toList().distinct().takeIf { it.size == 3 } ?: listOf('M', 'd', 'y')
        return order.joinToString("") { field ->
            when (field) {
                'y' -> "%04d".format(date.year)
                'M' -> "%02d".format(date.monthValue)
                else -> "%02d".format(date.dayOfMonth)
            }
        }
    }

    private data class Person(val phone: String, val name: String)

    private companion object {
        // Test numbers (NANP 555-01xx, fictional) and their code: the CI job's [auth.sms.test_otp] (.github/workflows/ci.yml).
        val MAYA = Person("+1 201 555 0101", "Maya Reyes")
        val THEO = Person("+1 201 555 0102", "Theo Park")
        const val TEST_OTP = "123456"
        val BIRTHDAY: LocalDate = LocalDate.of(1990, 3, 14)
        const val GROUP = "Reyes family"
        const val MESSAGE = "See you all on Sunday"
        const val MARK = "\u0000"

        const val SHORT = 10_000L
        const val LONG = 30_000L
        /** Upload (storage + `media` + `create_post`) through WorkManager, then the realtime insert. */
        const val UPLOAD = 90_000L
    }
}
