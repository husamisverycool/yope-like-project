// Surface: onboarding.widget — guided add-the-widget step. Spec: design/surfaces/onboarding.widget.md.
// References: references/auto/retro/apk/widget_preview_friends.webp (W34: 158-dp full-bleed photo art, name bottom-right),
// references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt (APK-X: Glance corner 22 dp),
// references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png (VID-SET: labelled widget thumbnails in Settings),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: upsell, "Add Widget", toasts); Locket's add-widget
// steps (mechanics). Composition of C-33 (page title), widget preview art, C-11 numbered circles, C-05, C-08 in Locket's order.
package app.feature.account.onboarding

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.model.Media
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountEvent
import app.feature.account.common.AccountViewModel
import app.feature.account.common.OnboardingForm
import app.feature.account.common.navigateAccount
import app.feature.account.shell.AccountFlow
import app.ui.components.HeaderAction
import app.ui.components.PrimaryButton
import app.ui.components.TextLink
import app.ui.foundation.DsImage
import app.ui.foundation.FadeVisibility
import app.ui.foundation.PageRoles
import app.ui.foundation.PhotoScrimOverlay
import app.ui.haptics.rememberHaptics
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
import app.widget.GroupPhotoWidgetReceiver
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/** What the preview tile shows: the newest photo across the person's groups and its sender's first name. */
@Immutable
data class WidgetPreview(val photo: Any?, val firstName: String?)

/** Reads the newest cached post across the person's groups for the preview (spec Data: no API of its own). */
class WidgetPreviewViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow<WidgetPreview?>(null)
    val preview: StateFlow<WidgetPreview?> = mutable.asStateFlow()

    init {
        viewModelScope.launch {
            runCatching {
                val groups = env.backend.observeMyGroups().first { it.value != null || !it.refreshing }.value.orEmpty()
                val newest = groups.mapNotNull { g -> runCatching { env.backend.newestPost(g.id) }.getOrNull() }.maxByOrNull { it.createdAt } ?: return@runCatching
                val media = env.backend.media(listOf(newest.mediaId)).firstOrNull() ?: return@runCatching
                val path = media.imagePath(Media.Rendition.Display)
                val url = env.backend.signedUrls(listOf(path))[path]
                val name = env.backend.profiles(listOf(newest.authorId)).firstOrNull()?.firstName
                mutable.value = WidgetPreview(url, name)
            }
        }
    }
}

/**
 * [fromSettings]: opened from settings.root's Widgets row (back chevron; "Add Widget" / "Maybe later" return there);
 * otherwise the last onboarding step (out: the pending invite's join or groups.list).
 */
@Composable
fun WidgetRoute(nav: NavController, fromSettings: Boolean = false) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val vm = viewModel(key = "widgetPreview") { WidgetPreviewViewModel(env) }
    val preview by vm.preview.collectAsStateWithLifecycle()
    val steps = listOfNotNull(
        context.getString(R.string.onboarding_widget_step_android_1),
        context.getString(R.string.onboarding_widget_step_android_2),
        // BLOCKED ({app_name}): omitted in release builds.
        BlockedCopy.widgetStepAndroid3(context),
    )
    val next = {
        if (fromSettings) {
            nav.popBackStack()
        } else {
            nav.navigateAccount(AccountEvent.Navigate(AccountFlow.finishOnboarding(env), clearStack = true))
        }
        Unit
    }
    WidgetScreen(
        steps = steps,
        preview = preview,
        onAdd = {
            val requested = WidgetPinning.request(context) {
                haptics.perform(Tokens.Haptics.globalSuccess)
                env.toasts.show(context.getString(R.string.onboarding_widget_added))
            }
            if (requested) {
                next()
            } else {
                haptics.perform(Tokens.Haptics.globalError)
                env.toasts.show(context.getString(R.string.onboarding_widget_pinfailed))
            }
        },
        onSkip = next,
        onBack = if (fromSettings) {
            { nav.popBackStack(); Unit }
        } else {
            null
        },
    )
}

/**
 * Pins the group-photo widget through the launcher (`AppWidgetManager.requestPinAppWidget`, as Retro's Android app does —
 * `AppWidgetPinReceiver`). Returns false when the launcher cannot pin (the steps are the path then); [onAdded] runs when
 * the launcher reports the widget added.
 */
object WidgetPinning {
    private const val ACTION_PINNED = "app.feature.account.WIDGET_PINNED" // provenance-ok: broadcast action id
    @Volatile private var listener: (() -> Unit)? = null
    @Volatile private var registered = false

    fun request(context: Context, onAdded: () -> Unit): Boolean {
        val app = context.applicationContext
        val manager = AppWidgetManager.getInstance(app) ?: return false
        if (!manager.isRequestPinAppWidgetSupported) return false
        listener = onAdded
        register(app)
        val callback = PendingIntent.getBroadcast(
            app,
            0,
            Intent(ACTION_PINNED).setPackage(app.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        return runCatching { manager.requestPinAppWidget(ComponentName(app, GroupPhotoWidgetReceiver::class.java), null, callback) }.getOrDefault(false)
    }

    private fun register(app: Context) {
        if (registered) return
        registered = true
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                listener?.invoke()
                listener = null
            }
        }
        ContextCompat.registerReceiver(app, receiver, IntentFilter(ACTION_PINNED), ContextCompat.RECEIVER_NOT_EXPORTED)
    }
}

