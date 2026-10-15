// Surface: groups.invite — invite by link or from contacts. Spec: design/surfaces/groups.invite.md
// (contacts per design/surfaces/onboarding.permission.contacts.md, Android card).
// References: references/auto/yope/frames/a-yrrah-7452976839846382855-t10.73-add-friends-share-link-2024.png (I24),
// a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png (E26), a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (M24),
// a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png (NG2), a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png (CC),
// a-virgi-7686278541255642390-t44.23-suggested-friends-es.png, -t52.23-request-pending-es.png (SF).
package app.feature.account.groups

import android.Manifest
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.DataError
import app.data.model.GroupInvite
import app.data.model.GroupKind
import app.data.model.MemberRole
import app.designsystem.R
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.dataError
import app.feature.account.platform.DeviceContact
import app.feature.account.platform.ExternalActions
import app.ui.components.AccentTitle
import app.ui.components.Avatar
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.HeaderCircleButton
import app.ui.components.HeaderCircleFill
import app.ui.components.HudOverlay
import app.ui.components.LightPill
import app.ui.components.LightPillShape
import app.ui.components.PermissionCard
import app.ui.components.TextLink
import app.ui.components.TitleSplit
import app.ui.format.Formats
import app.ui.permissions.PermissionRationale
import app.ui.permissions.rememberPermissionRequest
import app.ui.system.SystemAlertDialog
import app.ui.text.TextRoles
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.ZoneId

@Immutable
data class GroupInviteUiState(
    val groupName: String = "",
    val kind: GroupKind = GroupKind.Friends,
    /** The caller's live invite (reused), null until one exists. */
    val invite: GroupInvite? = null,
    val canTurnOff: Boolean = false,
    val loading: Boolean = false,
    val full: Boolean = false,
    val maxMembers: Int? = null,
    val error: Boolean = false,
    val contactsGranted: Boolean = false,
    val contacts: List<DeviceContact> = emptyList(),
    val invited: Set<String> = emptySet(),
    val cardDismissed: Boolean = false,
    val confirmTurnOff: Boolean = false,
)

class GroupInviteViewModel(private val env: AccountEnvironment, private val groupId: String) : AccountViewModel() {
    private val mutable = MutableStateFlow(GroupInviteUiState(contactsGranted = env.isGranted(Manifest.permission.READ_CONTACTS)))
    val state: StateFlow<GroupInviteUiState> = mutable.asStateFlow()

    init {
        load()
        if (mutable.value.contactsGranted) loadContacts()
    }

