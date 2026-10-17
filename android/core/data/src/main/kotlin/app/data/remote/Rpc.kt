package app.data.remote

/**
 * Every client-facing RPC of docs/API.md §6 with its parameter names. Calls are checked against
 * this list (an unknown parameter is a programming error), and `SchemaConformanceIntegrationTest`
 * compares it with the live database's function signatures.
 *
 * [required] are the parameters without a default (they must be sent, possibly as JSON null);
 * [optional] have SQL defaults (omitted = default).
 */
enum class Rpc(val function: String, val required: Set<String>, val optional: Set<String> = emptySet(), val anon: Boolean = false) {
    // §6.1 Groups
    CreateGroup("create_group", setOf("p_name", "p_kind", "p_time_zone"), setOf("p_cover_path", "p_waking_start", "p_waking_end")),
    UpdateGroup("update_group", setOf("p_group_id"), setOf("p_name", "p_kind", "p_cover_path", "p_time_zone")),
    CreateInvite("create_invite", setOf("p_group_id")),
    RevokeInvite("revoke_invite", setOf("p_token")),
    InvitePreview("invite_preview", setOf("p_token"), anon = true),
    JoinGroup("join_group", setOf("p_token")),
    RemoveMember("remove_member", setOf("p_group_id", "p_user_id")),
    LeaveGroup("leave_group", setOf("p_group_id")),
    SetGroupMuted("set_group_muted", setOf("p_group_id", "p_muted")),
    SetGroupInvitationHours("set_group_invitation_hours", setOf("p_group_id", "p_start", "p_end")),
    SetGroupInvitationPaused("set_group_invitation_paused", setOf("p_group_id", "p_paused")),

    // §6.2 Photos, chat, reactions, tags
    CreatePost(
        "create_post", setOf("p_media_id", "p_group_ids"),
        setOf("p_caption", "p_voice_path", "p_voice_duration_ms", "p_voice_levels", "p_invitation_id", "p_reply_to_post_id"),
    ),
    SendMessage(
        "send_message", setOf("p_group_id", "p_kind"),
        setOf("p_body", "p_voice_path", "p_voice_duration_ms", "p_voice_levels", "p_reply_to_post_id", "p_reply_to_message_id"),
    ),
    DeleteMessage("delete_message", setOf("p_message_id")),
    React("react", setOf("p_post_id", "p_emoji")),
    Unreact("unreact", setOf("p_post_id", "p_emoji")),
    TagSelf("tag_self", setOf("p_post_id")),
    UntagSelf("untag_self", setOf("p_post_id")),
    DeleteMedia("delete_media", setOf("p_media_id")),
    DeletePost("delete_post", setOf("p_post_id")),

    // §6.3 Account and safety
    DeleteAccount("delete_account", emptySet()),
    BlockUser("block_user", setOf("p_user_id")),
    UnblockUser("unblock_user", setOf("p_user_id")),
    Report("report", setOf("p_target_kind", "p_target_id", "p_reason")),
    RegisterDevice("register_device", setOf("p_platform", "p_push_token"), setOf("p_push_to_start_token", "p_live_activities_enabled")),
    UnregisterDevice("unregister_device", setOf("p_push_token")),
    SetQuietHours("set_quiet_hours", setOf("p_start", "p_end", "p_time_zone")),
    /** Pause All (migration 0037): no notification until the next midnight of `p_time_zone`. */
    SetNotificationsPaused("set_notifications_paused", setOf("p_paused"), setOf("p_time_zone")),
    SetBirthday("set_birthday", setOf("p_birthday", "p_opt_in")),
    ConfirmAge("confirm_age", setOf("p_birthdate")),

    // §6.4 Browsing and remembering
    Wall("wall", setOf("p_user_id"), setOf("p_before", "p_limit")),
    GroupHistoryWeeks("group_history_weeks", setOf("p_group_id"), setOf("p_before_week", "p_limit")),
    OnThisDay("on_this_day", setOf("p_group_id", "p_local_date")),
    UpdateRecap("update_recap", setOf("p_recap_id"), setOf("p_items", "p_text", "p_collage_ids")),
    GroupCollages("group_collages", setOf("p_group_id"), setOf("p_from", "p_to")),
    SaveAlbum("save_album", setOf("p_group_id", "p_name", "p_post_ids")),
    RenameAlbum("rename_album", setOf("p_album_id", "p_name")),
    DeleteAlbum("delete_album", setOf("p_album_id")),
    ContributeTribute("contribute_tribute", setOf("p_request_id", "p_post_id", "p_line")),
    GroupTributes("group_tributes", setOf("p_group_id")),

