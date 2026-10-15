"""Reviewed notes for spec tokens and copy that the account screens meet without a direct `Tokens.*`
reference (descriptive layout / platform tokens, another platform's values, another pass's surface).

NOTES[(surface or "*", token)] = (status, what our screen does, note)
COPY_NOTES[(surface or "*", key)] = (status, what our screen does, note)
"""

B = "match (behaviour)"
NA = "n/a"

NOTES = {
    # --- global platform / motion -------------------------------------------------------------
    ("*", "easing.global.native"): (B, "Navigation Compose default transitions, system keyboard, M3 sheets and progress indicators", "PLATFORM curve: nothing to set"),
    ("*", "duration.global.navigationPush"): (NA, "native push (Navigation Compose)", "the spec: Yope's 100 ms push cannot be applied to a native push (F-11)"),
    ("*", "spring.global.platformDefault.ios"): (NA, "Android uses spring.global.platformDefault.android", "iOS token"),
    ("*", "layout.global.reduceMotion"): (B, "rememberReduceMotion() (ANIMATOR_DURATION_SCALE = 0): segmented pill, feed insertions and toast cross-fade instead of moving", ""),
    ("*", "layout.global.textStyleMap"): (B, "all text sizes are sp tokens (scale with the font size); stacks scroll at large sizes", "iOS Dynamic Type mapping; Android scales sp"),
    ("*", "layout.global.system.typography"): (B, "MaterialTheme.typography on system lists, dialogs and sheets (bodyLarge / bodyMedium / headlineSmall / labelLarge)", ""),
    ("*", "color.global.system.ios"): (NA, "Android system surfaces use color.global.system.* (M3 dark roles)", "iOS token"),
    ("*", "color.global.destructive"): (NA, "destructive labels use color.global.system.error", "token note: on Android system surfaces use color.global.system.error"),
    ("*", "radius.global.capsule"): (B, "CircleShape (height / 2) on every capsule: toast, CTA, header capsule, segmented track and pill, enable pill", ""),
    ("*", "haptic.global.shutter"): (NA, "no haptic (android: none)", "camera.capture places the card"),
    ("*", "haptic.global.longPressStart"): ("approx", "menus open from a tap on the ••• circle (DropdownMenu, no haptic); no long-press menu on Android cards", "iOS context-menu haptic; Android DropdownMenu plays none"),
    ("*", "haptic.global.send"): (NA, "SMS invites open the SMS app (ACTION_SENDTO returns no result), so no 'sent' moment exists", "spec: SMS sent (.sent) → send; iOS MFMessageCompose only"),
    ("*", "spring.global.sheetPresent"): (NA, "groups.create is a native destination; M3 sheets keep the system motion", "token note: native sheets keep the system motion; this spring is for custom sheets"),
    ("*", "color.global.scrim"): (NA, "no custom sheet or text-over-photo scrim on these surfaces; M3 sheets and dialogs keep their own scrim", "token note: system sheets keep their own dimming"),
    # --- auth ------------------------------------------------------------------------------------
    ("*", "auth.phone.layout.subtitle"): (B, "TextRoles.onboardingSubtitle: auth.phone.fontSize.subtitle, italic, regular, color.global.textPrimary, centred", ""),
    ("*", "auth.phone.layout.legalFooter"): (B, "LegalFooter: caption role, color.global.textSecondary, link phrases bold (LinkAnnotation → Custom Tabs), centred, bottom of the safe area", "snapshot has no nav-bar inset, so the footer touches the bottom edge"),
    ("*", "auth.phone.layout.keyboard"): (B, "KeyboardType.Phone + ContentType.PhoneNumber autofill", ""),
    ("*", "auth.phone.layout.countryCode"): (B, "flag (regional-indicator emoji fitted into a 20 × 13 slot) 20 from the field edge, text keeps flagToText clear; inline calling code, as-you-type formatting, zero after the code kept; tap → country list (M3 modal sheet)", "gap fill G2-4; flag slot from Tokens.Layouts.AuthPhoneLayoutCountryCode"),
    ("*", "auth.phone.layout.inlineError"): (B, "ErrorAlert: M3 AlertDialog, no title, the error sentence, one button auth.phone.error.dismiss; Back / outside do not close it", "gap fill G2-5; auth.phone, auth.code, auth.agegate, auth.profile, groups.create"),
    ("*", "auth.code.layout.codeField"): (B, "one FormTextField, KeyboardType.NumberPassword, ContentType.SmsOtpCode; SMS User Consent (SmsRetriever.startSmsUserConsent) fills it", ""),
    ("*", "auth.agegate.layout.dateEntry"): (B, "Yope form field with a numeric keyboard; placeholder = the locale's short-date order (getLocalizedDateTimePattern FormatStyle.SHORT); empty by default; minimum age not shown before submit", ""),
    ("*", "auth.agegate.layout.optIn"): ("approx", "CheckRow: label listSubtitle textPrimary, detail listSubtitle textSecondary, trailing check / ring, unchecked by default", "the Material check glyph's visible circle is 20 dp in its 24 dp box (measured above)"),
    ("*", "auth.profile.layout.avatarPicker"): (B, "Photo Picker (PickVisualMedia ImageOnly), no READ_MEDIA_* permission", ""),
    # --- onboarding ---------------------------------------------------------------------------
    ("*", "onboarding.permission.camera.layout.request"): (NA, "requested by camera.capture (capture pass); rationale = core:ui PermissionRationale (M3 dialog, only when shouldShowRequestPermissionRationale)", "this pass provides PermissionCard / rememberPermissionRequest"),
    ("*", "onboarding.permission.contacts.layout.card"): (B, "core:ui PermissionCard: no illustration, title + detail left-aligned 16 from the edge, white button 16 from the trailing edge, optional ✕ top-trailing", ""),
    ("*", "onboarding.permission.notifications.layout.preAlert"): ("approx", "API 33+: this screen, then POST_NOTIFICATIONS; API ≤ 32 skipped. 'maybe later' sits above 'continue'", "Structure 5 puts the dark button above the lime one (buttonGap above the primary); the token's android line says 'under' — Structure followed"),
    ("*", "onboarding.permission.photos.layout.request"): (NA, "no screen: Photo Picker everywhere; the viewer pass saves through MediaStore", ""),
    ("*", "groups.invite.layout.contacts"): ("approx", "READ_CONTACTS granted → contact rows; not granted → the inline contacts card", "the API 37 Contact Picker path is not built (targetSdk < 37)"),
    # --- groups -------------------------------------------------------------------------------
    ("*", "groups.list.layout.tabBar"): (B, "core:ui FloatingTabBar: camera · groups · walls · me (avatar), selected pill controlRaised, icon-only, no badges", ""),
    ("*", "groups.create.layout.titleAccent"): (B, "core:ui AccentTitle: line 1 textPrimary, line 2 accent, onboardingTitle role, centred", ""),
    ("*", "groups.invite.layout.share"): (B, "Intent.createChooser(ACTION_SEND text/plain)", ""),
    ("*", "groups.screen.layout.background"): (B, "feed on color.global.background, profile on color.global.backgroundDeep", ""),
    ("*", "groups.screen.layout.menu"): (B, "DropdownMenu anchored to the ••• circle; destructive items in color.global.system.error", ""),
    ("*", "safety.block.layout.menu"): (B, "DropdownMenu items (M3 baseline), Block / Report… in color.global.system.error", ""),
    # --- settings / safety --------------------------------------------------------------------
    ("*", "settings.root.layout.list"): (B, "core:ui SystemScaffold + SystemList: LazyColumn of M3 ListItem rows on color.global.system.surface, headers/footers bodyMedium onSurfaceVariant, HorizontalDivider (divider.android, system.outline)", ""),
    ("*", "settings.root.layout.toggleHaptic"): (B, "SystemSwitchRow plays TOGGLE_ON / TOGGLE_OFF on API 34+ (the M3 Switch plays none)", ""),
    ("*", "settings.root.size.listItemOneLine.android"): (B, "M3 ListItem one-line height (56 dp) — platform default", "measured above where a one-line row is visible"),
    ("*", "settings.blocked.layout.empty"): (B, "core:ui SystemEmpty: centred, bodyLarge onSurface + bodyMedium onSurfaceVariant", ""),
    ("*", "safety.report.layout.flow"): (B, "ModalBottomSheet (top corners 28, drag handle, container system.surfaceContainerLow), 'Report' TextButton in system.error", ""),
    ("*", "safety.block.layout.confirm"): (B, "SystemAlertDialog (M3) with Block as the confirming, destructive action", ""),
    ("*", "safety.block.layout.toast"): (B, "core:ui ToastHost / LimeToast: accent fill, checkmark + label onAccent (button role), capsule, top under the status bar, side margins size.global.screenMargin, spring enter / cross-fade under Reduce Motion", "measured on auth.code resent-toast"),
    ("*", "safety.report.layout.reasons"): ("BLOCKED", "no reason list (the details text, or the target kind, is the reason)", "categories are the owner's; G2-8: Locket ships without a reason list"),
    # --- paywall ------------------------------------------------------------------------------
    ("*", "paywall.layout.promptRule"): (B, "settings entry always opens; locked perks use openPaywallFromLockedPerk (SessionPromptGate: once per session, never during capture/onboarding)", ""),
    ("*", "paywall.layout.planSheet"): (B, "ModalBottomSheet with the M3 drag handle, top corners radius.global.sheet android (28)", ""),
    ("*", "paywall.layout.requiredDisclosures"): (B, "store prices at runtime (Play ProductDetails via core:billing), renewal + cancellation lines, Restore Purchases, Terms / Privacy links", ""),
    ("*", "paywall.size.iconTile"): ("BLOCKED", "tile omitted (its art paywall.layout.iconTileArt is BLOCKED)", "the title moves up"),
    ("*", "paywall.layout.iconTileArt"): ("BLOCKED", "tile omitted", "owner asset (the app icon)"),
    ("*", "paywall.fontSize.planDetail"): ("MISS", "no detail line under the yearly plan", "not built: core:billing's PremiumPackage exposes only formattedPrice; the per-month price (RevenueCat pricePerMonth) needs a core:billing accessor (foundation API, not this pass's)"),
    ("*", "paywall.color.planDetail"): ("MISS", "no detail line under the yearly plan", "as above"),
    ("*", "color.global.separator"): (NA, "Yope surfaces separate cards with gaps; system lists use system.outline", "core:ui Hairline() provides it for surfaces that name it"),
}

