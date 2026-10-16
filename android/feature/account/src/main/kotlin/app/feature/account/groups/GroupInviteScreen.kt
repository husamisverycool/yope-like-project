// Surface: groups.invite — invite by link or from contacts. Spec: design/surfaces/groups.invite.md (contacts per
// design/surfaces/onboarding.permission.contacts.md, Android block). References: references/auto/retro/press/
// tc-2024-04-retro-journals-5.png (TC-J5 phones 1–2: book cover 281.8 × 393.5 + shadow, eye note #767676, "Turn on link sharing",
// grouped menu with "Reset link" and the red row, 64-pt share circles 90.4 apart), references/auto/retro/press/
// tc-2024-04-journals-1.webp (TC-J1: cover shadow), references/auto/retro/press/tc-2023-07-retro-1b.webp (TC-1B: people rows),
// references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: link-sharing, invite and contacts strings).
package app.feature.account.groups

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.GroupInvite
import app.data.model.GroupKind
import app.designsystem.LocalDsDarkTheme
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountViewModel
import app.feature.account.common.BookCover
import app.feature.account.common.CollectEvents
import app.feature.account.common.SheetPage
import app.feature.account.common.dataError
import app.feature.account.common.sheetBottomPadding
import app.feature.account.platform.DeviceContact
import app.feature.account.platform.ExternalActions
import app.ui.components.ActivityIndicator
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.GroupedPosition
import app.ui.components.Hairline
import app.ui.components.HeaderAction
import app.ui.components.PeopleRow
import app.ui.components.PrimaryButton
import app.ui.components.SectionHeader
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.format.Formats
import app.ui.permissions.PermissionRationale
import app.ui.permissions.rememberPermissionRequest
import app.ui.system.SystemAlertDialog
import app.ui.text.TextRoles
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.ZoneId

@Immutable
data class GroupInviteUiState(
    val groupName: String = "",
    val kind: GroupKind = GroupKind.Friends,
    val coverUrl: String? = null,
    /** The caller's live invite (link on), null = link off. */
    val invite: GroupInvite? = null,
    /** Reading `group_invites` (the menu / capsule area shows the platform indicator). */
    val loading: Boolean = true,
    /** `create_invite` (turn on, reset) in flight: the capsule is busy. */
    val creating: Boolean = false,
    val full: Boolean = false,
    val maxMembers: Int? = null,
    val error: Boolean = false,
    val offline: Boolean = false,
    val contactsGranted: Boolean = false,
    val contacts: List<DeviceContact>? = null,
    val invited: Set<String> = emptySet(),
    val confirmTurnOff: Boolean = false,
)

/**
 * The invite sheet: reads the group (name, kind, cover), its members (only to know whether it is full — never shown as a
 * number) and the caller's live invite; link sharing is turned on explicitly (`create_invite`), reset (`revoke_invite` then
 * `create_invite`) and turned off (`revoke_invite`, confirmed) — MERGE RA-11.
 */
class GroupInviteViewModel(private val env: AccountEnvironment, private val groupId: String) : AccountViewModel() {
    private val mutable = MutableStateFlow(GroupInviteUiState(contactsGranted = env.isGranted(Manifest.permission.READ_CONTACTS)))
    val state: StateFlow<GroupInviteUiState> = mutable.asStateFlow()

    init {
        load()
        if (mutable.value.contactsGranted) loadContacts()
    }

    fun load() {
        mutable.update { it.copy(error = false, offline = false, loading = true) }
        viewModelScope.launch {
            try {
                val group = env.backend.group(groupId)
                if (group != null) {
                    val cover = group.coverPath?.let { path -> runCatching { env.backend.signedUrls(listOf(path))[path] }.getOrNull() }
                    mutable.update { it.copy(groupName = group.name, kind = group.kind, coverUrl = cover) }
                }
                val me = env.backend.currentUserId
                val members = env.backend.observeMembers(groupId).first { it.value != null || !it.refreshing }.value.orEmpty()
                val max = runCatching { env.backend.publicConfig().maxGroupMembers }.getOrNull()
                val mine = env.backend.activeInvites(groupId).firstOrNull { it.createdBy == me && it.isUsable(env.clock.instant()) }
                mutable.update { it.copy(full = max != null && members.size >= max, maxMembers = max, invite = mine, loading = false) }
            } catch (t: Throwable) {
                val offline = t.dataError() == DataError.Network
                mutable.update { it.copy(loading = false, error = !offline, offline = offline) }
            }
        }
    }