    fun load() {
        mutable.update { it.copy(error = false) }
        viewModelScope.launch {
            try {
                val group = env.backend.group(groupId)
                if (group != null) mutable.update { it.copy(groupName = group.name, kind = group.kind) }
                val me = env.backend.currentUserId
                env.backend.observeMembers(groupId).collect { page ->
                    val members = page.value ?: return@collect
                    val max = runCatching { env.backend.publicConfig().maxGroupMembers }.getOrNull()
                    val admin = members.any { it.member.userId == me && it.member.role == MemberRole.Admin }
                    mutable.update { it.copy(full = max != null && members.size >= max, maxMembers = max, canTurnOff = admin) }
                }
                val mine = env.backend.activeInvites(groupId).firstOrNull { it.createdBy == me }
                mutable.update { it.copy(invite = mine, canTurnOff = it.canTurnOff || mine != null) }
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(error = true) }
            }
        }
    }

    /** First tap: `create_invite` when the caller has no live invite (HUD), then the share sheet. */
    fun share(onLink: (url: String, groupName: String) -> Unit) {
        val existing = mutable.value.invite
        if (existing != null) {
            linkOf(existing)?.let { onLink(it, mutable.value.groupName) } ?: haptic(Tokens.Haptics.globalError)
            return
        }
        mutable.update { it.copy(loading = true) }
        viewModelScope.launch {
            try {
                val invite = env.backend.createInvite(groupId)
                mutable.update { it.copy(loading = false, invite = invite, canTurnOff = true) }
                linkOf(invite)?.let { onLink(it, mutable.value.groupName) } ?: haptic(Tokens.Haptics.globalError)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(loading = false, error = true) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    fun askTurnOff() = mutable.update { it.copy(confirmTurnOff = true) }
    fun cancelTurnOff() = mutable.update { it.copy(confirmTurnOff = false) }

    /** Optimistic: the link section returns to "no invite" at once; restored if `revoke_invite` fails. */
    fun turnOff() {
        val invite = mutable.value.invite ?: return
        mutable.update { it.copy(confirmTurnOff = false, invite = null) }
        haptic(Tokens.Haptics.globalWarning)
        viewModelScope.launch {
            try {
                env.backend.revokeInvite(invite.token)
                toast(R.string.groups_invite_link_turnedoff)
            } catch (t: Throwable) {
                t.dataError()
                mutable.update { it.copy(invite = invite) }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    fun dismissCard() = mutable.update { it.copy(cardDismissed = true) }

    fun onContactsPermission(granted: Boolean) {
        mutable.update { it.copy(contactsGranted = granted) }
        if (granted) loadContacts()
    }

    fun markInvited(contact: DeviceContact) = mutable.update { it.copy(invited = it.invited + contact.id) }

    /** The invite link for SMS, creating the invite first when needed. */
    fun linkForSms(onLink: (url: String, groupName: String) -> Unit) = share(onLink)

    private fun loadContacts() {
        viewModelScope.launch {
            val contacts = runCatching { env.contacts.contacts() }.getOrDefault(emptyList())
            mutable.update { it.copy(contacts = contacts) }
        }
    }

    private fun linkOf(invite: GroupInvite): String? = env.inviteLinks.url(invite.token)
}

@Composable
fun GroupInviteRoute(nav: NavController, groupId: String) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val vm = viewModel(key = "invite:$groupId") { GroupInviteViewModel(env, groupId) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    fun message(url: String, groupName: String): String = BlockedCopy.inviteLinkMessage(context, groupName, url) ?: url
    val contactsRequest = rememberPermissionRequest(
        Manifest.permission.READ_CONTACTS,
        PermissionRationale(
            title = stringResource(R.string.system_permissions_rationale_contacts_title),
            message = BlockedCopy.rationaleContactsMessage(context),
            notNow = stringResource(R.string.system_permissions_rationale_notnow),
            continueLabel = stringResource(R.string.system_permissions_rationale_continue),
            openSettings = stringResource(R.string.system_permissions_opensettings),
        ),
        onResult = vm::onContactsPermission,
    )
    GroupInviteScreen(
        state = state,
        zone = env.zone(),
        onClose = { nav.popBackStack() },
        onShare = { vm.share { url, name -> ExternalActions.share(context, message(url, name)) } },
        onTurnOff = vm::askTurnOff,
        onConfirmTurnOff = vm::turnOff,
        onCancelTurnOff = vm::cancelTurnOff,
        onRetry = vm::load,
        onEnableContacts = contactsRequest::launch,
        onDismissCard = vm::dismissCard,
        onInviteContact = { contact ->
            vm.linkForSms { url, name ->
                ExternalActions.smsCompose(context, contact.phone, message(url, name))
                vm.markInvited(contact)
            }
        },
    )
}

@Composable
internal fun inviteTitle(kind: GroupKind, groupName: String): Pair<String, String> {
    val formatted = when (kind) {
        GroupKind.Friends -> stringResource(R.string.groups_invite_title_friends, groupName)
        GroupKind.Family -> stringResource(R.string.groups_invite_title_family, groupName)
        GroupKind.Roommates -> stringResource(R.string.groups_invite_title_roommates, groupName)
        GroupKind.Custom -> stringResource(R.string.groups_invite_title_custom, groupName)
    }
    return TitleSplit.aroundAccent(formatted, groupName)
}

@Composable
internal fun contactsCardTitle(kind: GroupKind): String = when (kind) {
    GroupKind.Friends -> stringResource(R.string.onboarding_permission_contacts_card_title_friends)
    GroupKind.Family -> stringResource(R.string.onboarding_permission_contacts_card_title_family)
    GroupKind.Roommates -> stringResource(R.string.onboarding_permission_contacts_card_title_roommates)
    GroupKind.Custom -> stringResource(R.string.onboarding_permission_contacts_card_title_custom)
}

@Composable
fun GroupInviteScreen(
    state: GroupInviteUiState,
    zone: ZoneId,
    onClose: () -> Unit,
    onShare: () -> Unit,
    onTurnOff: () -> Unit,
    onConfirmTurnOff: () -> Unit,
    onCancelTurnOff: () -> Unit,
    onRetry: () -> Unit,
    onEnableContacts: () -> Unit,
    onDismissCard: () -> Unit,
    onInviteContact: (DeviceContact) -> Unit,
) {
    val (line1, line2) = inviteTitle(state.kind, state.groupName)
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
        LazyColumn(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
            item(key = "header") {
                Box(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalHeaderInset)) {
                    HeaderCircleButton(Tokens.Icons.globalClose, stringResource(R.string.groups_invite_close_accessibilitylabel), onClose, fill = HeaderCircleFill.OnDeep)
                }
            }
            item(key = "title") { AccentTitle(line1, line2, modifier = Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH)) }
            item(key = "gap1") { Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeTitleToContent)) }
            when {
                state.full -> item(key = "full") {
                    EmptyState(
                        stringResource(R.string.groups_invite_full_title, state.groupName),
                        state.maxMembers?.let { stringResource(R.string.groups_invite_full_detail, it.toString()) },
                    )
                }
                state.error -> item(key = "error") {
                    EmptyState(
                        stringResource(R.string.groups_invite_error_title),
                        stringResource(R.string.groups_invite_error_detail),
                        action = EmptyStateAction(stringResource(R.string.groups_invite_error_retry), onRetry),
                    )
                }
                else -> {
                    item(key = "link") { LinkSection(state, zone, onShare, onTurnOff) }
                    item(key = "gap2") { Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeTitleToContent)) }
                    item(key = "contactsLabel") { SectionLabel(stringResource(R.string.groups_invite_contacts_label), icon = null) }
                    if (!state.contactsGranted) {
                        if (!state.cardDismissed) item(key = "card") {
                            PermissionCard(
                                title = contactsCardTitle(state.kind),
                                detail = stringResource(R.string.onboarding_permission_contacts_card_detail),
                                buttonText = stringResource(R.string.onboarding_permission_contacts_card_button),
                                onButton = onEnableContacts,
                                onDismiss = onDismissCard,
                                dismissLabel = stringResource(R.string.onboarding_permission_contacts_card_dismissaccessibilitylabel),
                                modifier = Modifier.padding(horizontal = Tokens.Sizes.onboardingPermissionContactsSizeCardMarginH),
                            )
                        }
                    } else {
                        items(state.contacts, key = { it.id }, contentType = { "contact" }) { contact ->
                            ContactRow(contact, invited = contact.id in state.invited, onInvite = { onInviteContact(contact) })
                        }
                    }
                }
            }
        }
        HudOverlay(state.loading, stringResource(R.string.groups_create_hud_loading))
        if (state.confirmTurnOff) {
            SystemAlertDialog(
                title = stringResource(R.string.groups_invite_link_turnoff_title),
                text = stringResource(R.string.groups_invite_link_turnoff_message),
                confirmLabel = stringResource(R.string.groups_invite_link_turnoff_confirm),
                onConfirm = onConfirmTurnOff,
                dismissLabel = stringResource(R.string.groups_invite_link_turnoff_cancel),
                onDismiss = onCancelTurnOff,
                destructive = true,
            )
        }
    }
}

