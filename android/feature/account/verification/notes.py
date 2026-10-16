"""Reviewed notes (Pass 4, Retro redesign) for spec tokens and copy that the account screens meet without a direct
`Tokens.*` / `R.string.*` reference (descriptive layout / platform tokens, another platform's values, another pass's
surface).

NOTES[(surface or "*", token)] = (status, what our screen does, note)
COPY_NOTES[(surface or "*", key)] = (status, what our screen does, note)
"""

B = "match (behaviour)"
NA = "n/a"
AP = "approx"

NOTES = {
    # --- global platform / motion -------------------------------------------------------------
    ("*", "layout.global.reduceMotion"): (B, "DsMotion / LocalReduceMotion: page changes, pagers and cross-fades fall back to fades when animations are off", "PLATFORM"),
    ("*", "easing.global.native"): (B, "Navigation Compose transitions, M3 ModalBottomSheet / AlertDialog / Switch keep the system motion", "PLATFORM curve: nothing to set"),
    ("*", "spring.global.sheetPresent"): (NA, "the account sheets are native destinations / M3 ModalBottomSheet with the system motion", "token note: native sheets keep the system motion; this spring is for custom sheets"),
    ("*", "duration.global.sheetPresent"): (NA, "as spring.global.sheetPresent", "system sheet motion"),
    ("*", "spring.global.platformDefault.android"): (B, "M3 Switch / Material motion defaults", "PLATFORM"),
    ("*", "layout.global.textStyleMap"): (B, "every text role is in sp (scales with the font size); long pages scroll", "iOS Dynamic Type mapping; Android scales sp"),
    ("*", "layout.global.cornerStyle"): (B, "RoundedCornerShape (circular corners)", "Android has no continuous corners"),
    ("*", "radius.global.capsule"): (B, "CircleShape / RoundedCornerShape(50 %) on every capsule (C-05, C-06, C-09)", ""),
    ("*", "color.global.selection"): (B, "M3 Switch checked track (core:ui GroupedRow toggle, AppTheme colour scheme)", "PLATFORM tint"),
    ("*", "color.global.premium"): (NA, "the purple FREE / trial badge is not drawn: core:billing returns no trial offers", "trial pill not built (no trial data)"),
    ("*", "settings.root.layout.toggleHaptic"): (B, "M3 Switch plays no custom haptic; the view model raises haptic.global.select on toggle", "PLATFORM"),
    ("*", "settings.root.layout.list"): (B, "C-14 GroupedSection / GroupedRow (core:ui) inside SettingsGroup (settings/SettingsUi.kt); headers SettingsHeader, footers SettingsFooter", ""),
    ("*", "settings.account.layout.alert"): (B, "M3 AlertDialog (core:ui SystemAlertDialog / ErrorAlert), destructive confirm in color.global.destructive", ""),
    ("*", "auth.phone.layout.inlineError"): (B, "message-only M3 AlertDialog (core:ui ErrorAlert) with auth.phone.error.dismiss", ""),
    ("*", "auth.phone.layout.keyboard"): (B, "KeyboardType.Phone + ContentType.PhoneNumber autofill; the field takes focus on appear", ""),
    ("*", "auth.code.layout.codeField"): (B, "one FormTextField, KeyboardType.NumberPassword, ContentType.SmsOtpCode; SMS User Consent fills it", ""),
    ("*", "auth.agegate.layout.dateEntry"): (B, "C-12 field with the locale's digit order and separators (DateEntryPattern), no default year", ""),
    ("*", "auth.agegate.layout.optIn"): (B, "C-14 single-row group with an M3 Switch under the field", ""),
    ("*", "auth.profile.layout.avatarPicker"): (B, "ActivityResultContracts.PickVisualMedia (single image), no permission", "PLATFORM"),
    ("*", "onboarding.permission.notifications.layout.preAlert"): (B, "OnboardingForm page (title, explanation, capsule + 'Maybe later' link on API 33+)", ""),
    ("*", "haptic.global.shutter"): (NA, "no haptic (the value is none); the shutter is camera.capture's", "capture pass"),
    ("*", "onboarding.permission.camera.layout.request"): (NA, "camera.capture requests CAMERA on first open (capture pass)", "another pass's surface"),
    ("*", "onboarding.permission.photos.layout.request"): (B, "pickers need no permission (PickVisualMedia); API 29+ MediaStore saves need none", "PLATFORM"),
    ("*", "icon.global.download"): (B, "the denied-save block's glyph (drawn by photo.viewer, social pass; rendered here as the same composition)", ""),
    ("*", "groups.invite.layout.contacts"): (B, "Android: READ_CONTACTS after 'Connect Contacts' (rationale / settings via core:ui rememberPermissionRequest), people rows with Invite capsules (SMS)", "iOS 18 ContactAccessButton is iOS only"),
    ("*", "groups.list.layout.tabBar"): (B, "shell ShellTabBar → core:ui TabBar (C-04): camera, home, walls, me icons; over media on the camera", ""),
    ("*", "groups.screen.layout.menu"): (AP, "long-press on others' strip tiles / grid cells opens a DsDropdownMenu (Report Post / Block {first_name}); own photos have no menu", "core:ui DayTile / GridCell got a `menu` slot (Modifier.tapLongPressable)"),
    ("*", "safety.report.layout.flow"): (B, "menu item → M3 ModalBottomSheet (reasons) → a reason sends at once and closes; 'I don't like it' → Next Steps; alerts after (ReportFlow)", ""),
    ("*", "safety.block.layout.menu"): (B, "DropdownMenu items in groups.screen / groups.settings", ""),
    ("*", "safety.block.layout.confirm"): (B, "M3 AlertDialog with the destructive 'Block' (BlockConfirmation)", ""),
    ("*", "paywall.layout.promptRule"): (B, "SessionPromptGate: at most one automatic paywall per session; settings always opens it", ""),
    ("*", "paywall.layout.planCard"): (B, "core:ui PlanCardPager / PlanCard inside AppTheme(dark = false): white card, black capsule in both appearances; paywall.fontSize / paywall.color plan roles", "measured below"),
    ("*", "paywall.layout.requiredDisclosures"): (B, "store-localized prices, the billed amount per period (periodUnit), auto-renew line (paywall.legal.billing.android), Restore / Terms / Privacy", ""),
    # --- invite.web (the web page's own tokens) -----------------------------------------------------
    ("invite.web", "invite.web.layout.ogImage"): (NA, "web only (link preview image)", "web pass"),
    ("invite.web", "invite.web.size.breakpoint"): (NA, "web only (desktop layout)", "web pass"),
    ("invite.web", "invite.web.layout.backdrop"): (B, "core:ui BlurredBackdrop (sigma size.global.backdropBlur, dim color.global.backdropDim) over the group cover", ""),
    ("invite.web", "invite.web.color.pillHover"): (NA, "web hover state", "no hover on touch"),
    ("invite.web", "invite.web.duration.pill"): (NA, "web hover transition", ""),
    ("invite.web", "invite.web.easing.pill"): (NA, "web hover transition", ""),
    ("invite.web", "invite.web.size.qrDesktop"): (NA, "desktop layout", "web pass"),
    ("invite.web", "invite.web.size.avatarDesktop"): (NA, "desktop layout", "web pass"),
    ("invite.web", "invite.web.fontSize.headlineDesktop"): (NA, "desktop layout", "web pass"),
    ("invite.web", "invite.web.size.headlineTopDesktop"): (NA, "desktop layout", "web pass"),
    ("invite.web", "invite.web.fontSize.bodyDesktop"): (NA, "desktop layout", "web pass"),
    ("invite.web", "invite.web.lineHeight.bodyDesktop"): (NA, "desktop layout", "web pass"),
    ("invite.web", "invite.web.color.bodyDesktop"): (NA, "desktop layout", "web pass"),
    ("invite.web", "invite.web.size.bodyMaxWidthDesktop"): (NA, "desktop layout", "web pass"),
    ("invite.web", "invite.web.size.bodyToQrDesktop"): (NA, "desktop layout", "web pass"),
    ("invite.web", "invite.web.layout.linkPreview"): (NA, "web document metadata", "web pass"),
}