COPY_NOTES = {
    ("*", "system.permissions.camera.purpose"): (NA, "iOS Info.plist purpose string", "Android has no purpose string"),
    ("*", "system.permissions.microphone.purpose"): (NA, "iOS Info.plist purpose string", ""),
    ("*", "system.permissions.photosAdd.purpose"): (NA, "iOS Info.plist purpose string", ""),
    ("*", "system.permissions.photosRead.purpose"): (NA, "iOS Info.plist purpose string", ""),
    ("*", "system.permissions.contacts.purpose"): (NA, "iOS Info.plist purpose string", ""),
    ("*", "system.permissions.rationale.camera.title"): (NA, "camera rationale shown by camera.capture (capture pass) through core:ui PermissionRationale", ""),
    ("*", "onboarding.permission.camera.denied.title"): (NA, "camera.capture (capture pass) places the denied card (core:ui PermissionCard)", ""),
    ("*", "onboarding.permission.camera.denied.detail"): (NA, "camera.capture places it", ""),
    ("*", "onboarding.permission.camera.denied.button"): (NA, "camera.capture places it", ""),
    ("*", "onboarding.permission.photos.denied.title"): (NA, "the viewer pass places the denied-save card (core:ui PermissionCard)", ""),
    ("*", "onboarding.permission.contacts.search.placeholder"): (NA, "iOS 18 ContactAccessButton search field", "iOS only"),
    ("*", "onboarding.permission.contacts.choose"): (NA, "iOS 17 'choose contacts' pill", "iOS only"),
    ("*", "onboarding.widget.step.ios.1"): (NA, "iOS steps", "Android shows onboarding.widget.step.android.*"),
    ("*", "settings.notifications.liveActivity"): (NA, "Live Activity row", "iOS only"),
    ("*", "settings.notifications.liveActivity.footer"): (NA, "Live Activity footer", "iOS only"),
    ("*", "walls.mine.a11y.settings"): (NA, "the walls pass's settings entry", "names the entry point into settings.root"),
    ("*", "paywall.legal.billing.ios"): (NA, "Android shows paywall.legal.billing.android", "iOS only"),
    ("*", "paywall.locked.badge"): (NA, "the 'Premium' badge sits on other passes' locked controls", ""),
    ("*", "paywall.plans.yearly.detail"): ("MISS", "not shown", "needs a per-month price from core:billing (PremiumPackage exposes only formattedPrice)"),
    ("*", "paywall.perk.history.emoji"): ("BLOCKED", "history perk drawn without an emoji in release", "no sourced emoji (owner)"),
    ("*", "safety.report.menuItem"): (B, "menus use groups.screen.photo.menu.report / groups.settings.members.menu.report (same text, surface-specific keys)", ""),
    ("*", "safety.block.menuItem"): (B, "menus use groups.settings.members.menu.block", ""),
    ("*", "safety.block.menuItemNamed"): (B, "the photo menu uses groups.screen.photo.menu.block ({first_name})", ""),
}
