# Platform research: Apple HIG and Material 3 (and platform docs)

Research pass: platform conventions for the surfaces assigned to Apple HIG / Material 3 in
`docs/SURFACES.md`, plus cross-cutting accessibility, haptics, widget, Live Activity and share
values. Fetched on 2026-10-15 (iOS 26 / Android 16 era). Machine-readable output:
`design/proposals/platform.tokens.json` (226 tokens), `design/proposals/platform.copy.json`
(18 strings). Platform constraints that are not design values (refresh budgets, push, App Clip
size, store policy) are in `docs/PLATFORM_CONSTRAINTS.md`.

## How the values were obtained

- **Apple HIG and Apple developer docs**: the DocC JSON behind each page
  (`https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json`,
  `https://developer.apple.com/tutorials/data/documentation/<path>.json`) was converted to text and the
  tables were read directly. HIG pages carry a change-log date. The pages with tables were also
  screenshotted (`references/auto/platform/`).
- **Material 3**: m3.material.io renders its token tables from JSON snapshots. The snapshot dated
  `2026-10-13_06-10-19` was downloaded and each token was resolved through its references
  (for example `md.comp.dialog.headline.size` → `md.sys.typescale.headline-small.size` → 24). The
  type scale has two contexts in the data. The public page shows the **"3p" (third-party)
  audience** values, which are the ones used here. Without that context, the data returns Google's
  first-party tracking (0 / 0.1). The resolved values were checked against the rendered page text.
- **Android / Firebase / Google Play**: server-rendered HTML. Each page's "Last updated" date is noted.
- Levels: a number or rule quoted from Apple/Google documentation is **VERIFIED**. Naming a native component
  or API that supplies the look is **PLATFORM**.
- `source_app` uses "Apple HIG" for Apple docs and "Material 3" for Google/Android docs. The 5 Meta
  tokens and 1 W3C token use their real source names, which are outside the CONVENTIONS enum. They are
  flagged for the merge.
- Cross-surface tokens (type scale, touch targets, contrast, reduce motion, dialogs) use
  `"surface": "all"`. `docs/SURFACES.md` has no global id, so the merge step needs to accept this
  value or map it to an id.

### Document dates (staleness check)

| Source | Last change shown on the page |
|---|---|
| HIG Widgets / Live Activities | 2026-10-13 |
| HIG Layout | 2026-09-09 |
| HIG Apple In-App Purchase | 2026-09-17 |
| HIG Menus | 2026-06-08 |
| HIG Sheets | 2026-03-24 |
| HIG Typography, Color, Buttons | 2025-12-16 |
| HIG Motion | 2025-09-09 |
| HIG Accessibility, App Clips | 2025-06-09 |
| HIG VoiceOver | 2025-03-07 |
| HIG Playing haptics | 2024-05-07 |
| HIG Settings, Onboarding | 2024-06-10 |
| HIG Alerts | 2024-02-02 |
| HIG Notifications | 2023-10-24 |
| HIG Privacy, Lists and tables | 2023-06-21 |
| HIG Action sheets, Activity views, Managing accounts | no change-log date in page metadata |
| App Review Guidelines | "Last Updated: June 8, 2026" |
| M3 token snapshot | 2026-10-13 (DSDB revision 2026-05-27) |
| Android docs | 2026-03-03 … 2026-10-13 (per row below) |

---

## settings.root · settings.notifications · settings.account · settings.blocked

