package app.main.e2e

import android.Manifest
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.util.Log
import androidx.annotation.StringRes
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.ComposeTimeoutException
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasScrollToNodeAction
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isEnabled
import androidx.compose.ui.test.isOn
import androidx.compose.ui.test.isSelected
import androidx.compose.ui.test.isToggleable
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToKey
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
import androidx.compose.ui.test.performTouchInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import app.designsystem.R
import app.feature.account.AccountEnvironments
import app.feature.account.groups.GROUP_SCREEN_LIST_TAG
import app.feature.capture.camera.OvernightFormats
import app.main.MainActivity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
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
 *    a chat message; turns the weekly question on in the group's settings and answers it with a photo from the camera;
 *    makes a plan; takes a 9 AM photo and sees the group's developing tile; sees the photo on her wall; opens settings and
 *    signs out.
 * 2. Theo opens Maya's invite link, signs up from the invite card, joins the group at the end of onboarding and sees
 *    Maya's photo in the group and in the viewer; reacts to it with a selfie (the viewer's front-camera layer); answers
 *    Maya's plan Going and sees his name under Going; sees the weekly question with Maya's answer and the developing
 *    tile; at the reveal (what the worker's scheduler does at 9 AM, run by the test: `due_developed_posts` at the photo's
 *    reveal time) the tile goes and Maya's 9 AM photo is in the group; signs out.
 * 3. Maya signs in again, sees Theo's selfie on her photo, cancels her plan and restores it.
 * Each step leaves a screenshot and the semantics tree (see [Evidence]) for the CI artifact.
 *
 * The stack needs: the test OTPs below (`[auth.sms.test_otp]`, added by the CI job; never in backend/supabase/config.toml,
 * which `supabase config push` sends to the hosted project), `min_age_years` set (the age gate fails closed without it),
 * `weekly_question_keys` set to question.weekly.q01 and .q02 (no question is asked without a catalogue), and the worker
 * running against it (renditions, the reveal's push and widget jobs). Run locally: `supabase start` (with those settings),
 * the worker, an emulator, then `./gradlew :app:connectedDebugAndroidTest
 * -Pandroid.testInstrumentationRunnerArguments.supabaseUrl=http://10.0.2.2:54321
 * -Pandroid.testInstrumentationRunnerArguments.supabaseAnonKey=<anon key>
 * -Pandroid.testInstrumentationRunnerArguments.serviceRoleKey=<service role key>` on a fresh stack (the accounts are
 * created). Text is matched through the app's own string resources, so copy edits do not break the journey.
 */
@RunWith(AndroidJUnit4::class)
class JourneyTest {
    // The v2 rule queues effects on a StandardTestDispatcher run on the main thread, as the app's own effects run there. The
    // v1 rule's unconfined dispatcher resumed RootGate's auth-state collector on the background thread that emitted the
    // sign-out, and NavController (main thread only) threw.
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
        var link = clipboardLink()
        if (link == null) {
            problem("invite-copy", "Copy Link left no invite link on the clipboard (${clipboardText()})")
            link = inviteLinkFromBackend()
        }
        assertTrue("Maya's group has a live invite link", link != null)
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
        // The open group shows the new post through its realtime subscription; reopening it reads the feed again.
        if (!appears(mayaPhoto, UPLOAD)) {
            problem("realtime-post", "the new post did not appear in the open group (realtime insert)")
            tap(desc(R.string.groups_screen_back_accessibilitylabel))
            tap(hasText(GROUP), LONG)
            waitFor(mayaPhoto, LONG)
        }
        evidence.step("maya-group-with-post")

        // Viewer + a reaction from the photo's menu.
        soft("viewer-reaction", recover = { backTo(mayaPhoto) }) {
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
        }

        // Chat: a message.
        soft("chat", recover = { backTo(desc(R.string.groups_screen_back_accessibilitylabel)) }) {
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
            waitFor(mayaPhoto)
        }

        // The weekly question: on in the group's settings (Maya created the group, so she is its admin), then answered.
        soft("weekly-question-switch", recover = { backTo(mayaPhoto) }) { mayaTurnsOnTheWeeklyQuestion(mayaPhoto) }
        soft("weekly-question-answer", recover = { backTo(mayaPhoto) }) { mayaAnswersTheQuestion() }

        // A plan.
        soft("plan-create", recover = { backTo(mayaPhoto) }) { mayaMakesAPlan(mayaPhoto) }

        // A 9 AM photo: developing until the reveal.
        soft("overnight-capture", recover = { backTo(mayaPhoto) }) { mayaTakesA9AmPhoto(mayaPhoto) }

        // Home, then the wall (Profile tab).
        tap(desc(R.string.groups_screen_back_accessibilitylabel))
        waitFor(hasText(GROUP), LONG)
        evidence.step("maya-groups")
        tap(desc(R.string.groups_list_tab_me_accessibilitylabel))
        waitFor(hasTestTag("walls.mine"), LONG)
        soft("wall") {
            waitFor(descContaining(before(R.string.photo_viewer_a11y_photomine, 1)), LONG)
        }
        evidence.step("maya-wall")

        // Settings → sign out.
        tap(desc(R.string.walls_mine_a11y_settings))
        signOut("maya")

        // ---- Theo, from Maya's invite link ----
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(link)).setClassName(context, MainActivity::class.java.name).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        try {
            theoJoinsByInvite(mayaPhoto)
            soft("selfie-reaction", recover = { backTo(mayaPhoto) }) { theoReactsWithASelfie(mayaPhoto) }
            soft("plan-answer", recover = { backTo(mayaPhoto) }) { theoAnswersThePlan(mayaPhoto) }
            soft("weekly-question-member") { theoSeesTheQuestion() }
            soft("overnight-reveal") { theoSeesTheReveal() }

            // Theo signs out; Maya signs in again and sees what Theo did.
            backTo(mayaPhoto)
            tap(desc(R.string.groups_screen_back_accessibilitylabel))
            waitFor(hasText(GROUP), LONG)
            tap(desc(R.string.groups_list_tab_me_accessibilitylabel))
            waitFor(hasTestTag("walls.mine"), LONG)
            tap(desc(R.string.walls_mine_a11y_settings))
            signOut("theo")
            mayaSignsInAgain(mayaPhoto)
            soft("selfie-seen-by-author", recover = { backTo(mayaPhoto) }) { mayaSeesTheosSelfie(mayaPhoto) }
            soft("plan-cancel-restore", recover = { backTo(mayaPhoto) }) { mayaCancelsAndRestoresThePlan(mayaPhoto) }
        } finally {
            restoreLaunchIntent()
        }

        assertTrue("the journey finished with problems:\n" + problems.joinToString("\n"), problems.isEmpty())
    }

    private fun theoJoinsByInvite(mayaPhoto: SemanticsMatcher) {
        waitFor(text(R.string.invite_web_cta), LONG)
        evidence.step("theo-invite-card")
        tap(text(R.string.invite_web_cta))
        signUp(THEO, "theo")
        // The pending invite joins at the end of onboarding and opens the group.
        waitFor(mayaPhoto, LONG)
        evidence.step("theo-group")
        tap(mayaPhoto)
        waitFor(mayasPhotoInTheViewer(), LONG)
        evidence.step("theo-viewer")
    }

    // ---- The weekly question (question.weekly) ----

    /** Group settings → Admin Settings → "Weekly Question" on (`set_group_weekly_question`). */
    private fun mayaTurnsOnTheWeeklyQuestion(mayaPhoto: SemanticsMatcher) {
        tap(desc(R.string.groups_screen_settings_accessibilitylabel))
        val row = text(R.string.question_weekly_settings_row)
        waitFor(row, LONG)
        scrollTo(row)
        evidence.step("maya-group-settings")
        tap(row)
        waitFor(row and isToggleable() and isOn(), LONG)
        evidence.step("maya-weekly-question-on")
        tap(desc(R.string.groups_settings_close_accessibilitylabel))
        waitFor(mayaPhoto, LONG)
    }

    /** The card (the group's pager) → "Add a photo" → the camera with the question → send-to → the card shows the answer. */
    private fun mayaAnswersTheQuestion() {
        val card = questionCard()
        showInGroup(GROUP_PAGER_KEY, card)
        evidence.step("maya-question-card")
        node(card).performSemanticsAction(SemanticsActions.OnClick)
        waitFor(desc(context.getString(R.string.question_weekly_camera_a11y, context.getString(R.string.question_weekly_q01))), LONG)
        evidence.step("maya-question-camera")
        retry(attempts = 3, until = hasTestTag("camera.sendto")) { tap(hasTestTag("camera.shutter")) }
        evidence.step("maya-question-sendto")
        tap(hasTestTag("sendto.send"))
        waitGone(hasTestTag("camera.sendto"), UPLOAD)
        // answer_question links the post after create_post; the card then offers the answers ("See answers").
        showInGroup(GROUP_PAGER_KEY, card and hasCustomAction(context.getString(R.string.question_weekly_card_a11y_answers)), UPLOAD)
        evidence.step("maya-question-answered")
    }

    private fun theoSeesTheQuestion() {
        showInGroup(GROUP_PAGER_KEY, questionCard() and hasCustomAction(context.getString(R.string.question_weekly_card_a11y_answers)), LONG)
        evidence.step("theo-question-card")
    }

    /** The card of this week's question: the first key of the CI stack's catalogue (`weekly_question_keys`). */
    private fun questionCard(): SemanticsMatcher =
        desc(context.getString(R.string.question_weekly_card_a11y, context.getString(R.string.question_weekly_q01)))

    // ---- Plans (plans.create, plans.page) ----

    /** The group's plan row → the create sheet: name, today, Create Plan → the plan page with Maya under Going. */
    private fun mayaMakesAPlan(mayaPhoto: SemanticsMatcher) {
        showInGroup(GROUP_PLANS_KEY, text(R.string.plans_create_entry))
        tap(text(R.string.plans_create_entry))
        val name = field(R.string.plans_create_name_accessibilitylabel)
        waitFor(name, LONG)
        type(name, PLAN)
        tap(text(R.string.plans_create_date))
        // The date picker opens on today (the group's day); OK keeps it. No time chosen = all day.
        tap(hasText(context.getString(android.R.string.ok)))
        waitGone(hasText(context.getString(android.R.string.ok)), SHORT)
        evidence.step("maya-plan-create")
        tap(text(R.string.plans_create_cta))
        waitFor(goingList(MAYA_FIRST), LONG)
        evidence.step("maya-plan")
        tap(desc(R.string.plans_page_back_accessibilitylabel))
        waitFor(mayaPhoto, LONG)
        waitFor(hasText(PLAN), LONG)
        evidence.step("maya-group-plan-row")
    }

    /** The plan row → the plan page → Going: Theo's answer is selected and his name joins Maya's under Going. */
    private fun theoAnswersThePlan(mayaPhoto: SemanticsMatcher) {
        showInGroup(GROUP_PLANS_KEY, hasText(PLAN))
        tap(hasText(PLAN))
        val going = text(R.string.plans_page_answer_going) and hasAnyAncestor(desc(R.string.plans_page_answer_grouplabel))
        waitFor(going, LONG)
        evidence.step("theo-plan")
        tap(going)
        waitFor(going and isSelected(), LONG)
        waitFor(goingList(THEO_FIRST), LONG)
        evidence.step("theo-plan-going")
        tap(desc(R.string.plans_page_back_accessibilitylabel))
        waitFor(mayaPhoto, LONG)
    }

    /** The maker cancels the plan (the page says Canceled, no answers), then restores it (the answers come back). */
    private fun mayaCancelsAndRestoresThePlan(mayaPhoto: SemanticsMatcher) {
        showInGroup(GROUP_PLANS_KEY, hasText(PLAN))
        tap(hasText(PLAN))
        waitFor(goingList(THEO_FIRST), LONG)
        evidence.step("maya-plan-with-theo")
        tap(desc(R.string.plans_page_more_accessibilitylabel))
        tap(text(R.string.plans_page_menu_cancel))
        tap(text(R.string.plans_page_cancel_confirm))
        waitFor(text(R.string.plans_page_canceled), LONG)
        evidence.step("maya-plan-canceled")
        tap(desc(R.string.plans_page_more_accessibilitylabel))
        tap(text(R.string.plans_page_menu_restore))
        waitGone(text(R.string.plans_page_canceled), LONG)
        waitFor(text(R.string.plans_page_answer_going) and hasAnyAncestor(desc(R.string.plans_page_answer_grouplabel)), LONG)
        waitFor(goingList(THEO_FIRST), LONG)
        evidence.step("maya-plan-restored")
        tap(desc(R.string.plans_page_back_accessibilitylabel))
        waitFor(mayaPhoto, LONG)
    }

    /** The plan page's Going block (label and first names, one TalkBack element) naming [firstName]. */
    private fun goingList(firstName: String): SemanticsMatcher =
        text(R.string.plans_page_going) and hasText(firstName, substring = true) and hasAnyAncestor(desc(R.string.plans_page_answer_grouplabel)).not()

    // ---- Selfie reactions (viewer.selfiereaction) ----

    /** In the viewer of Maya's photo: the photo's menu → "React with a selfie" → the front-camera layer → Take selfie. */
    private fun theoReactsWithASelfie(mayaPhoto: SemanticsMatcher) {
        if (!exists(hasTestTag("photo.viewer"))) {
            tap(mayaPhoto)
            waitFor(mayasPhotoInTheViewer(), LONG)
        }
        node(hasTestTag("viewer.photo")).performTouchInput { longClick() }
        tap(text(R.string.viewer_selfiereaction_menu_react))
        waitFor(hasTestTag("selfie.layer"), LONG)
        val take = desc(R.string.viewer_selfiereaction_a11y_capture) and isEnabled()
        waitFor(take, LONG)
        evidence.step("theo-selfie-layer")
        tap(take)
        waitFor(selfieStack(THEO_FIRST), UPLOAD)
        evidence.step("theo-selfie-sent")
        tap(desc(R.string.photo_viewer_a11y_close))
        waitFor(mayaPhoto, LONG)
    }

    /** The photo's author opens it: Theo's face is in the stack on the photo (read from the server after a fresh sign-in). */
    private fun mayaSeesTheosSelfie(mayaPhoto: SemanticsMatcher) {
        tap(mayaPhoto)
        waitFor(descContaining(before(R.string.photo_viewer_a11y_photomine, 1)), LONG)
        waitFor(selfieStack(THEO_FIRST), LONG)
        evidence.step("maya-sees-theos-selfie")
        tap(desc(R.string.photo_viewer_a11y_close))
        waitFor(mayaPhoto, LONG)
    }

    /** The face stack on a photo, labelled with the first names it shows (never a count). */
    private fun selfieStack(vararg firstNames: String): SemanticsMatcher =
        hasTestTag("viewer.selfies") and desc(context.getString(R.string.viewer_selfiereaction_a11y_stack, firstNames.joinToString()))

    private fun mayasPhotoInTheViewer(): SemanticsMatcher =
        descContaining(context.getString(R.string.photo_viewer_a11y_photo, MAYA_FIRST, MARK).substringBefore(MARK))

    // ---- 9 AM photos (camera.overnight) ----

    /** The camera's 9 AM segment → the destination sheet (this group) → Done → the shutter → back: the developing tile. */
    private fun mayaTakesA9AmPhoto(mayaPhoto: SemanticsMatcher) {
        showInGroup(GROUP_STRIP_KEY, desc(R.string.groups_screen_week_add_accessibilitylabel))
        tap(desc(R.string.groups_screen_week_add_accessibilitylabel))
        waitFor(hasTestTag("camera.shutter"), LONG)
        tap(hasText(OvernightFormats.time(context)) and hasAnyAncestor(hasTestTag("camera.mode")))
        // The first switch to 9 AM opens the destination sheet with the camera's group chosen; Done once the groups loaded
        // (Done before that switches back to Now).
        waitFor(hasTestTagPrefix("camera.destination.row."), LONG)
        evidence.step("maya-9am-destination")
        tap(hasTestTag("camera.destination.done"))
        waitGone(hasTestTag("camera.destinationSheet"), SHORT)
        waitFor(hasTestTag("camera.destination"))
        evidence.step("maya-camera-9am")
        tap(hasTestTag("camera.shutter"))
        // No send-to in 9 AM mode: the camera stays, the photo goes through the upload queue to create_overnight_post.
        backTo(mayaPhoto)
        showInGroup(GROUP_STRIP_KEY, developingTile(), UPLOAD)
        evidence.step("maya-developing")
    }

    /**
     * Theo sees the developing tile; the test then does what the worker's scheduler does at 9 AM in the group's zone
     * (`due_developed_posts` at the photo's reveal time); the tile goes and Maya's 9 AM photo joins the week strip.
     */
    private fun theoSeesTheReveal() {
        showInGroup(GROUP_STRIP_KEY, developingTile(), LONG)
        evidence.step("theo-developing")
        val mayasTiles = stripTiles(descContaining(after(R.string.groups_screen_photo_accessibilitylabel, 2, MAYA_FIRST)))
        val revealAt = Server.latestDevelopsAt() ?: throw AssertionError("nothing is developing on the server")
        Server.developedPosts(revealAt)
        try {
            compose.waitUntil(UPLOAD) {
                stripTiles(developingTile()) == 0 && stripTiles(descContaining(after(R.string.groups_screen_photo_accessibilitylabel, 2, MAYA_FIRST))) > mayasTiles
            }
        } catch (e: ComposeTimeoutException) {
            throw AssertionError("after the reveal at $revealAt the week strip still shows the developing tile or no new photo by Maya", e)
        }
        compose.waitForIdle()
        evidence.step("theo-revealed")
    }

    private fun developingTile(): SemanticsMatcher = descContaining(before(R.string.camera_overnight_tile_a11y, 1))

    /** How many tiles of the week strip (the add tile's list) match [matcher]. */
    private fun stripTiles(matcher: SemanticsMatcher): Int {
        val add = compose.onAllNodes(desc(R.string.groups_screen_week_add_accessibilitylabel), useUnmergedTree = true)
            .fetchSemanticsNodes(atLeastOneRootRequired = false).firstOrNull() ?: return 0
        return add.parent?.children?.count { matcher.matches(it) } ?: 0
    }

    // ---- Sign-out and sign-in ----

    /** From settings.root: Sign Out → confirm → the landing. */
    private fun signOut(who: String) {
        waitFor(text(R.string.settings_root_title), LONG)
        evidence.step("$who-settings")
        scrollTo(text(R.string.settings_root_signout))
        tap(text(R.string.settings_root_signout))
        waitFor(text(R.string.settings_root_signout_confirm))
        evidence.step("$who-signout-confirm")
        tap(text(R.string.settings_root_signout_confirm))
        waitFor(text(R.string.auth_phone_getstarted), LONG)
        evidence.step("$who-signed-out")
    }

    /** A returning account: phone and code, then straight home (no age gate, name or onboarding), and into the group. */
    private fun mayaSignsInAgain(mayaPhoto: SemanticsMatcher) {
        tap(text(R.string.auth_phone_getstarted))
        val phone = field(R.string.auth_phone_field_accessibilitylabel)
        waitFor(phone)
        node(phone).performTextReplacement(MAYA.phone)
        tap(text(R.string.auth_phone_continue))
        val code = field(R.string.auth_code_field_accessibilitylabel)
        waitFor(code, LONG)
        type(code, TEST_OTP)
        evidence.step("maya-again-code")
        tapIfPresent(text(R.string.auth_code_continue))
        waitFor(hasText(GROUP), LONG)
        evidence.step("maya-again-groups")
        tap(hasText(GROUP))
        waitFor(mayaPhoto, LONG)
    }

    // ---- The group screen's list ----

    /**
     * Brings the group screen's item [key] (the lazy list's key: `plans`, `strip`, `pager`) into view, then [matcher]
     * inside it (the pager and the strip scroll sideways), within [timeout].
     */
    private fun showInGroup(key: String, matcher: SemanticsMatcher, timeout: Long = LONG) {
        val list = hasTestTag(GROUP_SCREEN_LIST_TAG)
        try {
            compose.waitUntil(timeout) {
                runCatching { compose.onNode(list).performScrollToKey(key) }
                exists(matcher)
            }
        } catch (e: ComposeTimeoutException) {
            throw AssertionError("not in the group screen's \"$key\" after ${timeout / 1000} s: ${matcher.description}", e)
        }
        compose.waitForIdle()
        runCatching { node(matcher).performScrollTo() }
        compose.waitForIdle()
    }

    /**
     * The invite link reaches the running MainActivity as a new intent, which it adopts (`setIntent`, so routing reads the
     * link). ActivityScenario recognises its activity by the intent it launched it with, so from then on it ignores that
     * activity's lifecycle and the rule's teardown times out ("never becomes DESTROYED", run 71). The launch intent goes
     * back before the rule closes the scenario.
     */
    private fun restoreLaunchIntent() {
        compose.activityRule.scenario.onActivity { activity ->
            activity.intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER).setClassName(activity, MainActivity::class.java.name)
        }
    }

    // ---- Problems that do not stop the journey: recorded (with evidence), reported at the end ----

    private val problems = mutableListOf<String>()

    private fun problem(name: String, message: String) {
        Log.e(E2eRunner.TAG, "problem $name: $message")
        problems += "$name: $message"
        evidence.step("problem-$name")
    }

    /** Runs [block]; a failure is recorded as a problem, [recover] brings the app back to a known screen. */
    private fun soft(name: String, recover: () -> Unit = {}, block: () -> Unit) {
        try {
            block()
        } catch (e: AssertionError) {
            problem(name, e.message ?: e.toString())
            recover()
        }
    }

    /** Whether [matcher] shows within [timeout]. */
    private fun appears(matcher: SemanticsMatcher, timeout: Long): Boolean = try {
        compose.waitUntil(timeout) { exists(matcher) }
        compose.waitForIdle()
        true
    } catch (e: ComposeTimeoutException) {
        false
    }

    /** System Back until [matcher] is on screen. */
    private fun backTo(matcher: SemanticsMatcher) {
        repeat(BACK_ATTEMPTS) {
            if (exists(matcher)) return
            compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
            compose.waitForIdle()
        }
        waitFor(matcher)
    }

    /** The live invite of Maya's group through the app's data layer (only when the clipboard path failed). */
    private fun inviteLinkFromBackend(): String? = runBlocking {
        val env = AccountEnvironments.get(context)
        val group = env.backend.observeMyGroups().first { it.value != null || !it.refreshing }.value?.firstOrNull { it.name == GROUP }
            ?: return@runBlocking null
        env.backend.activeInvites(group.id).firstOrNull()?.let { env.inviteLinks.url(it.token) }
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

    private fun hasCustomAction(label: String): SemanticsMatcher = SemanticsMatcher("has the custom action \"$label\"") { node ->
        node.config.getOrNull(SemanticsActions.CustomActions)?.any { it.label == label } == true
    }

    private fun hasTestTagPrefix(prefix: String): SemanticsMatcher = SemanticsMatcher("test tag starting with \"$prefix\"") { node ->
        node.config.getOrNull(SemanticsProperties.TestTag)?.startsWith(prefix) == true
    }

    private fun exists(matcher: SemanticsMatcher): Boolean =
        compose.onAllNodes(matcher).fetchSemanticsNodes(atLeastOneRootRequired = false).isNotEmpty()

    // ---- Actions and waits ----

    private fun tap(matcher: SemanticsMatcher, timeout: Long = SHORT) {
        waitFor(matcher, timeout)
        // A target below the fold of a scrolling screen is scrolled into view first: a click outside the window lands
        // nowhere (run 96: the plan row pushed the new group's "Invite Family" under the screen's bottom edge).
        runCatching { node(matcher).performScrollTo() }
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

    /**
     * The invite link Copy Link put on the clipboard, retried for [CLIPBOARD] (the copy lands asynchronously) before it
     * counts as a problem.
     */
    private fun clipboardLink(): String? {
        val deadline = SystemClock.uptimeMillis() + CLIPBOARD
        while (true) {
            clipboardText()?.takeIf { it.startsWith("https://${E2eRunner.E2E_INVITE_HOST}/i/") }?.let { return it }
            if (SystemClock.uptimeMillis() > deadline) return null
            SystemClock.sleep(250)
        }
    }

    /**
     * The clipboard's text, read in the app's process. Android lets only the focused app read the clipboard, and the
     * system's "Copied" overlay (Android 13+) takes focus after a copy: in run 74 the overlay closed ≈ 7 s after Copy
     * Link; in run 78 focus did not come back to the app after the overlay closed and every read for 15 s was denied
     * ("application is not in focus"). So the read borrows the shell's READ_CLIPBOARD_IN_BACKGROUND for its own
     * duration, as the platform's compatibility test reads the clipboard in the background (CTS ClipboardManagerTest,
     * `callWithShellPermissionIdentity(… READ_CLIPBOARD_IN_BACKGROUND)`).
     */
    private fun clipboardText(): String? {
        compose.waitForIdle()
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val automation = instrumentation.uiAutomation
        val borrows = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        if (borrows) automation.adoptShellPermissionIdentity(READ_CLIPBOARD_IN_BACKGROUND)
        var text: String? = null
        try {
            instrumentation.runOnMainSync {
                val clip = context.getSystemService(ClipboardManager::class.java)?.primaryClip
                text = clip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(context)?.toString()
            }
        } finally {
            if (borrows) automation.dropShellPermissionIdentity()
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
        const val MAYA_FIRST = "Maya"
        const val THEO_FIRST = "Theo"
        const val GROUP = "Reyes family"
        const val MESSAGE = "See you all on Sunday"
        const val PLAN = "Sunday lunch at Grandma's"

        // The group screen's lazy list and its item keys (GroupScreen.kt).
        const val GROUP_PLANS_KEY = "plans"
        const val GROUP_STRIP_KEY = "strip"
        const val GROUP_PAGER_KEY = "pager"
        const val MARK = "\u0000"

        const val BACK_ATTEMPTS = 4

        const val SHORT = 10_000L
        /** How long a clipboard read is retried after a copy. */
        const val CLIPBOARD = 15_000L
        /** System permission (not in the public SDK's Manifest.permission) the shell holds; see [clipboardText]. */
        const val READ_CLIPBOARD_IN_BACKGROUND = "android.permission.READ_CLIPBOARD_IN_BACKGROUND"
        const val LONG = 30_000L
        /** Upload (storage + `media` + `create_post`) through WorkManager, then the realtime insert. */
        const val UPLOAD = 90_000L
    }
}
