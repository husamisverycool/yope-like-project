## Voice patterns

Every pattern a string may name in its `pattern` field. Since the redesign (docs/REDESIGN_BRIEF.md) **Retro's
voice governs every app surface** — including surfaces whose *mechanics* come from another app (camera, widgets,
daily invitation, chat, birthday, year story, paywall). Platform patterns (`platform.*`) govern components the
system draws. A few *content* patterns from mechanics references stay where Retro has no such feature (they say
what a string must contain; Retro's casing and punctuation still apply). Retired ids and their successors are
listed under "Retired patterns" so existing copy entries can be re-pointed by the Pass 2 groups.

Evidence: Retro's 1,673 Android strings (APK 2026.10.1150), cited by key — file
`references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` (key ⇥ value); the website
(`references/auto/retro/web/retro.app-web-copy-excerpts.txt`, "web"); iOS captures by id (H43, LAND, PAY, TC-R3 …,
see `design/components.md` "Evidence shorthands"). Rules and counts are from
`design/research/retro-package-copy-motion.md` §4 (RP). `%1$s` / `%1$d` in an example is Retro's placeholder; ours
are `{name}` style.

### Retro voice — app-wide

| id | governs | rules (case · person · length · punctuation · emoji) | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `retro.voice.second-person` | every app surface | Warm, short, second person ("you / your"); the app speaks as "we" when it must ("We will never spam your contacts."); reassurance over pressure; light self-aware humour allowed in explanations, never in errors. | "Post good photos or dumb photos with your two favorite people, no pressure." (`nux_card_message_tips_from_retro_first_week_friends`) · "We will never spam your contacts." (`contact_permission_upsell_message`) · "These photos are only visible to you." (`rewind_home_no_permission_upsell_message`) · "Beep boop — we're processing your referral code" (RP §4.1) | Guilt or pressure lines; "No Lurking" framing. |
| `retro.voice.sentence-case` | default casing: buttons, conversational titles, prompts, explanations, placeholders, menu items, toasts | Sentence case; proper names and product nouns keep their capitals ("Week 27"). 72 of 98 multi-word buttons and 95 of 175 titles are Sentence case (RP §4.1). | "Add friends" · "Choose friends" · "Send reminder" · "Try it out" · "Maybe later" (RP §4.1) · "Welcome to your weekly photo journal" (`onboarding_v3_page_title_education`) · "Who else should be here?" (RP §4.1) | — |
| `retro.voice.title-case` (kept id, updated) | tool-screen and sheet titles, settings rows and section headers, buttons that name a product object, relative-week labels, feature names | Title Case. Tool screens ("Add to Your Week", "Create Recap", "Edit Profile", "New Album"); settings rows (31 of 31 multi-word); single-word section headers; product-object buttons ("Send Postcard", "Create Album", "Join Album", "Share Recap", "Add Friend"); "This Week", "Last Week", "Two Weeks Ago". | "Notification Settings" · "Lock My Friend Requests" · "Change Phone Number" (RP §4.1) · "Album Members" (`journal_members_sheet_title`) · "Delete Album" · "Leave Album" (`journal_settings_title_*`) · "Last Week" (JED) · "Share Profile" (ST-02) | "Key Holders" / "Manage Key Holders" (gate). |
| `retro.voice.button` | every button and capsule label | 1–3 words, verb first, Sentence case (Title Case only for a named product object — see `retro.voice.title-case`); no terminal punctuation (148 of 150); no emoji. Confirmation buttons in dialogs restate the action ("Yes, delete", "Yes, go back"). | "Get started" (LAND) · "Get this week started" (H43, iOS only) · "Add a memory" (`nux_card_cta_what_to_share`) · "Create a chat" (`message_inbox_empty_state_cta`) · "Add to album" (`journal_profile_empty_state_cta`) · "Try it for free" (TC-R3) · "Yes, delete" (`rewind_home_delete_confirmation_cta`) · "Send again" (`onboarding_form_input_*`) | "Like ❤️"; "Unlock for 24 hours". |
| `retro.voice.title` | screen, sheet and card titles | A short noun phrase (Title Case for tools, `retro.voice.title-case`) or a conversational Sentence-case statement / question; no terminal period; "?" for questions; "!" only for greetings. | "Postcard" · "Create Recap" (TC-R3, TC-REC) · "Every week is precious" (`onboarding_v3_page_title_reminders`) · "Retro is better with friends" (`onboarding_v3_page_title_friend_picker`) · "Welcome to Week %1$d!" (`home_empty_state_title_template`) · "Next Steps" (`media_viewer_report_dont_like_title`) | — |
| `retro.voice.placeholder` | text-field hints | Sentence-case instruction or the field's noun; ends with "…" (ellipsis character) when it invites free text; a bare noun for search ("Search"). | "Add a comment…" (`media_viewer_comment_box_placeholder`) · "Add a caption…" (`media_viewer_comment_box_caption_placeholder`) · "Send a private message reply…" (`media_viewer_reply_to_author_placeholder`) · "Name your album" (`journal_creation_name_placeholder`) · "Enter your phone number…" (`onboarding_form_input_hint_*`) · "Search" (ED-W3) | — |
| `retro.voice.progress` | in-progress / busy lines | Gerund + "…" (ellipsis character; 33 strings). | "Updating…" (`add_journal_media_to_week_success_message`) · "Downloading…" (`journal_settings_download_all_success_message`) · "Creating your collage…" (RP §4.1) · "Opening Retro..." (web, three periods — web only) | — |
| `retro.voice.confirmation` | success toasts and inline confirmations | Very short past-tense or state line; "!" on most success toasts; plain statement for neutral states. | "Saved!" (`edit_address_success_message`) · "Copied!" (`media_viewer_comment_copy_success_message`) · "Submitted!" (`profile_report_submit_success`) · "Message sent!" (`media_viewer_reply_to_author_success_message`) · "Invite link copied to clipboard" (`invites_copy_link_success_message`) · "Deleted" (`rewind_home_delete_media_success`) · "Phone number changed" (`change_phone_number_success_message`) | "Like sent!" (likes). |
| `retro.voice.empty-state` | empty states | Title: a Sentence-case statement or invitation (a greeting may take "!"); optional one-sentence explanation with a period; one action (`retro.voice.button`). | "Nothing to see here yet" (`activity_tab_empty_message`) · "Let's get started" / "Add some photos or videos to your album!" / "Add to album" (`journal_profile_empty_state_*`) · "Your chats will show up here." / "Create a chat" (`message_inbox_empty_state_*`) · "Welcome to Week 43!" / "Get this week started" (H43) · "No postcards sent" / "Postcards that you send to yourself or a friend will appear here" (`postcard_orders_empty_state_*`) | Count-based progress toward an unlock. |
| `retro.voice.error` | errors, offline, not-found, failed sends | Title: "Something went wrong", or a Title-Case name of the error ("Code Expired"); message: one or two sentences — what happened, then what to do ("…try again."); list / widget errors are one tappable line ("… Tap to retry"); never "!"; no blame. | "Something went wrong" (`error_message_dialog_default_title`) · "There was a problem. Please try again." (`error_message_generic`) · "Code Expired" / "That code has expired. Send a new code and try again." (`error_message_expired_auth_code*`) · "We couldn't verify the code. Check your connection and try again." (`error_message_auth_code_service`) · "Error loading friends. Tap here to try again." (`friends_tab_loading_error`) · "Couldn't send comment" / "Try Again" (`media_viewer_comment_send_failed_*`) · "Couldn't find album" (`journal_profile_by_slug_does_not_exist_message`) · "This link is invalid, expired, or revoked. Contact the sender for a new link." (web `/downloads`) | — |
| `retro.voice.confirm` | confirmation dialogs (content; the dialog is native) | Title: the action as a question naming its object ("Unfriend %1$s?", "Block %1$s?", "Delete address?"); message: the consequence in one line ("They will not be notified"); confirm button restates the action ("Yes, delete"). Retro also titles some dialogs "Are you sure?" — HIG rejects that title (`platform.alertTitle`), so use the action-question form. | "Unfriend %1$s?" / "They will not be notified" (`user_profile_confirm_unfriend_*`) · "Block %1$s?" / "Blocking %1$s will remove them as a friend and prevent them from interacting with you." (`user_profile_confirm_block_*`) · "Any media you selected will not be added" / "Yes, go back" (`composer_lost_changes_warning_*`) · "This will permanently delete this %1$s from your camera roll" (`rewind_home_delete_confirmation_message`) | "Are you sure?" as a title; "WARNING:" capitals. |
| `retro.voice.prompt` | invitations to share (cards, reminders, empty weeks) | A question about a moment, second person, ends with "?"; an invitation, never an obligation. | "Anything from today you want to remember?" (`post_reminder_notification_message`) · "Caught up with a friend?" · "Did something nice for yourself?" · "Ate something tasty?" · "Anything else you want to remember?" (`nux_card_title_what_to_share_0..7`) | Deadlines, "you haven't posted". |
| `retro.voice.coach` | first-use tips (NUX) | Short imperative, Sentence case, no period. | "Tap to advance" (`viewer_nux_tap_forward`) · "Tap left to go back" (`viewer_nux_tap_back`) · "Document the moments that are important to you" (`…first_week_1`) | — |
| `retro.voice.settings` | settings rows and their descriptions | Row label Title Case (`retro.voice.title-case`); description one Sentence-case sentence ending with a period; section header one or two Title-Case words. | "Lock My Friend Requests" / "Others will not be able to send you friend requests." · "Neighborhood Captions" / "Show the neighborhood or city on photos you post with locations." · "Pause All" / "Turn off all notifications for the day" (RP §4.2) · "Account" · "Privacy" · "System Permissions" (`settings_section_header_*`) | "Weeks posted" stats. |
| `retro.voice.explanation` (kept id) | one-line explanations, sheet bodies, descriptions | Sentence case with a final period. | "Retro is a social photo journal for moments big and small. Add to any week, any time." (`onboarding_v3_page_subtitle_education`) · "Life moves fast — how often do you want to get reminders to document your journey?" (`onboarding_v3_page_subtitle_reminders`) · "Retro is a weekly photo album. Try adding photos to 3 different weeks below." (Engadget 2026, retro-timehop) | The 4-week gate explanation. |
| `retro.voice.menu-labels` (kept id) | context menus and action sheets (item text) | Sentence case, verb first, no period; destructive items in red (layout per `platform.menuItem`). | "Share to my week" · "Add to Album" · "Hide photo" · "Delete from Photos" (Rewind menu, TC-RWP) · "Download all photos" (`journal_settings_title_download_all`) · "Copy Link" (`invites_option_copy_link`) | — |
| `retro.voice.terse-numbers` (kept id) | week titles, tile labels, short numeric labels | Digits; "Week %1$d" with a capital W; 3-letter weekday on tiles ("Mon", "Tue"); no emoji; ISO weeks (Monday start). | "Week 27" (ST-01/02) · "Week %1$d" (`header_title_week_number_template`) · "Mon", "Tue", "Wed" (tiles) · "%1$d of %2$d" (`media_viewer_progress_badge_template`) | "%1$d new"; "Seen"; "Weeks Posted: N". |
| `retro.voice.formats` | dates, ranges, times, separators | Range by the locale formatter: month once inside a month ("Jul 3 - 9", store; "Apr 29 – May 5", JED); dated headers "January 25, 2024"; Rewind date "May 1, 2019"; relative times "1d", "2h"; meta separator " · "; relative weeks in words ("Two Weeks Ago"); durations "1:00". | "Jul 3 - 9" (ST-02) · "January 25, 2024" (TC-J1) · "May 1, 2019" (RWA) · "elton 2h" (TC-2B) · "Muted · Seen" (RP §4.1) · "Two Weeks Ago" (`weeks_ago_*`) · "Photos taken since %1$s" (`composer_header_template_current_week`) | — |
| `retro.voice.punctuation` | all strings | "!" only for greetings, celebrations and success toasts (42 strings), never in errors; "?" for prompts and confirmations; "…" (one character) for progress and open placeholders; " · " for meta; em dash for asides; no terminal punctuation on titles, buttons, labels; explanations end with a period. Apostrophes are mixed in Retro (54 straight, 32 curly): new strings use the straight apostrophe (the majority). | "Welcome to Retro Premium — forever." (RP §4.1) · "Saved!" · "Are you sure?" · "Updating…" | — |
| `retro.voice.emoji` | all strings | No emoji in product UI (4 exceptions in Retro, all likes or system lines — not copied). | "Welcome to Week %1$d!" · "Never miss a message" · "Saved!" (none carry emoji) | "❤️ your post", "Like ❤️", "✌️%1$s left the thread". |

### Retro voice — feature families

| id | governs | rules | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `retro.voice.onboarding` | sign-up, landing, onboarding pages | Landing: a short Title-Case tagline and one primary button; pages: conversational Sentence-case headline + one explanation sentence; a greeting may use the person's name and "!". Order from the APK: phone → code → username → full name, then splash, education, reminders, notifications, profile photo, friends, invite link. | "Friends Only" (LAND) · "already have an account?" (LAND, lower case link) · "By continuing, I confirm that I am %1$d or older and agree to the Terms and Privacy policy." (RP §6.3) · "Hi %1$s, let's get your Retro set up." (`onboarding_v3_splash_screen_title_template`) · "Your code may take up to 30 seconds to arrive" (`onboarding_form_input_*`) · "Let your friends know it's you by setting a profile photo!" (`onboarding_v3_profile_photo_skip_attempt_message`) · "A private space for your friends. One scan away." (`onboarding_v3_page_title_share_invite_link`) | "No Ads. Ever." as a promise we have not made (owner). |
| `retro.voice.permission` | in-app permission pre-prompts (`onboarding.permission.*`, permission-denied states) | Title: Title Case naming the access ("Allow Access to Photos", "Camera Roll Access") or a benefit in Sentence case ("Never miss a message"); one or two sentences: what it is used for + a reassurance; button: Title-Case verb naming the access ("Give Permission", "Allow Photo Access", "Connect Contacts"). Then the system prompt (`platform.purposeString`). | "Allow Access to Photos" / "Retro needs permission to access your photo library so you can select and post photos." / "Give Permission" (`composer_permission_upsell_*`) · "No Contacts Access" / "Connect your phone contacts to find friends to invite here. We will never spam your contacts." / "Connect Contacts" (`contact_permission_upsell_*`) · "Never miss a message" / "Do you want to get notifications for direct messages, friend requests, and other activity?" (`onboarding_notification_permission_retry_*`) | Asking again in a loop; pre-prompts that imitate the system alert. |
| `retro.voice.push` | push and local notifications (`notifications.push`, `daily.notification`) | Title: the context ("Week %1$d", "On This Week") or the sender; body: one line — a `retro.voice.prompt` question for invitations, a plain statement with a period for activity ("%1$s just posted."), a quoted comment after a colon. One notification per event. | "Week %1$d" / "Anything from today you want to remember?" (`post_reminder_notification_*`) · "Week %1$d is almost over" / "Anything you want to look back on?" (Sunday variant) · "On This Week" / "Relive your memories from this week over the years." (`on_this_week_notification_*`) · "%1$s just posted." · "%1$s commented on your post: "Wow this looks yummy!"" · "%1$s just joined Retro." (`notification_settings_description_*`) | "Relive %1$d memories …" (count); "Finish setting up your Retro!" nudges; "%1$s says you're friends, that true?"; reminder chains. |
| `retro.voice.push-channel` | Android notification channels | Name: 1–3 words, Title Case; description: one Sentence-case line (a period only when it is a full sentence). Limits: name ≤ 40, description ≤ 300 characters (platform). | "New Posts" / "Recent posts from users you care about" · "Friend Activity" · "Messages" / "Real-time messages from other users" · "Upload Progress" / "See progress when Retro is uploading media in the background" (`notification_channel_display_*`) | "Media activity, such as comments and likes." (likes). |
| `retro.voice.widget` | widget gallery names and descriptions, widget states, widget configuration | Gallery name Title Case ("Friend Updates"); description a short Sentence-case line starting with a verb (also `platform.widgetDescription`); states: a short line + the action ("No media. Tap to reload"); configuration titles end with "…" when they lead to a choice. | "Friend Updates" / "See live updates from your friends" · "Your Memories" / "See memories from your profile" · "Albums" / "See memories from your album" (RP §4.2) · "No media. Tap to reload" (`app_widget_empty_message`) · "Error loading media. Tap to retry" (`app_widget_error_message`) · "Log in to see your content" (`app_widget_not_logged_in_message`) · "Refreshing" (`app_widget_refreshing_toast`) · "See photos from…" (`app_widget_config_screen_title_friend_picker`) · "New! Widgets for your home screen" / "Try out widgets" (RP §4.2) | "Post to see" (`app_widget_post_locked_message`). |
| `retro.voice.share` | share texts, share-image footers, link previews | Share message: "Check out my {thing} on {app_name}!" + newline + link; OG / preview: short Title-Case or Sentence-case line; the share image carries the year in the serif, the name and the domain. | "Check out my %1$s on Retro!\n%2$s" (`recap_composer_share_export_template`) · "Share your Retro link" (RP §4.2) · "Add me on Retro" / "Photos with friends." (web OG) · "2023 / nathan / retro.app" (TC-H) | — |
| `retro.voice.web-invite` | invite web page and App Clip card (`invite.web`, `invite.appclip`) | Headline names the inviter with "!" ("{name} Invited You!", Title Case); one Sentence-case line with a period on what you'll see; one short button ("Let's go"); busy state "Opening {app_name}..."; shared-album lines name the sharer ("{name} shared with you"); mobile footer explains the app is needed. | "Nathan Invited You!" · "See what Nathan is up to this week on Retro." · "Let's go" · "Opening Retro..." · "Ryan shared with you" · "You're invited to view the journal." · "Download the app to read and leave comments" (web, RP §7) | "7 members • 24 photos" counts only if the surface spec allows counts of members (no social counts). |
| `retro.voice.paywall` | paywall and premium welcome | Two-part product title; benefit titles Title Case + one Sentence-case line; plan names with a dash and a short description; CTA "Try %1$s free" / "Continue"; footer "Cancel anytime", "Restore purchase"; welcome with "!" or a line break. At most one prompt per session (tenet). | "Unlimited Profile History — Add photos from any time in your life. No matter how far back." · "Annual — Best value for long-term use" · "Try %1$s free" · "Cancel anytime" · "Restore purchase" · "Welcome to\nRetro Premium" · "Thanks for supporting ad-free social" (RP §4.2) · "Cancel anytime. No questions asked." (PAY) | "Join thousands of subscribers" rating bar; referral rewards; "Popular" / "Flexible" pressure badges if they read as pressure (owner). |
| `retro.voice.rewind` | on-this-day (`onthisday`) | Subtitle "On this week" (Sentence case); card title "This week in {year}"; feature name "Rewind"-style Title Case for our own name; empty and permission lines per `retro.voice.empty-state` / `retro.voice.permission`. | "On this week" (TC-RWP) · "This week in %1$s" (`home_feed_card_on_this_week_title_template`) · "Revisit memories from Week %1$s over the years" / "View memories" (`home_rewind_upsell_feed_card_*`) · "No media found on your camera roll" (`rewind_home_empty_state_message`) · "Try it out" (`rewind_home_nux_cta`) | "N YEARS AGO" banners (Timehop). |
| `retro.voice.retrospective` | year story and recaps (`year.story`, `week.recap`, `collage.*`) | Title-Case feature names ("Year in Photos", "Create Recap"); page headlines are second-person Sentence-case statements, sometimes with an em-dash aside; closing line "Here's to another year in the books". | "Year in Photos" (`retrospective_page_title_splash`) · "Let's look back at your 52 weeks" (`retrospective_page_title_look_back`) · "This is where you spent most of your time" (`…most_popular_places`) · "You made the most memories with %1$s" (`…most_tagged_friend`) · "Here's to another year in the books" (`…recap_promo`) · "Create something beautiful to look back on" / "Life Lately" (RP §6.3) · "When you fill in your weeks on Retro, you'll see recaps here." (`recap_time_selector_empty_message`) | "%1$s was your biggest fan", "the ones your friends loved the most" (popularity from likes); "You took %1$s photos this year" (count). |

### Apple HIG / Material 3 (system components) — kept

| id | governs | rules | verbatim examples (source) | do-not-copy |
|---|---|---|---|---|
| `platform.purposeString` | `system.permissions` (Info.plist purpose strings) | One brief, complete sentence; active voice; Sentence case; ends with a period; names the specific feature; separate string per resource. | "The app records during the night to detect snoring sounds." (HIG Privacy) · "The app uses location data to determine the recommended route to your destination and provide turn-by-turn directions." (App Review 5.1.1(ii)) · Retro's in-app equivalent: "Retro needs permission to access your photo library so you can select and post photos." (`composer_permission_upsell_message`) | Restating the resource without its use. |
| `platform.alertTitle` | alert / dialog titles | A complete sentence → Sentence case with ending punctuation; a fragment → Title Case, no punctuation; one or two lines. With Retro content: `retro.voice.confirm`. | HIG Alerts §Content; "Unfriend %1$s?" (`user_profile_confirm_unfriend_title_template`) | "Are you sure?", "Warning!", apologies. |
| `platform.alertMessage` | alert / dialog messages | Only if it adds value; complete sentences, Sentence case, punctuation. | "They will not be notified" (Retro omits the period on this one-clause message, `user_profile_confirm_unfriend_message`) | — |
| `platform.alertButton` | alert, dialog and system action buttons | One- or two-word verb describing the result; "Cancel" for cancel; "OK" only for informational alerts. Retro's confirm buttons may restate with "Yes, …" (`retro.voice.confirm`). | "Delete" · "Cancel" (HIG Alerts) · "Yes, delete" (`rewind_home_delete_confirmation_cta`) | — |
| `platform.menuItem` | layout of menus and action sheets | Destructive items in red, at the top of action sheets with Cancel at the bottom; an ellipsis when the action needs more input. Item **text** follows `retro.voice.menu-labels` (Sentence case — Retro's own menus). | "Report…" (HIG Menus) · "Share to my week" (TC-RWP) | — |
| `platform.widgetDescription` | widget gallery descriptions | Begins with an action verb; no "This widget shows…"; Sentence-style capitalization. | "See live updates from your friends" (Retro, RP §4.2) | — |
| `platform.appClipCard` | App Clip card (`invite.appclip`) | Title ≤ 30 characters, subtitle ≤ 56 characters, one of Apple's preset action verbs; no text in the card image. | Retro links its `/u/` page to an App Clip card (`io.lonepalm.Retro.Clip`, RP §7) — card text not captured | Asking to install repeatedly. |
| `platform.a11yLabel` (new id) | VoiceOver / TalkBack labels of icon-only and image elements | Label the purpose, not the visual; no "button" suffix (the trait says it); Title-style for controls named like buttons, Sentence case for descriptions; images of people are labelled with the person and context; an emoji used as an illustration is named by its Unicode CLDR short name. | "View Terms" · "View Privacy" (`view_terms_link_content_description`, `view_privacy_link_content_description`) · design/research/platform.md §Accessibility (rules) | — |

### Mechanics content patterns — kept (no Retro analog)

Content rules only; case and punctuation follow the Retro patterns above.

| id | governs | rule kept | example | change from before |
|---|---|---|---|---|
| `bereal.format.countdown` | countdown text (`daily.capture`, `daily.liveactivity`, `daily.ongoing`) | `MM:SS`, both fields zero-padded; no label text; never a "late" state. | "01:31", "00:59" (BeReal) | none |
| `locket.onboarding.widgetSteps` | `onboarding.widget` | Numbered imperative steps that name the system UI ("Edit", "Add Widget", "Widgets"); a closing line. | "Tap Edit in the upper-left corner." / "Tap Add Widget." (Locket help) | Title / closing line in Retro voice ("New! Widgets for your home screen", "Try out widgets" — `retro.voice.widget`) |
| `messaging.reaction` | reaction activity and push | "{name} reacted {emoji} to your photo" — who reacted and with which emoji, inline; no count, no period. | "a message, photo, gif, or video you reacted to" (WhatsApp help, faq.whatsapp.com/424198503229937); "Senders and their tapbacks appear near the top of the screen" (Apple iPhone User Guide, React with Tapbacks) | noun "photo" (Retro says "post": "%1$s commented on your post"); replaces `messaging.reaction`, whose example came from Locket's decompiled app (owner decision 22) |
| `P-BR-1` invitation | `birthday.request` | "You're invited to {action} for {name}." + a bar-lowering line. | "Hey — I'm organizing a birthday video for [Name]'s birthday on [date]. Would love a short clip from you." (Tribute) | Retro tone (`retro.voice.second-person`, "no pressure") |
| `P-BR-2` prompt | `birthday.request` | Open question about the person, with the name. | "What do you appreciate most about Harper?" (VidDay) | — |
| `P-BR-3` due line | `birthday.request` | A date, never a countdown. | "Submit by Wednesday, December 31, 2025" (Tribute) | date format per `retro.voice.formats` |
| `P-BC-1` step greeting | `birthday.contribute` | "Let's {verb} a {noun} for {name}!" | "Let's record a video for Tribute!" | — |
| `P-BC-2` completion | `birthday.contribute` | "{Noun} Upload Complete!" → in Retro voice a success toast (`retro.voice.confirmation`, e.g. "Added!"-style) | "Video Upload Complete!" (Tribute) | toast form |
| `P-BT-1` title card | `birthday.tribute` | "Happy birthday, {name}!" | "Happy Birthday to Doug!" (Tribute) | Sentence case |

### Retired patterns (successor ids)

Existing copy entries that name a retired id keep resolving through this table until Pass 2 rewrites them.

| retired id | successor |
|---|---|
| `yope.voice.lowercase` | `retro.voice.sentence-case` (and `retro.voice.title-case` where Retro capitalises) |
| `yope.voice.second-person`, `locket.voice.second-person` | `retro.voice.second-person` |
| `yope.voice.button`, `bereal.voice.capture-labels`, `P-BC-3` | `retro.voice.button` |
| `yope.voice.title` | `retro.voice.title` |
| `yope.voice.placeholder`, `locket.voice.ellipsis` (placeholders) | `retro.voice.placeholder` |
| `locket.voice.ellipsis` (progress) | `retro.voice.progress` |
| `yope.voice.coach` | `retro.voice.coach` |
| `yope.voice.confirmation`, `locket.voice.exclamation` | `retro.voice.confirmation` (in-app), `retro.voice.push` (notifications) |
| `yope.voice.empty-state`, `locket.widget.empty` | `retro.voice.empty-state`, `retro.voice.widget` (widgets) |
| `yope.voice.permission` | `retro.voice.permission` |
| `yope.voice.error` | `retro.voice.error` |
| `yope.voice.emoji`, `timehop.voice.no-emoji` | `retro.voice.emoji` |
| `yope.voice.punctuation` | `retro.voice.punctuation` |
| `yope.voice.formats`, `timehop.voice.years-ago` | `retro.voice.formats` |
| `yope.voice.release-notes`, `yope.voice.support`, `timehop.voice.playful`, `timehop.voice.release-notes` | none (not product UI) |
| `locket.voice.sentence-case` | `retro.voice.sentence-case` |
| `locket.voice.title-case-names`, `timehop.voice.title-case-names`, `partiful.voice.labels` | `retro.voice.title-case` |
| `locket.widget.gallery` | `retro.voice.widget` + `platform.widgetDescription` |
| `locket.push.newPost`, `bereal.voice.push` | `retro.voice.push` |
| `locket.push.channel` | `retro.voice.push-channel` |
| `bereal.voice.capture-prompt` | `retro.voice.prompt` |
| `timehop.voice.uppercase-labels` | `retro.voice.rewind` (no uppercase banners) |
| `P-YS-1` … `P-YS-5` | `retro.voice.retrospective` (Wrapped keeps only the pacing, a mechanic) |
| `P-IW-1` … `P-IW-8`, `P-IW-T`, `P-IW-A` | `retro.voice.web-invite`; not-found / link status → `retro.voice.error`; image alt → `platform.a11yLabel` |
| `P-IW-A2` | `platform.a11yLabel` |

## Which pattern governs which surface

Rule: Retro's app-wide set (`retro.voice.second-person`, `.sentence-case`, `.title-case`, `.button`, `.title`,
`.placeholder`, `.progress`, `.confirmation`, `.empty-state`, `.error`, `.confirm`, `.coach`, `.punctuation`,
`.emoji`, `.formats`, `.terse-numbers`) applies to **every app surface** ("Retro set" below); the families add to it.
Loading · empty · error · offline · permission-denied states use `retro.voice.progress` / `.empty-state` /
`.error` / `.permission`.

| surface | patterns |
|---|---|
| `global` | Retro set |
| `global.system` | `platform.alertTitle`, `platform.alertMessage`, `platform.alertButton`, `platform.menuItem` (layout) + `retro.voice.menu-labels` (text), `retro.voice.confirm`, `platform.a11yLabel` |
| `invite.web`, `invite.appclip` | `retro.voice.web-invite`, `retro.voice.share`, `retro.voice.error`; App Clip card `platform.appClipCard` |
| `auth.phone`, `auth.code`, `auth.agegate`, `auth.profile` | Retro set + `retro.voice.onboarding`, `retro.voice.placeholder`, `retro.voice.error` |
| `onboarding.permission.camera`, `.notifications`, `.photos`, `.contacts` | `retro.voice.permission`, `retro.voice.button`; then the system prompt `platform.purposeString` |
| `onboarding.widget` | `retro.voice.widget` (title, closing), `locket.onboarding.widgetSteps` (steps content) |
| `groups.list`, `groups.create`, `groups.invite`, `groups.screen` | Retro set (`retro.voice.title-case` for tool titles: "New Album" → our group noun), `retro.voice.share` (invite link) |
| `groups.settings` | `retro.voice.settings`, `retro.voice.confirm`, `retro.voice.menu-labels`; native dialogs `platform.alert*` |
| `question.weekly` | Retro set + `retro.voice.prompt` (the questions), `retro.voice.settings` (group switch), `platform.menuItem` (Remove); never a tally |
| `plans.create`, `plans.page` | Retro set (`retro.voice.title-case` for tool titles: "New Album" → "New Plan"), `retro.voice.confirm` (discard / cancel), `retro.voice.menu-labels`; answers Going · Maybe · Can't go (Partiful content); never a count |
| `camera.capture`, `camera.sendto`, `camera.fromwidget` | Retro set (`retro.voice.placeholder` for the caption: "Add a caption…") |
| `camera.overnight` | Retro set + `retro.voice.explanation`, `retro.voice.settings` (alert switch), `retro.voice.push-channel`; times and relative days from the platform formatters |
| `widget.home.*`, `widget.lock.*`, `widget.arrival`, `widget.android` | `retro.voice.widget`, `platform.widgetDescription`, `retro.voice.push-channel` (Android refresh channel) |
| `widget.countdown` | `retro.voice.widget`, `platform.widgetDescription`; the day count is the platform relative formatter's output (PLATFORM), never typed |
| `chat.thread`, `chat.composer`, `chat.voice` | Retro set (`retro.voice.placeholder`: "Send a private message reply…"-style) |
| `chat.reactions` | Retro set + `messaging.reaction` (content); never a count |
| `photo.viewer` | Retro set + `retro.voice.coach` (viewer tips), `retro.voice.menu-labels`, `retro.voice.terse-numbers` (position) |
| `viewer.selfiereaction` | Retro set + `retro.voice.coach` (hints), `retro.voice.menu-labels`, `messaging.reaction` (rows); never a count |
| `walls.mine`, `walls.member`, `walls.browse` | Retro set (`retro.voice.title-case` for "Share Profile"-style pills) |
| `daily.notification` | `retro.voice.push` + `retro.voice.prompt` (tenet-5 adaptation below) |
| `daily.capture`, `daily.liveactivity`, `daily.ongoing`, `daily.dualimage` | Retro set + `bereal.format.countdown`; `retro.voice.push-channel` (ongoing) |
| `collage.view`, `collage.share` | Retro set + `retro.voice.share`, `retro.voice.retrospective` |
| `week.recap`, `week.edit`, `week.history` | Retro set + `retro.voice.retrospective` (recaps), `retro.voice.formats`, `retro.voice.terse-numbers`, `retro.voice.menu-labels` |
| `albums.list`, `albums.view` | Retro set |
| `onthisday` | `retro.voice.rewind` + Retro set |
| `birthday.add` | Retro set + `retro.voice.onboarding` |
| `birthday.request`, `birthday.contribute`, `birthday.tribute` | Retro set + `P-BR-1`…`P-BR-3`, `P-BC-1`, `P-BC-2`, `P-BT-1` (content) |
| `year.story` | `retro.voice.retrospective` + Retro set |
| `tagging` | Retro set |
| `settings.root`, `settings.notifications`, `settings.account`, `settings.blocked` | `retro.voice.settings`, `retro.voice.confirm`, `platform.alert*`, `retro.voice.push-channel` (Android channels) |
| `paywall` | `retro.voice.paywall` + Retro set; required links "Restore Purchases" / "Terms of Use" / "Privacy Policy" per `platform.alertButton` |
| `safety.report`, `safety.block` | `retro.voice.confirm` ("Block {name}?"), `retro.voice.menu-labels`, Retro report flow ("Why are you reporting this post?", "Other", "Submitted!" — `media_viewer_report_reason_*`, `profile_report_*`) |
| `system.permissions` | `platform.purposeString` |
| `notifications.push` | `retro.voice.push`; reactions and selfie reactions `messaging.reaction` (content); birthday request `P-BR-1`; tribute `P-BT-1`; plans `retro.voice.push` (sender, verb, colon, content); Android channels `retro.voice.push-channel` |

## Adaptation rules

**Allowed changes to a reference string** (`origin: adapted`, CONVENTIONS §4): only nouns are swapped,
and the swap is written in the string's `notes`.

| reference noun | becomes |
|---|---|
| "Retro" (the app) | `{app_name}` |
| "Retro Premium" | the premium product name from the paywall copy (owner, `config/app.json`) |
| Retro's "album" / "journal" (a shared collection) | the group noun of our product |
| Retro's "friends" (people whose weeks you see) | the group's members, or "friends" where the group type is friends |
| "Rewind", "Recaps", "Postcard", "Key Holders" (Retro feature names) | our own feature names (`{app_name}`'s), never Retro's |
| "Locket", "BeReal", "Tribute", "VidDay", "Wrapped", "Partiful", "Timehop", "Yope" | `{app_name}` or a generic noun |

**`{app_name}`**: the app's display name, from `config/app.json` `displayName` (owner decision; BLOCKED until set —
`tools/designgen.mjs` keeps every string containing it in debug-only output). Another company's name, logo,
trademark or mascot never appears in a string.

**Tenet filters** (CONVENTIONS §6) applied before any pattern:

- **No counts**: no likes, reactions, views, "%1$d new", "N posts", "Weeks Posted: N", "Relive %1$d memories",
  "You took %1$s photos this year", "N friends joined", guest or subscriber counts, retake counts.
- **No popularity or performance**: no "biggest fan", "the ones your friends loved the most", top-friend rankings
  based on likes.
- **No streaks**, no 🔥N, no streak chips.
- **No guilt or gates**: no "Post to see", "No Lurking", "Post each week to unlock photos from friends.", "Key
  holders only", "Expires in N days" urgency, "you haven't posted".
- **No nagging**: one message per event; no "Finish setting up …!" nudges; no reminder chains; at most one paywall
  prompt per session.
- **No fake urgency**: no ⚠️, no `TIME SENSITIVE`, no "{n} min left", no "late" labels, no countdown to a deadline
  (dates instead).

**Daily invitation (tenet 5)**: Retro's post reminder is the model — title "Week {number}", body a
`retro.voice.prompt` question ("Anything from today you want to remember?"); one alert at the start of the window
(platform §daily.liveactivity: "Use one alert, at start"); no time-sensitive level, no deadline, no brand verb.