    /** "Turn on link sharing": `create_invite` → link on. */
    fun turnOn() = create(replacing = null)

    /** "Reset link": the old link stops working, a new one is made. */
    fun reset() {
        val old = mutable.value.invite ?: return
        create(replacing = old)
    }

    private fun create(replacing: GroupInvite?) {
        if (mutable.value.creating) return
        mutable.update { it.copy(creating = true) }
        viewModelScope.launch {
            try {
                if (replacing != null) env.backend.revokeInvite(replacing.token)
                val invite = env.backend.createInvite(groupId)
                mutable.update { it.copy(creating = false, invite = invite) }
            } catch (t: Throwable) {
                val error = t.dataError()
                val full = (error as? DataError.Api)?.code == ApiError.GroupFull
                mutable.update {
                    it.copy(
                        creating = false,
                        full = it.full || full,
                        error = !full && error != DataError.Network,
                        offline = error == DataError.Network,
                        invite = if (replacing != null) null else it.invite,
                    )
                }
                haptic(Tokens.Haptics.globalError)
            }
        }
    }

    fun askTurnOff() = mutable.update { it.copy(confirmTurnOff = true) }
    fun cancelTurnOff() = mutable.update { it.copy(confirmTurnOff = false) }

    /** Optimistic: link off at once (cross-fade to the capsule); restored if `revoke_invite` fails. */
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

    fun onContactsPermission(granted: Boolean) {
        mutable.update { it.copy(contactsGranted = granted) }
        if (granted) loadContacts()
    }

    fun markInvited(contact: DeviceContact) = mutable.update { it.copy(invited = it.invited + contact.id) }

    /** The link of the live invite, or null (link off / no invite domain configured). */
    fun link(): String? = mutable.value.invite?.let { env.inviteLinks.url(it.token) }

    private fun loadContacts() {
        viewModelScope.launch {
            val contacts = runCatching { env.contacts.contacts() }.getOrDefault(emptyList())
            mutable.update { it.copy(contacts = contacts) }
        }
    }
}

@Composable
fun GroupInviteRoute(nav: NavController, groupId: String) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val vm = viewModel(key = "invite:$groupId") { GroupInviteViewModel(env, groupId) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    // `groups.invite.link.message` is BLOCKED while it names the app ({app_name}): release builds share the link alone.
    fun message(url: String): String = BlockedCopy.inviteLinkMessage(context, state.groupName, url) ?: url
    val contactsRequest = rememberPermissionRequest(
        Manifest.permission.READ_CONTACTS,
        PermissionRationale(
            title = stringResource(R.string.system_permissions_rationale_contacts_title),
            message = stringResource(R.string.system_permissions_rationale_contacts_message),
            notNow = stringResource(R.string.system_permissions_rationale_notnow),
            continueLabel = stringResource(R.string.system_permissions_rationale_continue),
            openSettings = stringResource(R.string.system_permissions_opensettings),
        ),
        onResult = vm::onContactsPermission,
    )
    GroupInviteScreen(
        state = state,
        zone = env.zone(),
        actions = GroupInviteActions(
            onClose = { nav.popBackStack() },
            onTurnOn = vm::turnOn,
            onReset = vm::reset,
            onTurnOff = vm::askTurnOff,
            onConfirmTurnOff = vm::turnOff,
            onCancelTurnOff = vm::cancelTurnOff,
            onMessage = { vm.link()?.let { ExternalActions.smsCompose(context, "", message(it)) } },
            onCopy = {
                vm.link()?.let { url ->
                    copyToClipboard(context, url)
                    env.toasts.show(context.getString(R.string.groups_invite_link_copied))
                }
            },
            onShare = { vm.link()?.let { ExternalActions.share(context, message(it)) } },
            onRetry = vm::load,
            onEnableContacts = contactsRequest::launch,
            onInviteContact = { contact ->
                vm.link()?.let { url ->
                    ExternalActions.smsCompose(context, contact.phone, message(url))
                    vm.markInvited(contact)
                } ?: vm.turnOn()
            },
        ),
    )
}

