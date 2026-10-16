// Surface: invite.web — Android side of the install / App Link path: the invite card natively (as the App Clip draws it on
// iOS), then sign-up or `join_group`. Spec: design/surfaces/invite.web.md (mobile card, States, Data & actions) and
// design/surfaces/invite.appclip.md (the card's native states). References: references/auto/retro/web/retro.app-u-nathan-iphone.png
// (WEBU: card inset 6, radius ≈ 36, 112 avatar, pill 302 × 56), references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css (CSS:
// .page_mobileProfilePageContent, .page_invitePillButton, .page_mobileInviteFooter), references/auto/retro/web/
// retro.app-web-copy-excerpts.txt (WEBX: copy).
package app.feature.account.invite

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.ApiError
import app.data.error.DataError
import app.data.repo.AuthState
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.feature.account.platform.ExternalActions
import app.feature.account.shell.AccountFlow
import app.model.AppRoute
import app.ui.components.Avatar
import app.ui.components.BlurredBackdrop
import app.ui.foundation.tapClickable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** The invite card's states (invite.web States, invite.appclip States). */
enum class InviteJoinState { Loading, Ready, Unavailable, NotFound, Full, Error, RateLimited, Offline }

@Immutable
data class InviteJoinUiState(
    val phase: InviteJoinState = InviteJoinState.Loading,
    val preview: InvitePreviewResult.Valid? = null,
    /** "Let's go" pressed: sign-up or `join_group` in progress ("Opening…"). */
    val opening: Boolean = false,
)

/**
 * The join path: the web service's preview (404 / 410 / 429 end here); "Let's go" (or [autoJoin], the pending invite at the
 * end of onboarding) → signed out: sign-up first (auth.phone; the invite stays pending) · onboarding unfinished: that step ·
 * else `join_group` → the group (groups.list under it).
 */
class InviteJoinViewModel(private val env: AccountEnvironment, private val token: String, private val autoJoin: Boolean = false) : AccountViewModel() {
    private val mutable = MutableStateFlow(InviteJoinUiState())
    val state: StateFlow<InviteJoinUiState> = mutable.asStateFlow()

    init {
        env.stores.pendingInviteToken = token
        loadPreview()
    }

    fun retry() = loadPreview()

    private fun loadPreview() {
        mutable.update { it.copy(phase = InviteJoinState.Loading, opening = false) }
        viewModelScope.launch {
            when (val preview = env.invitePreview.fetch(token)) {
                InvitePreviewResult.Unavailable -> end(InviteJoinState.Unavailable)
                InvitePreviewResult.NotFound -> end(InviteJoinState.NotFound)
                InvitePreviewResult.RateLimited -> end(InviteJoinState.RateLimited, keep = true)
                InvitePreviewResult.Offline -> end(InviteJoinState.Offline, keep = true)
                InvitePreviewResult.Error -> end(InviteJoinState.Error, keep = true)
                // No invite domain configured: nothing to preview; join_group decides with the same rules.
                InvitePreviewResult.NotConfigured, is InvitePreviewResult.Valid -> {
                    mutable.update { it.copy(phase = InviteJoinState.Ready, preview = preview as? InvitePreviewResult.Valid) }
                    if (autoJoin) go()
                }
            }
        }
    }

    /** "Let's go". */
    fun go() {
        if (mutable.value.opening) return
        mutable.update { it.copy(opening = true) }
        viewModelScope.launch {
            val auth = env.backend.authState.first { it != AuthState.Initializing }
            val userId = (auth as? AuthState.SignedIn)?.userId
            if (userId == null) {
                navigate(AppRoute.AuthPhone, clearStack = true)
                return@launch
            }
            val next = try {
                AccountFlow.nextAfterSignIn(env, userId, justVerified = false)
            } catch (t: Throwable) {
                if (t.dataError() == DataError.Network) return@launch end(InviteJoinState.Offline, keep = true)
                AppRoute.InviteJoin(token)
            }
            if (next !is AppRoute.InviteJoin) {
                navigate(next, clearStack = true)
                return@launch
            }
            try {
                val group = env.backend.joinGroup(token)
                env.stores.pendingInviteToken = null
                haptic(Tokens.Haptics.globalSuccess)
                navigate(AppRoute.GroupsList, clearStack = true)
                navigate(AppRoute.Group(group.id))
            } catch (t: Throwable) {
                val error = t.dataError()
                when ((error as? DataError.Api)?.code) {
                    ApiError.GroupFull -> end(InviteJoinState.Full)
                    ApiError.InviteExpired, ApiError.InviteRevoked -> end(InviteJoinState.Unavailable)
                    ApiError.InviteNotFound -> end(InviteJoinState.NotFound)
                    else -> end(if (error == DataError.Network) InviteJoinState.Offline else InviteJoinState.Error, keep = true)
                }
            }
        }
    }