/** Section label (text role `sectionLabel`, `color.global.textSecondary`) with an optional leading glyph. */
@Composable
private fun SectionLabel(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector?) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH).semantics(mergeDescendants = true) { heading() },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap, Alignment.CenterHorizontally),
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = Tokens.Colors.globalTextSecondary)
        Text(text, style = TextRoles.sectionLabel, color = Tokens.Colors.globalTextSecondary)
    }
}

/**
 * Link section: label `groups.invite.link.label` with `icon.global.link`; white pill
 * `groups.invite.link.share` (link glyph); `groups.invite.link.expiry` (caption, gray) once an invite
 * exists; "turn off link" lime text link for the link's creator and admins.
 */
@Composable
private fun LinkSection(state: GroupInviteUiState, zone: ZoneId, onShare: () -> Unit, onTurnOff: () -> Unit) {
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        SectionLabel(stringResource(R.string.groups_invite_link_label), Tokens.Icons.globalLink)
        LightPill(stringResource(R.string.groups_invite_link_share), onShare, leadingIcon = Tokens.Icons.globalLink)
        val invite = state.invite
        if (invite != null) {
            Text(stringResource(R.string.groups_invite_link_expiry, Formats.date(invite.expiresAt, zone)), style = TextRoles.caption, color = Tokens.Colors.globalTextSecondary)
            if (state.canTurnOff) {
                Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
                TextLink(stringResource(R.string.groups_invite_link_turnoff), onTurnOff)
            }
        }
    }
}

/**
 * Contact row: pitch `groups.invite.size.pickerRowPitch`, side margin `size.global.screenMargin`;
 * avatar `size.global.avatarPicker` (photo, or gray + person glyph); name
 * `groups.invite.fontSize.pickerName` / `.fontWeight.pickerName` white; trailing white "invite" pill
 * (`onboarding.permission.contacts.size.cardButtonWidth` × `.cardButtonHeight`, capsule), then
 * "invited" in `color.global.textSecondary`. Avatar → name gap: `size.global.headerGap` (not measured).
 */
@Composable
private fun ContactRow(contact: DeviceContact, invited: Boolean, onInvite: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.groupsInviteSizePickerRowPitch).padding(horizontal = Tokens.Sizes.globalScreenMargin),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
    ) {
        Avatar(contact.photo, Tokens.Sizes.globalAvatarPicker)
        Text(
            contact.name,
            style = dsTextStyle(Tokens.FontSizes.groupsInviteFontSizePickerName, Tokens.FontWeights.groupsInviteFontWeightPickerName),
            color = Tokens.Colors.globalTextPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (invited) {
            Text(stringResource(R.string.groups_invite_contacts_invited), style = TextRoles.button, color = Tokens.Colors.globalTextSecondary)
        } else {
            LightPill(
                stringResource(R.string.groups_invite_contacts_invite),
                onInvite,
                shape = LightPillShape.Capsule,
                height = Tokens.Sizes.onboardingPermissionContactsSizeCardButtonHeight,
                modifier = Modifier.width(Tokens.Sizes.onboardingPermissionContactsSizeCardButtonWidth),
            )
        }
    }
}