/** Copies the invite link (`groups.invite.layout.share` copy: ClipboardManager). */
private fun copyToClipboard(context: Context, url: String) {
    val clipboard = context.getSystemService(ClipboardManager::class.java) ?: return
    clipboard.setPrimaryClip(ClipData.newPlainText(context.getString(R.string.groups_invite_link_copy), url))
}

/** What the invite sheet does on each control. */
@Immutable
data class GroupInviteActions(
    val onClose: () -> Unit = {},
    val onTurnOn: () -> Unit = {},
    val onReset: () -> Unit = {},
    val onTurnOff: () -> Unit = {},
    val onConfirmTurnOff: () -> Unit = {},
    val onCancelTurnOff: () -> Unit = {},
    val onMessage: () -> Unit = {},
    val onCopy: () -> Unit = {},
    val onShare: () -> Unit = {},
    val onRetry: () -> Unit = {},
    val onEnableContacts: () -> Unit = {},
    val onInviteContact: (DeviceContact) -> Unit = {},
)

/**
 * The invite sheet (C-29 page sheet: centred "Invite to {group_name}" + close; scrolls): the cover
 * (`groups.invite.size.coverWidth` × `.coverHeight`, `groups.screen.shadow.cover`), centred; the note
 * `groups.invite.size.coverToNote` under it (eye `groups.invite.icon.note` at `size.global.iconSmall`,
 * `groups.invite.size.noteGlyphGap`, text role `meta`, `groups.invite.color.note` light / secondary text dark; with a live
 * link a second line with its expiry date). `size.global.titleToContent` below: link off → C-05 "Turn on link sharing";
 * link on → the grouped menu (Reset link; Turn off link sharing in red) and the three 64-pt share targets. The two
 * cross-fade (`duration.global.fade`). `size.global.sectionGap` below: the Contacts section (C-20 header; Android: people
 * rows with the C-06 "Invite" capsule, or the C-27 permission block left-aligned).
 */
@Composable
fun GroupInviteScreen(state: GroupInviteUiState, zone: ZoneId, actions: GroupInviteActions) {
    SheetPage(
        title = stringResource(R.string.groups_invite_title, state.groupName),
        close = HeaderAction(Tokens.Icons.globalClose, stringResource(R.string.groups_invite_close_accessibilitylabel), actions.onClose),
    ) {
        LazyColumn(Modifier.fillMaxWidth(), contentPadding = PaddingValues(bottom = sheetBottomPadding()), horizontalAlignment = Alignment.CenterHorizontally) {
            item(key = "cover") {
                BookCover(
                    state.coverUrl,
                    Tokens.Sizes.groupsInviteSizeCoverWidth,
                    Tokens.Sizes.groupsInviteSizeCoverHeight,
                    Modifier.padding(top = Tokens.Sizes.globalTitleToContent),
                    contentDescription = stringResource(R.string.groups_invite_cover_accessibilitylabel, state.groupName),
                    glyph = null,
                )
            }
            item(key = "note") { Note(state, zone) }
            item(key = "link") {
                Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalTitleToContent), contentAlignment = Alignment.TopCenter) {
                    when {
                        state.full -> EmptyState(
                            stringResource(R.string.groups_invite_full_title, state.groupName),
                            state.maxMembers?.let { stringResource(R.string.groups_invite_full_detail, it.toString()) },
                        )
                        state.error || state.offline -> EmptyState(
                            stringResource(R.string.groups_invite_error_title),
                            stringResource(R.string.groups_invite_error_detail),
                            action = EmptyStateAction(stringResource(R.string.groups_invite_error_retry), actions.onRetry),
                        )
                        state.loading -> ActivityIndicator(stringResource(R.string.global_a11y_loading))
                        else -> AnimatedContent(
                            targetState = state.invite != null,
                            transitionSpec = { DsMotion.fadeIn togetherWith DsMotion.fadeOut },
                            label = "linkSharing",
                        ) { on -> if (on) LinkOn(actions) else LinkOff(state.creating, actions.onTurnOn) }
                    }
                }
            }
            if (!state.full) {
                item(key = "contactsHeader") {
                    SectionHeader(stringResource(R.string.groups_invite_contacts_label), afterContent = true)
                }
                contactsSection(state, actions)
            }
        }
    }
    if (state.confirmTurnOff) {
        SystemAlertDialog(
            title = stringResource(R.string.groups_invite_link_turnoff_title),
            text = stringResource(R.string.groups_invite_link_turnoff_message),
            confirmLabel = stringResource(R.string.groups_invite_link_turnoff_confirm),
            onConfirm = actions.onConfirmTurnOff,
            dismissLabel = stringResource(R.string.groups_invite_link_turnoff_cancel),
            onDismiss = actions.onCancelTurnOff,
            destructive = true,
        )
    }
}