    private fun end(phase: InviteJoinState, keep: Boolean = false) {
        if (!keep) env.stores.pendingInviteToken = null
        mutable.update { it.copy(phase = phase, opening = false) }
        haptic(Tokens.Haptics.globalError)
    }
}

@Composable
fun InviteJoinRoute(nav: NavController, token: String, join: Boolean = false) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val vm = viewModel(key = "invite:$token") { InviteJoinViewModel(env, token, join) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    InviteJoinScreen(
        state,
        onGo = vm::go,
        onRetry = vm::retry,
        onTerms = env.legal.termsUrl?.let { url -> { ExternalActions.openInAppBrowser(context, url) } },
        onPrivacy = env.legal.privacyUrl?.let { url -> { ExternalActions.openInAppBrowser(context, url) } },
    )
}

/**
 * The invite card (invite.web mobile, natively — invite.appclip Structure 2), the same in both appearances (Retro's web has
 * no dark scheme): the page #FFFFFF (`color.global.background` light value); the card `invite.web.size.cardInset` in from
 * the safe area, corners `invite.web.radius.card`, filled with the group cover blurred (C-34; none: the inviter's avatar
 * blurred; neither — and every state but a live invite — `color.global.backgroundDeep`); the inviter's avatar
 * (`invite.web.size.avatar`, placeholder `invite.web.color.avatarPlaceholder`) centred in the space above the text block;
 * the headline (`font.global.display` `fontSize.global.displayMedium` / `invite.web.lineHeight.headline`, white, max
 * `invite.web.size.textMaxWidth`); `invite.web.size.headlineToBody` below the line (`invite.web.fontSize.body` /
 * `.lineHeight.body` / `.letterSpacing.body`, `invite.web.color.body`); the same gap below, the members' C-23 stack (white
 * ring); `invite.web.size.bodyToPill` below, the pill (`invite.web.size.pillHeight`, inset `invite.web.size.pillInset`,
 * `invite.web.color.pill`, label `invite.web.fontSize.pill` / `.fontWeight.pill` white; busy "Opening…" at
 * `invite.web.opacity.pillDisabled`); `invite.web.size.pillToFooter` below, the footer "Terms & Privacy"
 * (`invite.web.fontSize.footer`, white, margin `invite.web.size.footerMargin`). Loading: the black card with the white
 * platform indicator.
 */