**References:** HIG Lists and tables (https://developer.apple.com/design/human-interface-guidelines/lists-and-tables),
HIG Settings (…/settings), HIG Alerts (…/alerts), HIG Managing accounts (…/managing-accounts),
SwiftUI `InsetGroupedListStyle`, `Section`, `ButtonRole.destructive`; M3 Lists specs
(https://m3.material.io/components/lists/specs), M3 Dialogs specs + guidelines.

**Layout (iOS).** A `List` with `.listStyle(.insetGrouped)`. Each group is a `Section` with a header and an
optional footer. The HIG says the grouped style "uses headers, footers, and additional space to separate
groups of data". Rows that drill into a sub-screen use the disclosure indicator. The HIG says
"Use an info button only to reveal more information about a row's content", so info buttons are not for
navigation. Colors are system semantic colors: `systemGroupedBackground` for the page and
`secondarySystemGroupedBackground` for cells. The HIG Settings page says to keep settings to "general,
infrequently changed settings" and to "Respect people's systemwide settings and avoid including redundant
versions of them". This means no in-app Dynamic Type or dark-mode switches.

**Layout (Android).** A Compose M3 `ListItem` column. A row is 56 / 72 / 88 dp tall for 1 / 2 / 3 lines,
with 16 dp leading and trailing space, 10 dp top and bottom, and 12 dp between slots. Leading icons are
24 dp and avatars are 40 dp (blocked people). Dividers are 1 dp in `outline`. The label uses bodyLarge,
supporting text uses bodyMedium, and trailing text uses labelSmall. M3 now also offers an "expressive"
**segmented** list style ("An expressive list has a segmented style and round corners"): items sit 2 dp
apart in a container with a 16 dp corner. This is the closest M3 match to iOS inset-grouped.

**Delete account (settings.account).**
- Apple 5.1.1(v): apps "must also offer account deletion within the app". Apple's FAQ adds that the deletion
  option must be "easy to find", that deactivation alone "is insufficient", and that deletion includes
  "user-generated content that's shared with others, such as photos". Re-authentication or a code step
  is allowed (https://developer.apple.com/support/offering-account-deletion-in-your-app/).
- HIG Managing accounts: "Tell people when account deletion will complete". Explain that subscription
  billing "continues through Apple until people cancel".
- Confirmation on iOS is an alert, because this is an "uncommon destructive action that they can't undo".
  It has a destructive-role **Delete** button and a **Cancel** button, and Cancel is not the default.
  Up to 3 buttons are allowed. The default action sits on the trailing side, and Cancel sits on the
  leading side or at the bottom.
- On Android it is an M3 basic dialog: corner 28 dp, headline in headlineSmall (24/32), supporting text in
  bodyMedium (14/20), actions in labelLarge (14/20/500), container `surface-container-high`, elevation
  level3 (6 dp). Use at most two actions: "one must be a confirming action, and the other a dismissing
  action". "The confirmation button is always closest to the edge."
- Google Play also requires an in-app deletion path **and** a web link
  (https://support.google.com/googleplay/android-developer/answer/13327111).

**Measured values.** "File" is the documentation URL; "coords" is the section or token.

| value | element | file | coords | method | precision | level |
|---|---|---|---|---|---|---|
| insetGrouped List + Section | iOS settings list | HIG lists-and-tables; SwiftUI InsetGroupedListStyle | §Style | native component | n/a | PLATFORM |
| systemGroupedBackground / secondarySystemGroupedBackground | page / cell bg | developer.apple.com/documentation/uikit/uicolor/systemgroupedbackground | abstract | semantic color | n/a | PLATFORM |
| 56 / 72 / 88 dp | M3 list item heights | m3 lists specs (TOKEN_TABLE.6c818a16475113bd.json) | md.comp.list.list-item.{one,two,three}-line.container.height | token resolve | exact | VERIFIED |
| 16 / 16 / 10 / 10 / 12 dp | leading/trailing/top/bottom/between | same | md.comp.list.list-item.*-space | token resolve | exact | VERIFIED |
| 24 dp / 40 dp | leading icon / avatar | same | leading-icon.size / leading-avatar.size | token resolve | exact | VERIFIED |
| 1 dp, `outline` | divider | same | md.comp.list.divider.* | token resolve | exact | VERIFIED |
| 2 dp gap, 16 dp corner | segmented style | same | md.comp.list.segmented.gap / container.shape | token resolve | exact | VERIFIED |
| bodyLarge / bodyMedium / labelSmall | label / supporting / trailing text | same | label-text / supporting-text / trailing-supporting-text | token resolve | exact | VERIFIED |
| ≤ 3 buttons | iOS alert | HIG alerts | §Content | quote | exact | VERIFIED |
| 28 dp | M3 dialog corner | m3 dialogs specs (TOKEN_TABLE.0b1e39a67d5bafdc.json) | md.comp.dialog.container.shape | token resolve | exact | VERIFIED |
| ≤ 2 actions | M3 dialog | m3 dialogs guidelines | §Buttons | quote | exact | VERIFIED |

**Copy (verbatim platform terms).** "Cancel" ("Always use the title Cancel for a button that cancels an
alert's action"), "Delete" (HIG example of a specific title), "OK" (informational alerts only).
**Voice pattern, platform alerts:**
1. Title: if it is a complete sentence, use sentence case with ending punctuation. If it is a fragment, use
   title case with no punctuation. Keep it to one or two lines. M3 adds "brief, clear statement or
   question" and says to avoid "Are you sure?", "Warning!" and apologies.
2. Message: include one "only if it adds value", in complete sentences.
3. Buttons: a one- or two-word verb in title-style capitalization with no punctuation.
   Examples: "View All", "Reply", "Ignore", "Erase", "Delete".

The proposed strings (`settings.account.delete.*`) follow these rules. The wording of the message is
new and needs owner sign-off because of the tenet conflict below.

**Do-not-copy / tenet conflicts.**
- Apple requires that shared photos be deleted with the account, which conflicts with
  "Nothing gets lost". This is an owner decision, logged in PLATFORM_CONSTRAINTS §9.
- Badges: the HIG says to use a badge "only to show people how many unread notifications" there are. A
  badge count would be a count that tenets may forbid, so no badge is recommended.

**Not found.**
- Row heights for iOS inset-grouped lists. The HIG does not publish them, and the system sizes rows by
  Dynamic Type, so no number is needed.
- An M3 "settings" pattern page. M3 has no dedicated settings component, so the list component is used.

---

## system.permissions

**References:** HIG Privacy (…/privacy, 2023-06-21); App Review guideline-reference "5.1.1(ii) Write clear
purpose strings" (https://developer.apple.com/help/app-review/guideline-reference/5-1-1-purpose-strings/);
App Review Guidelines 5.1.1(ii)/(iv), 5.1.2(v); Info.plist key pages (NSCameraUsageDescription,
NSPhotoLibraryUsageDescription, NSPhotoLibraryAddUsageDescription, NSContactsUsageDescription,
NSMicrophoneUsageDescription); PhotoKit "Delivering an Enhanced Privacy Experience"; Contacts
`CNAuthorizationStatus.limited` and `ContactAccessButton` (iOS 18); UserNotifications "Asking permission to
use notifications"; Android "Request runtime permissions" (2026-10-01), "Notification runtime permission"
(2026-10-01), "Selected Photos Access" (2026-03-03), Photo picker (2026-10-01); Google Play "Restricted
Permissions with minimum scope alternatives" (https://support.google.com/googleplay/android-developer/answer/14115180).

**iOS rules (VERIFIED):**
- **Ask in context.** "Request permission only when your app clearly needs access ... Ideally, wait to request
  permission until people actually use an app feature that requires access." Notifications: "Make the
  request in a context that helps people understand why".
- **Purpose string format.** "Aim for a brief, complete sentence that's straightforward, specific ... Use sentence
  case, avoid passive voice, and include a period at the end." App Review adds: "Write a separate purpose
  string for every protected resource"; "Don't restate the name of the resource without explaining its use"; strings
  must be localized.
- **Pre-alert screens** (custom screen before the system alert):
  - "Include only one button and make it clear that it opens the system alert ... Use a term like
    'Continue' or 'Next'". Never "Allow".
  - "Don't include additional actions ... don't provide a way for people to leave the screen ... without
    viewing the system alert — like offering an option to close or cancel."
  - **Consequence:** the `onboarding.permission.*` screens copied from Yope must not carry "Not now" or
    "Skip" on iOS. For the optional contacts step, use an in-context `ContactAccessButton` /
    `contactAccessPicker` (iOS 18) inside the invite flow instead of a skippable pre-alert screen.
- **Microphone timing.** 5.1.1(iv) says photo-posting apps "must not also require microphone access before
  allowing the user to upload photos". Ask for the microphone at the first voice note or video.
- **Photos.**
  - `PHPickerViewController` / `PhotosPicker` needs no authorization ("The user doesn't need to explicitly
    authorize your app to select photos") and delivers `PHLivePhoto` "without library access".
  - Saving needs only `NSPhotoLibraryAddUsageDescription`.
  - If the full library is read, handle `.limited`. Add `PHPhotoLibraryPreventAutomaticLimitedAccessAlert`
    and present `presentLimitedLibraryPicker` from your own control.
  - **Recommendation:** use the picker plus add-only access. The onboarding photos permission screen is then
    unnecessary.
- **Contacts.** iOS 18 adds limited contacts access (`CNAuthorizationStatus.limited`). 5.1.2(v): "do not
  include a Select All option or default the selection of all contacts"; the person must see the invite
  message before it is sent.
- **Notifications.** There is no developer purpose string; the system alert text is fixed. Provisional
  authorization ("delivers provisional notifications quietly") is available. 4.5.4 says push notifications
  "must not be required for the app to function".

**Android rules (VERIFIED):**
- "Ask for a permission in context". "Don't block the user. Always provide the option to cancel an
  educational UI flow" (the opposite of the iOS pre-alert rule).
- Show a rationale only when `shouldShowRequestPermissionRationale()` returns true.
- After two denials the dialog is no longer shown ("considered a permanent denial").
- POST_NOTIFICATIONS is a runtime permission on Android 13+.
- **Photos:** use the Photo Picker (`PickVisualMedia`, no permission). Play policy: READ_MEDIA_IMAGES /
  READ_MEDIA_VIDEO only "if system pickers ... are not sufficient for your app to provide core
  functionality". So READ_MEDIA_VISUAL_USER_SELECTED and READ_MEDIA_IMAGES should be **omitted**.
- **Contacts:** a new Play Contact Permissions policy (announced 2026-04-15) applies. Apps targeting
  Android 17 (API 37+) may request READ_CONTACTS only if the Android Contact Picker
  (`Intent.ACTION_PICK_CONTACTS`) is insufficient, and must file a declaration. Enforcement starts
  2027-01-27. "Social discovery" is a declarable use. The picker exists only on API 37+, so older devices
  keep the runtime permission.
- CAMERA and RECORD_AUDIO are ordinary runtime permissions. Ask at first capture and at first voice
  note / video.

**Copy.** `platform.copy.json` holds 5 purpose strings with `infoPlistKey` set, plus "Continue". All follow
pattern `platform.purposeString`, using Apple's own subject form ("The app …"). Apple's examples are:
- "The app records during the night to detect snoring sounds."
- "The app uses location data to determine the recommended route to your destination and provide
  turn-by-turn directions."

Counter-examples Apple rejects: "Microphone access is needed for a better experience.", "Turn on
microphone access.", "To use location.", "Your data will be used to provide a better experience."

**Not found.**
- An Android rationale-dialog wording standard. Google publishes none; the Yope-voice research supplies it,
  laid out as an M3 basic dialog.
- An iOS notification purpose string. None exists, because the system shows fixed text.

---

## safety.report · safety.block

**References:** HIG Action sheets (…/action-sheets), HIG Menus (…/menus, 2026-06-08), HIG Sheets
(…/sheets, 2026-03-24), SwiftUI `confirmationDialog`; M3 bottom sheets guidelines + specs, M3 menus specs;
App Review 1.2 (UGC).

**Layout.**
- **Entry (iOS).** An overflow `Menu` on the photo or member. Labels are verbs in title-style capitalization
  ("Report", "Block"), with no articles. Use an ellipsis "when the action requires more information"
  (for example "Report…" if a reason picker follows).
- **Choice (iOS).** An action sheet / `confirmationDialog`:
  - "Use an action sheet — not an alert — to offer choices related to an intentional action".
  - Put destructive choices "at the top"; Cancel goes "at the bottom".
  - "Avoid letting an action sheet scroll".
  - A longer reason list goes in a sheet with medium/large detents and a grabber.
- **Android.** A `ModalBottomSheet` with list rows ("Use a modal bottom sheet as an alternative to inline
  menus or simple dialogs on mobile, especially when offering a long list of action items"), followed by an
  `AlertDialog` to confirm Block.
  - Sheet: top corners 28 dp, drag handle 32×4 dp at 0.4 opacity in `on-surface-variant`, container
  `surface-container-low`, initial height "capped at 50% of the screen height".
  - Baseline menu: item height 48 dp, container corner 4 dp, labelLarge.
  - The M3 expressive menus (`md.comp.menus.*`) use 44 dp items and a 16 dp corner. Pick one family.

**Store requirement (VERIFIED, App Review 1.2).** UGC apps must have "A method for filtering objectionable
material", "A mechanism to report offensive content and timely responses", "The ability to block abusive
users", and "Published contact information". Report and Block are therefore mandatory, not optional.

**Copy.** "Report" and "Block" follow `platform.alertButton`. "Cancel" is verbatim. Titles and explanations
come from the Yope-voice research.

**Not found.** A platform-mandated report-reason taxonomy. Neither Apple nor Google publishes one.

---

## Accessibility (all surfaces)

| value | rule | source | level |
|---|---|---|---|
| Large Title 34/41 Regular (emph. Bold); Title 1 28/34; Title 2 22/28; Title 3 20/25 (emph. Semibold); Headline 17/22 Semibold; Body 17/22; Callout 16/21; Subhead 15/20; Footnote 13/18; Caption 1 12/16; Caption 2 11/13 (Regular, emph. Semibold) | iOS Dynamic Type, Large (default) | HIG Typography §Specifications (2025-12-16); screenshot `hig-typography-dynamic-type-large.png` | VERIFIED |
| AX5 Body 53/62 (range up to Large Title 60/70) | largest accessibility size, for layout testing | same | VERIFIED |
| Default 17 pt, minimum 11 pt | iOS text sizes | HIG Typography §Ensuring legibility | VERIFIED |
| Display L/M/S 57/64, 45/52, 36/44 (400, tracking −0.25/0/0); Headline L/M/S 32/40, 28/36, 24/32 (400, 0); Title L 22/28 (400, 0), Title M 16/24 (500, 0.15), Title S 14/20 (500, 0.1); Body L/M/S 16/24, 14/20, 12/16 (400; 0.5/0.25/0.4); Label L/M/S 14/20, 12/16, 11/16 (500; 0.1/0.5/0.5) | M3 baseline type scale (sp) | m3 type-scale-tokens, snapshot 2026-10-13, audience 3p | VERIFIED |
| 44×44 pt default, 28×28 pt minimum | iOS control size | HIG Accessibility §Mobility | VERIFIED |
| 48×48 dp, 8 dp apart | Android touch target | developer.android.com/guide/topics/ui/accessibility/apps; support.google.com/accessibility/android/answer/7101858 | VERIFIED |
| 4.5:1 (text ≤17 pt iOS / <18 sp Android); 3:1 (≥18 pt, or bold); 3:1 non-text | contrast | HIG Accessibility table; Android accessibility page; WCAG 2.2 SC 1.4.3/1.4.11 | VERIFIED |
| Reduce Motion → reduce automatic/repetitive animation, zoom, scale, peripheral motion; replace x/y/z transitions with fades; avoid animating blurs; tighten springs | iOS | HIG Accessibility §Vision; `UIAccessibility.isReduceMotionEnabled`, `@Environment(\.accessibilityReduceMotion)` | VERIFIED / PLATFORM |
| `ValueAnimator.areAnimatorsEnabled()`; `Settings.Global.ANIMATOR_DURATION_SCALE` / `TRANSITION_ANIMATION_SCALE` = 0 | Android "Remove animations" | ValueAnimator reference; AOSP `DisableAnimationsPreferenceController.java` sets WINDOW_/TRANSITION_/ANIMATOR_DURATION_SCALE to 0 | PLATFORM |

**VoiceOver / TalkBack labeling (VERIFIED).**
- HIG VoiceOver: "Provide alternative labels for all key interface elements".
- "Describe meaningful images"; "describe only the information the image itself conveys".
- "Exclude purely decorative images".
- Group an image with its caption so VoiceOver reads them together.
- "Inform VoiceOver when visible content or layout changes occur" (for example, a new photo arriving).
- Android: "Use descriptions to convey the purpose and result of the interaction, not the visual details".
- Android: "Avoid redundancies ... make the button's description 'Submit', not 'Submit button'"; descriptions
  should be unique; no contentDescription on Text.
- Apply to: photo cells (who and when, plus caption, but not visual details), reaction chips (emoji name
  without counts, per tenets), and the countdown (the system timer text is read by VoiceOver).

---

## widget.home.small / .medium / .large / .xl · widget.lock.* · widget.arrival · widget.android

**References:** HIG Widgets (2026-10-13; screenshot `hig-widgets-ios-dimensions.png`); WidgetKit docs
(Keeping a widget up to date, Displaying the right widget background, WidgetRenderingMode, Optimizing your
widget for accented rendering mode and Liquid Glass, Adding interactivity…, contentMarginsDisabled,
widgetContentMargins, ContainerRelativeShape); Android widget design guide Sizing (2026-05-12, screenshot)
and Style (2026-01-21), Glance "Create an app widget" (2026-09-22), widget quality guidelines (2026-04-06),
Android "Provide flexible widget layouts" (2026-10-01), Google "Widgets on lock screen: FAQ" (2025-03-06).

**iOS sizes (pt, HIG table)**, iPhone 393×852 / 430×932:

| family | 393×852 | 430×932 |
|---|---|---|
| small | 158×158 | 170×170 |
| medium | 338×158 | 364×170 |
| large | 338×354 | 364×382 |
| accessoryCircular | 72×72 | 76×76 |
| accessoryRectangular | 160×72 | 172×76 |
| accessoryInline | 234×26 | 257×26 |

All 10 screen rows are in the tokens. The table has no 402×874 / 440×956 rows.
**System extra large is "Not supported" on iPhone**; it exists on iPad (for example 748×356 pt on the
13" device). `widget.home.xl` is therefore iPad/Mac only.

**Margins, corners, text (VERIFIED).**
- "Use the standard margin width for widgets — 16 points for most widgets". Use 11 pt for tighter groupings.
  The Lock Screen and StandBy use smaller margins, which the system applies.
- In code, keep the default content margins and read `widgetContentMargins`. For a full-bleed photo, put
  the photo in `.containerBackground(for: .widget)`. It "must" be removable, because StandBy and vibrant
  contexts remove backgrounds.
- Corners: "use a SwiftUI container to apply the correct corner radius ... ContainerRelativeShape". No
  numeric widget radius is published.
- Text: "display text using fonts at 11 points or larger". Widgets support Dynamic Type from Large to AX5.

**Rendering modes (iOS 18+/26).**
- Full color: Home Screen light/dark, StandBy, CarPlay.
- Accented: Home Screen tinted, and clear (Liquid Glass).
- Vibrant: Lock Screen and StandBy Night Mode, with a red tint.
- `@Environment(\.widgetRenderingMode)` reads the mode. `widgetAccentedRenderingMode(.fullColor)` (iOS 18)
  keeps an image in color in tinted/clear appearances. The docs reserve fullColor for "media content,
  such as album art", which fits group photos.
- **Lock Screen photo widgets are always desaturated (vibrant).** The WidgetKit doc says photo-reliant
  widgets "may not work well on the Lock Screen" and should use `disfavoredLocations`.
- **Implication for `widget.lock.*`:** a Locket-style color photo cannot appear on the iPhone Lock
  Screen. Lock widgets can show a monochrome photo, a name or time, or an inline text line.

**Interactivity.**
- Tapping the widget opens the app through `widgetURL` / `Link`.
- `Button(intent:)` / `Toggle(intent:)` work in system sizes and in accessoryCircular / Rectangular.
  Inline "offers only one tap target".
- "An interaction with a button or toggle should do more than open the app". So `camera.fromwidget` is a
  `widgetURL` deep link, not an AppIntent button.
- From a **locked** device, iOS 18's LockedCameraCapture extension plus a Control widget gives a real
  lock-screen camera. Inside it, the network and App Group are unavailable, and the app finishes posting
  after unlock.

**Motion (widget.arrival).** "use standard and custom animations with a duration of up to two seconds". In
widgets, SwiftUI animates when the timeline entry changes. A measured reference animation must fit within
2 s.

**Gallery description.** "Begin a description with an action verb ... Avoid ... 'This widget shows…' ...
sentence-style capitalization", with one description for all sizes. HIG examples: "See the current weather
conditions and forecast for a location", "Keep track of your upcoming events and meetings."
→ Proposed string "See the newest photo from your group." (`widget.home.small.description`).

**Android (Glance).**
- Default handheld sizes (dp, Pixel-based):

  | cells | min w | max w | min h | max h |
  |---|---|---|---|---|
  | 2x1 | 109 | 306 | 56 | 130 |
  | 2x2 | 109 | 306 | 115 | 276 |
  | 2x3 | 109 | 306 | 185 | 422 |
  | 4x1 | 245 | 624 | 56 | 130 |
  | 4x2 | 245 | 624 | 115 | 276 |
  | 4x3 | 245 | 624 | 185 | 422 |

- Cell formula (Pixel 4): portrait (73n−16)×(118m−16) dp, landscape (142n−15)×(66m−15) dp.
- Set `targetCellWidth` / `targetCellHeight`. "Make sure the container stretches edge-to-edge at all sizes"
  and do not "Add custom padding".
- Corner: `android:dimen/system_app_widget_background_radius`, "never larger than 28 dp". Inner radius =
  systemRadius − padding. Tier 1 quality requires the system radius.
- Touch targets 48×48 dp. Support dark theme and dynamic color (Material 3 theme).
- "Widget has a description that helps users understand the value". The preview should include user
  content (generated previews on Android 15+; `setWidgetPreview` is rate-limited to about 2 calls/hour).
- **Lock screen:** all widgets are eligible for the Android lock-screen widget hub. It is on Pixel
  tablets, on phones from Android 16 QPR2 per Android Authority (not a Google doc), and on OEMs that adopt
  the AOSP feature. It is about 4×3 cells. Opt out with `not_keyguard` (API 36). Activities launched from
  it need authentication or `showWhenLocked`. There is no equivalent of iOS accessory (circular /
  rectangular / inline) widgets.

**Not found.**
- A published iOS widget corner radius. It is system-supplied (ContainerRelativeShape).
- The numeric values of WidgetKit default content margins per context. `widgetContentMargins` returns
  them at runtime; the HIG standard is 16 pt.
- An Android widget size for the lock-screen hub other than "approximately 4 cells wide by 3 cells tall".

---

## daily.liveactivity

**References:** HIG Live Activities (2026-10-13; screenshot `hig-live-activities-ios-dimensions.png`);
ActivityKit "Displaying live data with Live Activities", "Starting and updating Live Activities with
ActivityKit push notifications"; SwiftUI `Text(timerInterval:pauseTime:countsDown:showsHours:)`.

**Sizes (pt).**

| screen | compact (each side) | minimal | expanded | Lock Screen | limited width |
|---|---|---|---|---|---|
| 393×852 | 52.33×36.67 | 36.67–45×36.67 | 371×84–160 | 371×84–160 | 28×28 |
| 430×932 | 62.33×36.67 | 36.67–45×36.67 | 408×84–160 | 408×84–160 | 28×28 |

**Rules (VERIFIED).**
- "The standard layout margin for Live Activities on the Lock Screen is 14 points".
- Compact/minimal must fit "inside a 28pt-diameter circle" for limited-width contexts (new 2026-10-13).
- Text: "large, heavier-weight text — a medium weight or higher".
- Dynamic Island background is always black. A custom background is allowed only on the Lock Screen.
- Animations have a "maximum duration of two seconds".
- Use `ContainerRelativeShape` for rounded elements near corners.
- No ads. "Avoid displaying sensitive information". Make it easy to turn the Live Activity off in the app.
- End "immediately when the task or event ends". Use a custom dismissal of "15 to 30 minutes" in most cases.
- "don't use push notifications alongside Live Activities for the same updates". The push-to-start alert
  therefore **is** the daily invitation on iOS; do not also send a separate notification.
- The countdown uses `Text(timerInterval:)`, which updates itself, so no per-second pushes are needed.

**Tenet note.** The HIG says alerts "light up the screen and by default play the notification sound"; use
them "only for essential updates". Use one alert, at start. Do not alert when the window is closing,
because that would be urgency framing (tenet 5).

**Not found.** The Dynamic Island corner radius. The 2026 HIG page no longer states one, and the earlier
"44 pt" note in `/home/user/newproject/research/27-apple-hig.md` is not in the current page. Use
`ContainerRelativeShape`.

## daily.ongoing (Android)

**References:** Android "Live Updates" (2026-10-07), `Notification.Builder` reference (2026-08-03),
`Notification.ProgressStyle` (API 36), Notification channels (2026-10-01).

**Countdown notification.** Use the native chronometer:
- `setUsesChronometer(true)`, `setChronometerCountDown(true)` (API 24), `setWhen(windowEnd)`
- `setTimeoutAfter(ms)` (API 26), which auto-cancels the notification at window close.

**Promotion to a Live Update** (Android 16; `setRequestPromotedOngoing` "Added in version 36.1"):
- Requirements: POST_PROMOTED_NOTIFICATIONS; ongoing; contentTitle set; no custom RemoteViews; not
  colorized; the channel is not IMPORTANCE_MIN.
- **Usage criteria:** "Most Live Updates should represent activities that are explicitly triggered by the
  user"; "Don't allow activities triggered by other parties to generate Live Updates"; inappropriate uses
  include "alerts" and "upcoming calendar events".
- A server-triggered daily invitation therefore **does not qualify by default**. The compliant path is a
  normal (non-promoted) chronometer notification. Promote only if the person explicitly opts in to
  following the window, and include an Unpin action (the doc allows this when "the user explicitly
  indicates that they want to begin monitoring a background event").
- If promoted, the status chip is at most 96 dp wide and `setShortCriticalText` is at most about 7
  characters.

**Channels.** The user-visible channel name has a recommended maximum of 40 characters, and the description
300. Importance cannot be changed after the channel is created.

---

## Haptics (PLATFORM; mapping by documented meaning)

**Sources:**
- HIG Playing haptics (2024-05-07). Its iOS patterns are notification Success/Warning/Error; impact
  Light/Medium/Heavy/Rigid/Soft; and Selection ("a UI element's values are changing").
- SwiftUI `SensoryFeedback` (iOS 17): start, stop, alignment, selection, success, warning, error, impact.
- Android `HapticFeedbackConstants` (2026-08-03) and "Add haptic feedback to events" (2026-10-06).

**HIG rules:**
- "Use system-provided haptic patterns according to their documented meanings".
- "Avoid overusing haptics".
- "Make haptics optional".
- "Ensure that haptic vibrations don't disrupt experiences involving ... the camera ... or microphone".

**Android rules:** View-based constants need no VIBRATE permission and honor the user's setting. "We
strongly discourage using older Vibrator methods".

| token | interaction | iOS | Android |
|---|---|---|---|
| haptic.camera.sendSuccess | photo sent | .success | CONFIRM (API 30) |
| haptic.camera.sendFailure | send failed | .error | REJECT (API 30) |
| haptic.groups.select | recipient / segmented / scrub | UISelectionFeedbackGenerator / .selection | SEGMENT_TICK (34); SEGMENT_FREQUENT_TICK |
| haptic.settings.toggle | switch | none (system Toggle) | TOGGLE_ON/OFF (34) if component lacks it |
| haptic.photo.longPress | reaction picker / context menu | system | LONG_PRESS |
| haptic.daily.countdownStart / Stop | capture countdown | .start / .stop (iOS 17) | none / CONFIRM on completion |
| haptic.week.dragStart / dragAlign | reorder | system / .alignment | DRAG_START (34) / SEGMENT_TICK |
| haptic.all.pullThreshold | pull to refresh | system | GESTURE_THRESHOLD_ACTIVATE/DEACTIVATE (34) |
| haptic.auth.keypad | custom keypad only | none (system keyboard) | VIRTUAL_KEY / VIRTUAL_KEY_RELEASE |
| haptic.settings.destructiveConfirmed | delete / block confirmed | .warning | CONFIRM |

**Not found.**
- An Android "warning" constant.
- An Android start/stop constant.
- A documented iOS shutter haptic. The system Camera behavior is not documented, so no shutter haptic is
  proposed.

---

## collage.share

**References:** HIG Activity views; SwiftUI `ShareLink` (iOS 16); Android "Send simple data to other apps"
(Sharesheet, 2026-10-13); Meta "Sharing to Stories"
(https://developers.facebook.com/docs/instagram-platform/sharing-to-stories/, updated 2026-06-30).

- **iOS.** "Use the Share button to display an activity view". Avoid duplicating system actions, and use
  `ShareLink` with a preview. **Android:** `Intent.createChooser(...)` for the Sharesheet, passing a
  `content://` URI with read permission.
- **Instagram Stories (Meta doc).**
  - Background image: "Minimum dimensions 720x1280. Recommended image ratios 9:16 or 9:18". Video "can be
    1080p and up to 20 seconds", and "Under 50 MB recommended".
  - Sticker: "Recommended dimensions: 640x480". The background defaults to `#222222` if no colors are
    passed.
  - Since January 2023 a Facebook App ID (`source_application`) is required. iOS also needs
    `instagram-stories` in `LSApplicationQueriesSchemes`.
  - **Correction to the brief:** the page does not state 1080×1920. The proposed canvas 1080×1920 is
    computed (9:16 at 1080 width) and meets the stated minimum.

## invite.appclip (card metadata)

HIG App Clips (2025-06-09):
- Card image "1800x1200 px PNG or JPEG image without transparency"; "Avoid using text" in it.
- Title ≤ 30 characters, subtitle ≤ 56 characters.
- "Avoid requiring people to create an account before they can benefit from your App Clip".
- Don't ask to install repeatedly. Use `SKOverlay` "when someone completes a task or reaches a natural pause".

## paywall (platform-required elements only)

The HIG Apple In-App Purchase page (2026-09-17) and the App Store subscriptions page require these on the
sign-up screen:
- The subscription name, duration, and content.
- The billing amount, "correctly localized". It must be "the most prominent pricing element"; per-month
  breakdowns go in a subordinate position.
- "A way for existing subscribers to sign in or restore purchases".
- Links to Terms of Use/Service and Privacy Policy.
- For a free trial, its length and the price billed afterwards.

Google Play adds:
- Disclose "the cost ..., the frequency of your billing cycle, the automatic renewal terms, whether a
  subscription is required to use the app".
- Show a clearly visible dismiss.
- Settings must link to the Play Subscription Center.

Strings: "Restore Purchases" (adapted, title case), "Privacy Policy", and "Terms of Use" (verbatim). The
Locket (Gold) research owns the paywall's look and other copy.

---

## Pattern ids introduced (to add to `design/COPY.md`)

| id | rule | examples (verbatim, with source) |
|---|---|---|
| `platform.purposeString` | One brief complete sentence, active voice, sentence case, period; name the specific feature; subject "The app …" | "The app records during the night to detect snoring sounds." (HIG Privacy); "The app uses location data to determine the recommended route to your destination and provide turn-by-turn directions." (App Review 5.1.1(ii) reference) |
| `platform.alertTitle` | Sentence → sentence case + punctuation; fragment → title case, no punctuation; ≤2 lines; no "Are you sure?" / "Warning!" / apologies | HIG Alerts §Content; M3 Dialogs §Headline |
| `platform.alertMessage` | Only if it adds value; complete sentences, sentence case, punctuation | HIG Alerts §Content |
| `platform.alertButton` | 1–2 word verb describing the result, title-style caps, no punctuation; "Cancel" for cancel; "OK" only informational | "View All", "Reply", "Ignore", "Erase", "Convert", "Clear", "Delete" (HIG Alerts) |
| `platform.widgetDescription` | Starts with an action verb; no "This widget shows…"; sentence-style caps; one per widget kind | "See the current weather conditions and forecast for a location"; "Keep track of your upcoming events and meetings." (HIG Widgets) |