/** The eye note (and the expiry line while a link is live), centred. */
@Composable
private fun Note(state: GroupInviteUiState, zone: ZoneId) {
    val color = if (LocalDsDarkTheme.current) PageRoles.secondaryText() else Tokens.Colors.groupsInviteColorNote
    Column(
        Modifier.fillMaxWidth().padding(top = Tokens.Sizes.groupsInviteSizeCoverToNote, start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin).semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Tokens.Icons.groupsInviteIconNote, contentDescription = null, tint = color, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
            Spacer(Modifier.width(Tokens.Sizes.groupsInviteSizeNoteGlyphGap))
            Text(stringResource(R.string.groups_invite_link_label, state.groupName), style = TextRoles.meta, color = color, textAlign = TextAlign.Center)
        }
        state.invite?.let { invite ->
            val date = Formats.longDate(invite.expiresAt.atZone(zone).toLocalDate())
            Text(stringResource(R.string.groups_invite_link_expiry, date), style = TextRoles.meta, color = color, textAlign = TextAlign.Center)
        }
    }
}

/** Link off: C-05 "Turn on link sharing" at `size.global.buttonMarginH` (busy while `create_invite` runs). */
@Composable
private fun LinkOff(creating: Boolean, onTurnOn: () -> Unit) {
    PrimaryButton(
        stringResource(R.string.groups_invite_link_turnon),
        onTurnOn,
        Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH),
        loading = creating,
    )
}

/**
 * Link on: the grouped menu — one C-14 group inset `size.global.buttonMarginH` (fill `color.global.surfaceSecondary.android`,
 * `radius.global.groupedRow`, hairline between rows), rows `groups.invite.size.menuRowHeight` with the glyph at
 * `groups.invite.size.menuGlyphInset` and the label (text role `textButton`) at `groups.invite.size.menuTextInset` — then,
 * `size.global.titleToContent` below, the share targets.
 */
@Composable
private fun LinkOn(actions: GroupInviteActions) {
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH)) {
            MenuRow(Tokens.Icons.groupsInviteIconReset, stringResource(R.string.groups_invite_link_reset), Tokens.Colors.globalTextPrimary, GroupedPosition.First, actions.onReset)
            MenuRow(Tokens.Icons.globalLock, stringResource(R.string.groups_invite_link_turnoff), Tokens.Colors.globalDestructive, GroupedPosition.Last, actions.onTurnOff)
        }
        Spacer(Modifier.padding(top = Tokens.Sizes.globalTitleToContent))
        ShareTargets(actions)
    }
}