/**
 * The onboarding page ([OnboardingForm]; scrolls when the steps do not fit): title / explanation; the preview tile
 * `onboarding.widget.size.preview` square, corners `onboarding.widget.radius.preview`, centred — the newest group photo
 * aspect-fill with the widget's bottom scrim (`layout.global.photoScrim`) and the sender's first name (text role
 * `listTitle`, `color.global.textOnMedia`) bottom-trailing (Retro's widget art; its inset is not measured — the C-24 badge
 * inset `size.global.badgeInset` from the trailing edge, baseline `size.global.tileLabelBaseline` above the bottom, as C-17
 * sets text on a photo), or `color.global.control` with `icon.global.gallery` in secondary text; under it
 * (`size.global.sectionHeaderToContent`) the widget's name `widget.home.small.gallery.name` (text role `meta`, secondary,
 * centred). `size.global.titleToContent` below: the steps — a C-11 36-pt circle (`size.global.circleButton`,
 * `color.global.control`) with the numeral (`listTitle`), the text (`body`) `size.global.rowThumbGap` after it, rows
 * `size.global.sectionHeaderToContent` apart — then "You're done!" (`listTitle`) and `widget.arrival.help.delay` (`meta`,
 * secondary). Bottom (Android): C-05 "Add Widget" and, `auth.phone.size.capsuleToLink` under it, the C-08 "Maybe later".
 */
@Composable
fun WidgetScreen(
    steps: List<String>,
    preview: WidgetPreview?,
    onAdd: () -> Unit,
    onSkip: () -> Unit,
    onBack: (() -> Unit)? = null,
) {
    OnboardingForm(
        title = stringResource(R.string.onboarding_widget_title),
        explanation = stringResource(R.string.onboarding_widget_detail),
        back = onBack?.let { HeaderAction(Tokens.Icons.globalBack, stringResource(R.string.groups_screen_back_accessibilitylabel), it) },
        bottom = {
            PrimaryButton(stringResource(R.string.onboarding_widget_add), onAdd)
            TextLink(
                stringResource(R.string.onboarding_widget_skip),
                onSkip,
                Modifier.capTopAt(Tokens.Sizes.authPhoneSizeCapsuleToLink, CapTop.height(TextRoles.listTitle)),
            )
        },
    ) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            PreviewTile(preview)
            Text(
                stringResource(R.string.widget_home_small_gallery_name),
                style = TextRoles.meta,
                color = PageRoles.secondaryText(),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = Tokens.Sizes.globalSectionHeaderToContent),
            )
        }
        Spacer(Modifier.height(Tokens.Sizes.globalTitleToContent))
        Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalSectionHeaderToContent)) {
            steps.forEachIndexed { index, step -> StepRow(index + 1, step) }
            Column {
                Text(stringResource(R.string.onboarding_widget_done), style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
                Text(stringResource(R.string.widget_arrival_help_delay), style = TextRoles.meta, color = PageRoles.secondaryText())
            }
        }
    }
}

@Composable
private fun PreviewTile(preview: WidgetPreview?) {
    val shape = RoundedCornerShape(Tokens.Radii.onboardingWidgetRadiusPreview)
    val label = stringResource(R.string.onboarding_widget_preview_accessibilitylabel)
    Box(
        Modifier
            .size(Tokens.Sizes.onboardingWidgetSizePreview)
            .clip(shape)
            .background(Tokens.Colors.globalControl, shape)
            .clearAndSetSemantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        val photo = preview?.photo
        if (photo == null) {
            Icon(Tokens.Icons.globalGallery, contentDescription = null, tint = PageRoles.secondaryText(), modifier = Modifier.size(Tokens.Sizes.globalIcon))
        }
        FadeVisibility(visible = photo != null, modifier = Modifier.fillMaxSize()) {
            Box(Modifier.fillMaxSize()) {
                DsImage(photo, null, Modifier.fillMaxSize())
                PhotoScrimOverlay()
                preview?.firstName?.let { name ->
                    Text(
                        name,
                        style = TextRoles.listTitle,
                        color = Tokens.Colors.globalTextOnMedia,
                        maxLines = 1,
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .padding(end = Tokens.Sizes.globalBadgeInset)
                            .paddingFrom(LastBaseline, after = Tokens.Sizes.globalTileLabelBaseline),
                    )
                }
            }
        }
    }
}

/** One step: one element for TalkBack ("Step {number}", then the text). */
@Composable
private fun StepRow(number: Int, text: String) {
    val label = stringResource(R.string.onboarding_widget_stepnumber_accessibilitylabel, number.toString())
    Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .size(Tokens.Sizes.globalCircleButton)
                .background(Tokens.Colors.globalControl, CircleShape)
                .clearAndSetSemantics { contentDescription = label },
            contentAlignment = Alignment.Center,
        ) {
            Text(number.toString(), style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
        }
        Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
        Text(text, style = TextRoles.body, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.weight(1f))
    }
}