@Composable
fun InviteJoinScreen(
    state: InviteJoinUiState,
    onGo: () -> Unit,
    onRetry: () -> Unit,
    onTerms: (() -> Unit)? = null,
    onPrivacy: (() -> Unit)? = null,
) {
    val white = Tokens.Colors.globalTextOnMedia
    val shape = RoundedCornerShape(Tokens.Radii.inviteWebRadiusCard)
    val preview = state.preview
    val live = state.phase == InviteJoinState.Ready
    Box(Modifier.fillMaxSize().background(Tokens.ColorsLight.globalBackground).windowInsetsPadding(WindowInsets.safeDrawing).padding(Tokens.Sizes.inviteWebSizeCardInset)) {
        Box(Modifier.fillMaxSize().clip(shape).background(Tokens.Colors.globalBackgroundDeep, shape)) {
            // The group's blurred cover stays behind the card while the preview is known (live, or full at join time).
            val backdrop = if (live || state.phase == InviteJoinState.Full) preview?.coverUrl ?: preview?.inviterAvatarUrl else null
            if (backdrop != null) {
                // `invite.web.layout.backdrop`: the blur scales with the card (σ = blurSigmaToWidth × width), as on the web.
                BoxWithConstraints(Modifier.fillMaxSize()) {
                    BlurredBackdrop(backdrop, sigma = maxWidth * Tokens.Layouts.InviteWebLayoutBackdrop.blurSigmaToWidth)
                }
            }
            if (state.phase == InviteJoinState.Loading) {
                val loading = stringResource(R.string.global_a11y_loading)
                CircularProgressIndicator(color = white, modifier = Modifier.align(Alignment.Center).semantics { contentDescription = loading })
                return@Box
            }
            val (title, body, action) = cardCopy(state.phase, preview)
            Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    if (live && preview != null) {
                        Avatar(
                            preview.inviterAvatarUrl,
                            Tokens.Sizes.inviteWebSizeAvatar,
                            Modifier.background(Tokens.Colors.inviteWebColorAvatarPlaceholder, CircleShape),
                            contentDescription = preview.inviterFirstName?.let { stringResource(R.string.invite_web_avatar_alt, it) },
                        )
                    }
                }
                Text(
                    title,
                    style = dsTextStyle(Tokens.FontSizes.globalDisplayMedium, Tokens.FontWeights.fontWeightGlobalDisplayMedium, Tokens.Fonts.globalDisplay, Tokens.LineHeights.inviteWebLineHeightHeadline),
                    color = white,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.widthIn(max = Tokens.Sizes.inviteWebSizeTextMaxWidth).semantics { heading() },
                )
                if (body != null) {
                    Text(
                        body,
                        style = dsTextStyle(Tokens.FontSizes.inviteWebFontSizeBody, Tokens.FontWeights.fontWeightGlobalBody, Tokens.Fonts.globalFamily, Tokens.LineHeights.inviteWebLineHeightBody, Tokens.Tracking.inviteWebLetterSpacingBody),
                        color = Tokens.Colors.inviteWebColorBody,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.widthIn(max = Tokens.Sizes.inviteWebSizeTextMaxWidth).padding(top = Tokens.Sizes.inviteWebSizeHeadlineToBody),
                    )
                }
                if (live && preview != null && preview.memberAvatars.isNotEmpty()) {
                    MemberStack(preview, Modifier.padding(top = Tokens.Sizes.inviteWebSizeHeadlineToBody))
                }
                Spacer(Modifier.height(Tokens.Sizes.inviteWebSizeBodyToPill))
                if (action != null) {
                    val opening = state.opening
                    Pill(
                        text = if (opening) stringResource(R.string.invite_web_opening) else action,
                        busy = opening,
                        onClick = if (state.phase == InviteJoinState.Ready) onGo else onRetry,
                    )
                }
                Footer(onTerms, onPrivacy, Modifier.padding(top = if (action != null) Tokens.Sizes.inviteWebSizePillToFooter else 0.dp))
            }
        }
    }
}

/** Headline, line and pill label of each state (invite.web States; invite.appclip full / offline). */
@Composable
private fun cardCopy(phase: InviteJoinState, preview: InvitePreviewResult.Valid?): Triple<String, String?, String?> = when (phase) {
    InviteJoinState.Ready -> Triple(
        preview?.inviterFirstName?.let { stringResource(R.string.invite_web_invitedby, it) } ?: stringResource(R.string.invite_web_invitedfallback),
        preview?.groupName?.let { stringResource(R.string.invite_web_body, it) },
        stringResource(R.string.invite_web_cta),
    )
    InviteJoinState.Unavailable -> Triple(stringResource(R.string.invite_web_unavailable_title), stringResource(R.string.invite_web_unavailable_body), null)
    InviteJoinState.NotFound -> Triple(stringResource(R.string.invite_web_notfound_title), null, null)
    InviteJoinState.Full -> Triple(stringResource(R.string.invite_appclip_full_title), stringResource(R.string.invite_appclip_full_body), null)
    InviteJoinState.RateLimited -> Triple(stringResource(R.string.invite_web_error_title), stringResource(R.string.invite_web_ratelimited_body), null)
    InviteJoinState.Offline -> Triple(stringResource(R.string.invite_web_error_title), stringResource(R.string.invite_appclip_offline_body), stringResource(R.string.invite_web_error_retry))
    InviteJoinState.Error, InviteJoinState.Loading -> Triple(stringResource(R.string.invite_web_error_title), stringResource(R.string.invite_web_error_body), stringResource(R.string.invite_web_error_retry))
}

