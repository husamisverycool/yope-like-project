package app.model

import kotlinx.serialization.Serializable

/**
 * Navigation destinations (type-safe Navigation Compose routes). Each names the surface id from
 * docs/SURFACES.md it hosts; the screens pass fills them in.
 */
@Serializable
sealed interface AppRoute {
    val surface: String

    // Getting in
    @Serializable data object AuthPhone : AppRoute { override val surface get() = "auth.phone" }
    @Serializable data object AuthCode : AppRoute { override val surface get() = "auth.code" }
    @Serializable data object AuthAgeGate : AppRoute { override val surface get() = "auth.agegate" }
    @Serializable data object AuthProfile : AppRoute { override val surface get() = "auth.profile" }
    @Serializable data object PermissionCamera : AppRoute { override val surface get() = "onboarding.permission.camera" }
    @Serializable data object PermissionNotifications : AppRoute { override val surface get() = "onboarding.permission.notifications" }
    @Serializable data object PermissionPhotos : AppRoute { override val surface get() = "onboarding.permission.photos" }
    @Serializable data object PermissionContacts : AppRoute { override val surface get() = "onboarding.permission.contacts" }
    @Serializable data object OnboardingWidget : AppRoute { override val surface get() = "onboarding.widget" }
    /**
     * invite.web (Android join path): the native invite card; [join] = continue at once (the person already chose to join
     * before signing up — the pending invite at the end of onboarding), else "Let's go" continues.
     */
    @Serializable data class InviteJoin(val token: String, val join: Boolean = false) : AppRoute { override val surface get() = "invite.web" }

    // Groups
    @Serializable data object GroupsList : AppRoute { override val surface get() = "groups.list" }
    @Serializable data object GroupCreate : AppRoute { override val surface get() = "groups.create" }
    @Serializable data class GroupInvite(val groupId: String) : AppRoute { override val surface get() = "groups.invite" }
    @Serializable data class Group(val groupId: String) : AppRoute { override val surface get() = "groups.screen" }
    @Serializable data class GroupSettings(val groupId: String) : AppRoute { override val surface get() = "groups.settings" }

    // Posting
    @Serializable data class Camera(val groupId: String? = null) : AppRoute { override val surface get() = "camera.capture" }
    @Serializable data object SendTo : AppRoute { override val surface get() = "camera.sendto" }

    // Chat and photos
    @Serializable data class Chat(val groupId: String, val focusMessageId: String? = null) : AppRoute { override val surface get() = "chat.thread" }
    @Serializable data class PhotoViewer(val groupId: String, val postId: String) : AppRoute { override val surface get() = "photo.viewer" }

    // Walls
    @Serializable data object WallMine : AppRoute { override val surface get() = "walls.mine" }
    @Serializable data class WallMember(val userId: String) : AppRoute { override val surface get() = "walls.member" }
    @Serializable data object WallsBrowse : AppRoute { override val surface get() = "walls.browse" }

    // Daily invitation
    @Serializable data class DailyCapture(val groupId: String, val invitationId: String) : AppRoute { override val surface get() = "daily.capture" }
    @Serializable data class Collage(val groupId: String, val invitationId: String) : AppRoute { override val surface get() = "collage.view" }
    /** `collage.view` by the collage's id (a widget showing the group's collage of the day): its invitation is resolved first. */
    @Serializable data class CollageById(val groupId: String, val collageId: String) : AppRoute { override val surface get() = "collage.view" }

    // The week
    @Serializable data class WeekRecap(val groupId: String, val recapId: String) : AppRoute { override val surface get() = "week.recap" }
    @Serializable data class WeekEdit(val groupId: String, val recapId: String) : AppRoute { override val surface get() = "week.edit" }
    @Serializable data class WeekHistory(val groupId: String) : AppRoute { override val surface get() = "week.history" }
    @Serializable data class AlbumsList(val groupId: String) : AppRoute { override val surface get() = "albums.list" }
    @Serializable data class AlbumView(val groupId: String, val albumId: String) : AppRoute { override val surface get() = "albums.view" }

