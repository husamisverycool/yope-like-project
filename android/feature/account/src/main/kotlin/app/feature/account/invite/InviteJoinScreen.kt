// Surface: invite.web — Android side of the install / App Link path: check the invite with the web
// service's preview, keep it through sign-up and onboarding, then `join_group`. Spec:
// design/surfaces/invite.web.md (Platform notes, States, Data & actions) and invite.appclip.md (the
// same states rendered natively with the invite.web state layout, NF).
// References: references/auto/partiful/web/pf-web-notfound-01.png (NF) + pf-web-notfound.computed-styles.json.
package app.feature.account.invite

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
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
import app.feature.account.shell.AccountFlow
import app.model.AppRoute
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** The invite states (invite.appclip States, invite.web state layout). */
enum class InviteJoinState { Loading, Unavailable, NotFound, Full, Error, RateLimited, Offline }

class InviteJoinViewModel(private val env: AccountEnvironment, private val token: String) : AccountViewModel() {
    private val mutable = MutableStateFlow(InviteJoinState.Loading)
    val state: StateFlow<InviteJoinState> = mutable.asStateFlow()

    init {
        env.stores.pendingInviteToken = token
        run()
    }

    fun retry() = run()

    private fun run() {
        mutable.value = InviteJoinState.Loading
        viewModelScope.launch {
            // 1. Before joining: the web service's preview (404 / 410 end here; other answers go on —
            //    join_group decides with the same rules).
            when (env.invitePreview.fetch(token)) {
                InvitePreviewResult.Unavailable -> return@launch end(InviteJoinState.Unavailable)
                InvitePreviewResult.NotFound -> return@launch end(InviteJoinState.NotFound)
                else -> Unit
            }
            // 2. Signed out → sign-up first (auth.phone), the invite kept for after onboarding.
            val auth = env.backend.authState.first { it != AuthState.Initializing }
            val userId = (auth as? AuthState.SignedIn)?.userId
            if (userId == null) {
                navigate(AppRoute.AuthPhone, clearStack = true)
                return@launch
            }
            // 3. Signed in but onboarding not finished → that step (the invite stays pending).
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
            // 4. join_group → the group (groups.list under it).
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

    private fun end(state: InviteJoinState, keep: Boolean = false) {
        if (!keep) env.stores.pendingInviteToken = null
        mutable.value = state
        haptic(Tokens.Haptics.globalError)
    }
}

@Composable
fun InviteJoinRoute(nav: NavController, token: String) {
    val env = LocalAccountEnvironment.current
    val vm = viewModel(key = "invite:$token") { InviteJoinViewModel(env, token) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    InviteJoinScreen(state, onRetry = vm::retry)
}

/**
 * The invite.web state layout (NF), natively: page `invite.web.color.theme.default` with white text
 * (`invite.web.color.text.dark`), `invite.web.dimension.state.headerSpace` at the top, content
 * centred; glyph `invite.web.fontSize.state.glyph` (line height `invite.web.lineHeight.default`),
 * `invite.web.dimension.state.glyphToTitle`; title `invite.web.fontSize.state.title` /
 * `.fontWeight.state.title`, uppercase, centred (`invite.web.layout.state.title`); body
 * `invite.web.dimension.gateCard.titleToBody` below, `invite.web.fontSize.detail` at
 * `invite.web.opacity.text.body`; retry `invite.web.dimension.state.bodyToAction` below: large filled
 * button (`invite.web.dimension.button.large.height` / `.paddingH`, `invite.web.radius.button.large`,
 * `invite.web.color.button.filled.fill.dark` / `.label.dark`, `invite.web.fontSize.body`,
 * `invite.web.fontWeight.button`). Loading: the platform progress indicator (invite.appclip).
 */
@Composable
fun InviteJoinScreen(state: InviteJoinState, onRetry: () -> Unit) {
    val text = Tokens.Colors.inviteWebColorTextDark
    Box(Modifier.fillMaxSize().background(Tokens.Colors.inviteWebColorThemeDefault).windowInsetsPadding(WindowInsets.safeDrawing)) {
        if (state == InviteJoinState.Loading) {
            CircularProgressIndicator(color = text, modifier = Modifier.align(Alignment.Center))
            return@Box
        }
        val glyph = if (state == InviteJoinState.Full) stringResource(R.string.invite_appclip_full_glyph) else stringResource(R.string.invite_web_state_glyph)
        val glyphLabel = if (state == InviteJoinState.Full) stringResource(R.string.invite_appclip_full_glyphlabel) else stringResource(R.string.invite_web_state_glyphlabel)
        val (title, body) = when (state) {
            InviteJoinState.Unavailable -> stringResource(R.string.invite_web_unavailable_title) to stringResource(R.string.invite_web_unavailable_body)
            InviteJoinState.NotFound -> stringResource(R.string.invite_web_notfound_title) to null
            InviteJoinState.Full -> stringResource(R.string.invite_appclip_full_title) to stringResource(R.string.invite_appclip_full_body)
            InviteJoinState.RateLimited -> stringResource(R.string.invite_web_error_title) to stringResource(R.string.invite_web_ratelimited_body)
            InviteJoinState.Offline -> stringResource(R.string.invite_web_error_title) to stringResource(R.string.invite_appclip_offline_body)
            else -> stringResource(R.string.invite_web_error_title) to stringResource(R.string.invite_web_error_body)
        }
        val retry = state == InviteJoinState.Error || state == InviteJoinState.Offline
        Column(Modifier.fillMaxSize().padding(horizontal = Tokens.Sizes.inviteWebDimensionMargin)) {
            Spacer(Modifier.height(Tokens.Sizes.inviteWebDimensionStateHeaderSpace))
            Column(Modifier.weight(1f).fillMaxWidth(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    glyph,
                    style = TextStyle(fontSize = Tokens.FontSizes.inviteWebFontSizeStateGlyph, lineHeight = Tokens.FontSizes.inviteWebFontSizeStateGlyph * Tokens.LineHeights.inviteWebLineHeightDefault.value),
                    modifier = Modifier.semantics { contentDescription = glyphLabel; role = Role.Image },
                )
                Spacer(Modifier.height(Tokens.Sizes.inviteWebDimensionStateGlyphToTitle))
                Text(
                    title.uppercase(),
                    style = dsTextStyle(Tokens.FontSizes.inviteWebFontSizeStateTitle, Tokens.FontWeights.inviteWebFontWeightStateTitle, Tokens.Fonts.inviteWebFont),
                    color = text,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.semantics { heading() },
                )
                if (body != null) {
                    Spacer(Modifier.height(Tokens.Sizes.inviteWebDimensionGateCardTitleToBody))
                    Text(body, style = TextStyle(fontSize = Tokens.FontSizes.inviteWebFontSizeDetail), color = text, textAlign = TextAlign.Center, modifier = Modifier.alpha(Tokens.Opacities.inviteWebOpacityTextBody))
                }
                if (retry) {
                    Spacer(Modifier.height(Tokens.Sizes.inviteWebDimensionStateBodyToAction))
                    val shape = RoundedCornerShape(Tokens.Radii.inviteWebRadiusButtonLarge)
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .heightIn(min = Tokens.Sizes.inviteWebDimensionButtonLargeHeight)
                            .clip(shape)
                            .background(Tokens.Colors.inviteWebColorButtonFilledFillDark, shape)
                            .clickable(role = Role.Button, onClick = onRetry)
                            .padding(horizontal = Tokens.Sizes.inviteWebDimensionButtonLargePaddingH),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            stringResource(R.string.invite_web_error_retry),
                            style = dsTextStyle(Tokens.FontSizes.inviteWebFontSizeBody, Tokens.FontWeights.inviteWebFontWeightButton),
                            color = Tokens.Colors.inviteWebColorButtonFilledLabelDark,
                        )
                    }
                }
            }
        }
    }
}