/** The members (C-23 stack, `size.global.avatarSmall`, overlap `size.global.avatarStackOverlap`, white ring), as many as fit `invite.web.size.textMaxWidth`; one element "Members of {group_name}". */
@Composable
private fun MemberStack(preview: InvitePreviewResult.Valid, modifier: Modifier) {
    val avatar = Tokens.Sizes.globalAvatarSmall
    val pitch = avatar - Tokens.Sizes.globalAvatarStackOverlap
    val fit = 1 + ((Tokens.Sizes.inviteWebSizeTextMaxWidth - avatar) / pitch).toInt()
    val label = stringResource(R.string.invite_web_members_title, preview.groupName)
    Row(modifier.semantics(mergeDescendants = true) { contentDescription = label }, horizontalArrangement = Arrangement.spacedBy(-Tokens.Sizes.globalAvatarStackOverlap)) {
        preview.memberAvatars.take(fit).forEach { url ->
            Avatar(url, avatar, Modifier.border(Tokens.Sizes.globalAvatarStackOverlap / 2, Tokens.Colors.globalTextOnMedia, CircleShape))
        }
    }
}

/** The translucent pill (Retro `.page_invitePillButton`): busy = the "Opening…" label at `invite.web.opacity.pillDisabled`, announced as busy. */
@Composable
private fun Pill(text: String, busy: Boolean, onClick: () -> Unit) {
    val opening = stringResource(R.string.invite_web_opening)
    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.inviteWebSizePillInset)
            .heightIn(min = Tokens.Sizes.inviteWebSizePillHeight)
            .clip(CircleShape)
            .background(Tokens.Colors.inviteWebColorPill, CircleShape)
            .tapClickable(enabled = !busy, onClick = onClick)
            .alpha(if (busy) Tokens.Opacities.inviteWebOpacityPillDisabled else FULL)
            .semantics { if (busy) stateDescription = opening },
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = dsTextStyle(Tokens.FontSizes.inviteWebFontSizePill, Tokens.FontWeights.inviteWebFontWeightPill, Tokens.Fonts.globalFamily), color = Tokens.Colors.globalTextOnMedia)
    }
}

/** "Terms & Privacy" (`invite.web.footer.terms` / `.privacy`), each a link padded to the minimum touch target; omitted while the legal URLs are BLOCKED. */
@Composable
private fun Footer(onTerms: (() -> Unit)?, onPrivacy: (() -> Unit)?, modifier: Modifier) {
    if (onTerms == null && onPrivacy == null) {
        Spacer(modifier.height(Tokens.Sizes.inviteWebSizeFooterMargin))
        return
    }
    val style = dsTextStyle(Tokens.FontSizes.inviteWebFontSizeFooter, Tokens.FontWeights.fontWeightGlobalBody, Tokens.Fonts.globalFamily)
    val terms = stringResource(R.string.invite_web_footer_terms)
    val privacy = stringResource(R.string.invite_web_footer_privacy)
    // One line, as Retro's footer ("Terms & Privacy"): each label is its own link span; the line keeps the minimum touch height.
    // Plain white like the rest of the line (Retro's footer links are not styled as links).
    val linkStyle = TextLinkStyles(SpanStyle(color = Tokens.Colors.globalTextOnMedia))
    val text = buildAnnotatedString {
        onTerms?.let { action -> withLink(LinkAnnotation.Clickable(terms, linkStyle) { action() }) { append(terms) } }
        if (onTerms != null && onPrivacy != null) append(AMPERSAND)
        onPrivacy?.let { action -> withLink(LinkAnnotation.Clickable(privacy, linkStyle) { action() }) { append(privacy) } }
    }
    Box(modifier.padding(bottom = Tokens.Sizes.inviteWebSizeFooterMargin).heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid), contentAlignment = Alignment.Center) {
        Text(text, style = style, color = Tokens.Colors.globalTextOnMedia, maxLines = 1)
    }
}

/** Retro's footer joins the two links with an ampersand ("Terms & Privacy", WEBX). */
private const val AMPERSAND = " & " // provenance-ok: the joiner between the two footer link labels (WEBX "Terms & Privacy")
private const val FULL = 1f