    // Remembering
    @Serializable data object OnThisDay : AppRoute { override val surface get() = "onthisday" }
    @Serializable data object BirthdayAdd : AppRoute { override val surface get() = "birthday.add" }
    @Serializable data class BirthdayContribute(val groupId: String, val requestId: String) : AppRoute { override val surface get() = "birthday.contribute" }
    @Serializable data class Tribute(val groupId: String, val tributeId: String) : AppRoute { override val surface get() = "birthday.tribute" }
    @Serializable data class YearStory(val groupId: String, val year: Int) : AppRoute { override val surface get() = "year.story" }

    // Account, notifications, subscription, safety
    @Serializable data object Settings : AppRoute { override val surface get() = "settings.root" }
    @Serializable data object SettingsNotifications : AppRoute { override val surface get() = "settings.notifications" }
    @Serializable data object SettingsAccount : AppRoute { override val surface get() = "settings.account" }
    @Serializable data object SettingsBlocked : AppRoute { override val surface get() = "settings.blocked" }
    @Serializable data object Paywall : AppRoute { override val surface get() = "paywall" }
    @Serializable data class SafetyReport(val groupId: String? = null, val postId: String? = null, val userId: String? = null) : AppRoute { override val surface get() = "safety.report" }
    @Serializable data class SafetyBlock(val userId: String) : AppRoute { override val surface get() = "safety.block" }
}

/** Where a [DeepLink] lands, as a full back stack (first = bottom), so Back is predictable. */
object DeepLinkRouting {
    val home: AppRoute = AppRoute.GroupsList

    fun backStack(link: DeepLink): List<AppRoute> = when (link) {
        is DeepLink.Invite -> listOf(AppRoute.InviteJoin(link.token))
        is DeepLink.Camera -> listOf(home, AppRoute.Camera(link.groupId))
        is DeepLink.Post -> listOf(home, AppRoute.Group(link.groupId), AppRoute.PhotoViewer(link.groupId, link.postId))
        is DeepLink.ChatMessage -> listOf(home, AppRoute.Group(link.groupId), AppRoute.Chat(link.groupId, link.messageId))
        is DeepLink.DailyInvitation -> listOf(home, AppRoute.DailyCapture(link.groupId, link.invitationId))
        is DeepLink.Recap -> listOf(home, AppRoute.Group(link.groupId), AppRoute.WeekRecap(link.groupId, link.recapId))
        is DeepLink.BirthdayRequest -> listOf(home, AppRoute.BirthdayContribute(link.groupId, link.requestId))
        is DeepLink.Tribute -> listOf(home, AppRoute.Tribute(link.groupId, link.tributeId))
        is DeepLink.YearStory -> listOf(home, AppRoute.YearStory(link.groupId, link.year))
        is DeepLink.Plan -> link.groupId?.let { group -> listOf(home, AppRoute.Group(group), PlanRoute(link.planId, group)) }
            ?: listOf(home, PlanRoute(link.planId))
        is DeepLink.Collage -> listOf(home, AppRoute.Group(link.groupId), AppRoute.CollageById(link.groupId, link.collageId))
        // widget.styles → Locked: without the paywall (premium, or the session's prompt already used) the widget's own place.
        is DeepLink.Premium -> link.then?.takeUnless { it is DeepLink.Premium }?.let(::backStack) ?: listOf(home)
    }

    /**
     * [link]'s destination with the paywall at its perk on top ([PaywallPerkRoute]): what a locked widget style's tap opens
     * when the session's one prompt is granted; closing the paywall leaves the widget's own place (iOS `AppRouter`'s
     * `afterPaywall`).
     */
    fun withPaywall(link: DeepLink.Premium): List<AppRoute> = backStack(link) + PaywallPerkRoute(link.perk)

    /** The destination itself (top of [backStack]). */
    fun destination(link: DeepLink): AppRoute = backStack(link).last()
}