@Composable
private fun MenuRow(icon: ImageVector, label: String, color: Color, position: GroupedPosition, onClick: () -> Unit) {
    val shape = position.shape()
    Column(Modifier.fillMaxWidth().clip(shape).background(PageRoles.secondarySurface, shape).tapClickable(onClick = onClick)) {
        Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.groupsInviteSizeMenuRowHeight), contentAlignment = Alignment.CenterStart) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.padding(start = Tokens.Sizes.groupsInviteSizeMenuGlyphInset).size(Tokens.Sizes.globalIcon))
            Text(label, style = TextRoles.textButton, color = color, modifier = Modifier.padding(start = Tokens.Sizes.groupsInviteSizeMenuTextInset, end = Tokens.Sizes.globalScreenMargin))
        }
        if (position.dividerBelow) Hairline()
    }
}

/**
 * Three targets, centres `groups.invite.size.targetPitch` apart: a 64-pt circle (C-11 `size.global.circleButtonLarge`,
 * `color.global.control`, glyph `size.global.icon` in `color.global.textPrimary`) and its label
 * `groups.invite.size.targetLabelGap` below (text role `meta`, `color.global.textPrimary`, centred). Each is one button.
 */
@Composable
private fun ShareTargets(actions: GroupInviteActions) {
    Row(horizontalArrangement = Arrangement.Center) {
        ShareTarget(Tokens.Icons.globalChats, stringResource(R.string.groups_invite_link_messagetarget), actions.onMessage)
        ShareTarget(Tokens.Icons.globalLink, stringResource(R.string.groups_invite_link_copy), actions.onCopy)
        ShareTarget(Tokens.Icons.globalShare, stringResource(R.string.groups_invite_link_share), actions.onShare)
    }
}

@Composable
private fun ShareTarget(icon: ImageVector, label: String, onClick: () -> Unit) {
    val pitch: Dp = Tokens.Sizes.groupsInviteSizeTargetPitch
    Column(
        Modifier.width(pitch).tapClickable(onClick = onClick).semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.size(Tokens.Sizes.globalCircleButtonLarge).background(Tokens.Colors.globalControl, CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = Tokens.Colors.globalTextPrimary, modifier = Modifier.size(Tokens.Sizes.globalIcon))
        }
        Text(
            label,
            style = TextRoles.meta,
            color = Tokens.Colors.globalTextPrimary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = Tokens.Sizes.groupsInviteSizeTargetLabelGap),
        )
    }
}

/** The Contacts section on Android (`groups.invite.layout.contacts` android). */
private fun androidx.compose.foundation.lazy.LazyListScope.contactsSection(state: GroupInviteUiState, actions: GroupInviteActions) {
    val contacts = state.contacts
    when {
        !state.contactsGranted -> item(key = "contactsBlock") {
            Box(Modifier.fillMaxWidth()) {
                EmptyState(
                    title = stringResource(R.string.onboarding_permission_contacts_card_title),
                    detail = stringResource(R.string.onboarding_permission_contacts_card_detail),
                    icon = Tokens.Icons.globalGroup,
                    action = EmptyStateAction(stringResource(R.string.onboarding_permission_contacts_card_button), actions.onEnableContacts),
                    alignment = Alignment.Start,
                )
            }
        }
        contacts == null -> item(key = "contactsLoading") { ActivityIndicator(stringResource(R.string.global_a11y_loading)) }
        contacts.isEmpty() -> item(key = "contactsEmpty") {
            Text(
                stringResource(R.string.groups_invite_contacts_empty),
                style = TextRoles.body,
                color = PageRoles.secondaryText(),
                modifier = Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin),
            )
        }
        else -> items(contacts, key = { "contact:" + it.id }) { contact ->
            val invited = contact.id in state.invited
            PeopleRow(
                name = contact.name,
                avatar = contact.photo,
                modifier = Modifier.padding(bottom = Tokens.Sizes.globalSectionHeaderToContent),
                trailing = {
                    if (invited) {
                        Text(stringResource(R.string.groups_invite_contacts_invited), style = TextRoles.listSubtitle, color = PageRoles.secondaryText())
                    } else {
                        Capsule(stringResource(R.string.groups_invite_contacts_invite), { actions.onInviteContact(contact) }, style = CapsuleStyle.Outline)
                    }
                },
            )
        }
    }
}