COPY_NOTES = {
    ("*", "system.permissions.camera.purpose"): (NA, "iOS Info.plist purpose string", "Android has no purpose string"),
    ("*", "system.permissions.microphone.purpose"): (NA, "iOS Info.plist purpose string", ""),
    ("*", "system.permissions.photosAdd.purpose"): (NA, "iOS Info.plist purpose string", ""),
    ("*", "system.permissions.photosRead.purpose"): (NA, "iOS Info.plist purpose string", ""),
    ("*", "system.permissions.contacts.purpose"): (NA, "iOS Info.plist purpose string", ""),
    ("*", "system.permissions.rationale.microphone.title"): (NA, "the microphone rationale is shown by camera.sendto (capture pass) through core:ui rememberPermissionRequest", "rendered here in system.permissions/rationale-microphone"),
    ("*", "system.permissions.rationale.notifications.title"): (NA, "Android asks POST_NOTIFICATIONS after the onboarding pre-alert page (no separate rationale dialog)", "rendered in system.permissions/rationale-notifications"),
    ("*", "onboarding.permission.photos.denied.title"): (NA, "photo.viewer (social pass) places the denied-save block", "rendered here as the same composition"),
    ("*", "onboarding.permission.contacts.search.placeholder"): (NA, "iOS 18 ContactAccessButton search field", "iOS only"),
    ("*", "onboarding.permission.contacts.choose"): (NA, "iOS 17 'choose contacts' pill", "iOS only"),
    ("*", "onboarding.widget.step.ios.1"): (NA, "iOS steps", "Android shows onboarding.widget.step.android.*"),
    ("*", "onboarding.widget.continue"): (NA, "iOS 'Next'", "Android: 'Add Widget' + 'Maybe later'"),
    ("*", "settings.notifications.liveActivity"): (NA, "Live Activity row", "iOS only"),
    ("*", "settings.notifications.liveActivity.footer"): (NA, "Live Activity footer", "iOS only"),
    ("*", "paywall.legal.billing.ios"): (NA, "Android shows paywall.legal.billing.android", "iOS only"),
    ("*", "paywall.locked.badge"): (NA, "the 'Premium' badge sits on other passes' locked controls", ""),
    ("*", "paywall.plans.trial.badge"): ("MISS", "not drawn", "core:billing exposes no trial offer (no introductory-price data)"),
    ("*", "paywall.plans.trial.cta"): ("MISS", "not drawn", "as above"),
    ("*", "safety.report.menuItem.post"): (B, "groups.screen's photo menu uses groups.screen.photo.menu.report (same text, surface key)", ""),
    ("*", "safety.block.menuItem"): (B, "groups.settings member menu uses groups.settings.members.menu.block", ""),
    ("*", "safety.block.menuItemNamed"): (B, "groups.screen's photo menu uses groups.screen.photo.menu.block ({first_name})", ""),
    ("groups.screen", "birthday.request.title"): (B, "BirthdayRequestEntries (memory pass) supplies the title; this screen draws the row", ""),
    ("groups.screen", "birthday.request.due"): (B, "BirthdayRequestEntries supplies the due line", ""),
    ("groups.screen", "onthisday.entry.title"): (B, "OnThisDayEntry (memory pass) supplies the card copy", ""),
    ("groups.screen", "year.story.entry.title"): (B, "YearStoryEntry (memory pass) supplies the card copy", ""),
    ("invite.web", "invite.web.desktop.scan"): (NA, "desktop page", "web pass"),
    ("invite.web", "invite.web.getApp"): (NA, "web page link", "web pass; the app is the destination"),
    ("invite.web", "invite.web.cover.alt"): (NA, "web alt text", "the native cover is the decorative backdrop"),
    ("invite.web", "invite.web.og.title"): (NA, "web metadata", ""),
    ("invite.web", "invite.web.og.description"): (NA, "web metadata", ""),
    ("invite.web", "invite.web.notFound.documentTitle"): (NA, "web <title>", ""),
}