    // §14.1 Selfie reactions
    ReactWithSelfie("react_with_selfie", setOf("p_post_id", "p_image_path")),
    RemoveSelfieReaction("remove_selfie_reaction", setOf("p_post_id"), setOf("p_user_id")),

    // §14.3 Overnight photos
    CreateOvernightPost("create_overnight_post", setOf("p_media_id", "p_group_ids")),
    MyDeveloping("my_developing", emptySet()),
    SetOvernightAlerts("set_overnight_alerts", setOf("p_on")),
    GroupDeveloping("group_developing", setOf("p_group_id")),

    // §14.2 Plans
    CreatePlan(
        "create_plan", setOf("p_group_id", "p_title", "p_starts_at"),
        setOf("p_all_day", "p_ends_at", "p_place", "p_note", "p_cover_path"),
    ),
    UpdatePlan(
        "update_plan", setOf("p_plan_id", "p_title", "p_starts_at"),
        setOf("p_all_day", "p_ends_at", "p_place", "p_note", "p_cover_path"),
    ),
    CancelPlan("cancel_plan", setOf("p_plan_id")),
    RestorePlan("restore_plan", setOf("p_plan_id")),
    AnswerPlan("answer_plan", setOf("p_plan_id", "p_answer")),
    ClearAnswer("clear_answer", setOf("p_plan_id")),
    PlanPhotos("plan_photos", setOf("p_plan_id")),
    NextPlans("next_plans", emptySet(), setOf("p_group_id")),
    GroupPlans("group_plans", setOf("p_group_id")),

    // §14.4 Weekly question
    SetGroupWeeklyQuestion("set_group_weekly_question", setOf("p_group_id", "p_on")),
    CurrentGroupQuestion("current_group_question", setOf("p_group_id")),
    HideQuestion("hide_question", setOf("p_question_id")),
    AnswerQuestion("answer_question", setOf("p_post_id", "p_question_id")),
    ;

    val parameters: Set<String> get() = required + optional

    /** Throws when [keys] is not a valid argument set for this function. */
    fun check(keys: Set<String>) {
        val unknown = keys - parameters
        require(unknown.isEmpty()) { "$function: unknown parameter(s) $unknown" }
        val missing = required - keys
        require(missing.isEmpty()) { "$function: missing parameter(s) $missing" }
    }
}

/** Tables and views the client reads or writes (docs/API.md §5). */
object Tables {
    const val PROFILES = "profiles"
    const val PROFILE_PRIVATE = "profile_private"
    const val GROUPS = "groups"
    const val GROUP_MEMBERS = "group_members"
    const val GROUP_INVITES = "group_invites"
    const val BLOCKS = "blocks"
    const val MEDIA = "media"
    const val POSTS = "posts"
    const val MESSAGES = "messages"
    const val REACTIONS = "reactions"
    const val SELFIE_REACTIONS = "selfie_reactions"
    const val POST_TAGS = "post_tags"
    const val DAILY_INVITATIONS = "daily_invitations"
    const val COLLAGES = "collages"
    const val WEEKLY_RECAPS = "weekly_recaps"
    const val ALBUMS = "albums"
    const val ALBUM_ITEMS = "album_items"
    const val TRIBUTE_REQUESTS = "tribute_requests"
    const val TRIBUTE_CONTRIBUTIONS = "tribute_contributions"
    const val TRIBUTES = "tributes"
    const val YEAR_STORIES = "year_stories"
    const val DEVICES = "devices"
    const val NOTIFICATION_SETTINGS = "notification_settings"
    const val ENTITLEMENTS = "entitlements"
    const val PUBLIC_APP_CONFIG = "public_app_config"
    const val PLANS = "plans"
    const val PLAN_ANSWERS = "plan_answers"
    const val GROUP_QUESTIONS = "group_questions"
}
