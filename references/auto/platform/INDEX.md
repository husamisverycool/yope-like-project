# platform references (VERIFIED — official documentation screenshots, internal reference only)

| file | source URL | accessed | what it shows | version/date |
|---|---|---|---|---|
| `hig-widgets-ios-dimensions.png` | https://developer.apple.com/design/human-interface-guidelines/widgets#Specifications | 2026-10-15 | HIG widget "iOS dimensions" table (small/medium/large/circular rows per screen size) | HIG Widgets page, change log 2026-10-13 |
| `hig-live-activities-ios-dimensions.png` | https://developer.apple.com/design/human-interface-guidelines/live-activities#Specifications | 2026-10-15 | HIG Live Activities specifications: CarPlay, iOS (compact/minimal/expanded/Lock Screen) and iPadOS tables | HIG Live Activities page, change log 2026-10-13 |
| `hig-typography-dynamic-type-large.png` | https://developer.apple.com/design/human-interface-guidelines/typography#Specifications | 2026-10-15 | HIG iOS/iPadOS Dynamic Type sizes, "Large (default)" tab (style, weight, size, leading, emphasized weight) | HIG Typography page, change log 2025-12-16 |
| `android-widget-default-sizes.png` | https://developer.android.com/design/ui/mobile/guides/widgets/sizing | 2026-10-15 | Android widget design guide "Default sizes" handheld table (2x1…4x3 min/max dp) | Page last updated 2026-05-12 |

Text of every other cited page was fetched as Apple DocC JSON (`https://developer.apple.com/tutorials/data/...json`),
Android/Firebase HTML, and Material 3 token JSON (`https://m3.material.io/_dsm/data/dsdb-m3/2026-10-13_06-10-19/*.json`);
URLs are listed next to each value in `design/research/platform.md` and `docs/PLATFORM_CONSTRAINTS.md`.

## Gap fill (account, capture, global, memory) — 2026-10-15

| file | source URL | accessed | what it shows | version/date |
|---|---|---|---|---|
| `aosp-toast-duration-excerpt.txt` | https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/services/core/java/com/android/server/notification/NotificationManagerService.java ; …/core/java/android/widget/Toast.java | 2026-10-15 | `SHORT_DELAY = 2000; // 2 seconds`, `LONG_DELAY` 3.5 s, `LENGTH_SHORT = 0` (`safety.block.duration.toast`, `camera.sendto.duration.toastVisible`) | AOSP main, 2026-10 |
| `react-navigation-ios-modal-spring-excerpt.txt` | https://raw.githubusercontent.com/react-navigation/react-navigation/main/packages/stack/src/TransitionConfigs/TransitionSpecs.tsx and TransitionPresets.tsx | 2026-10-15 | `TransitionIOSSpec` spring {stiffness 1000, damping 500, mass 3, overshootClamping}; `ModalPresentationIOS` "Standard iOS modal presentation style (introduced in iOS 13)" uses it (`spring.global.sheetPresent`) | main branch, 2026-10 |
| `sf-pro-display-digit-one-stem-ratio.csv` | SF Pro Display v3 web fonts from https://www.apple.com/wss/fonts?families=SF+Pro,v3 (measurement only; no font file stored) + `references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png` | 2026-10-15 | '1' stem ÷ height per weight (regular 0.121 … bold 0.207 … black 0.294) vs BeReal's countdown 0.205 (`daily.capture.fontWeight.countdown`) | SF Pro v3 web, 2026-10 |
| `android-photopicker-selected-f200.png`, `android-photopicker-unselected-f150.png` | https://developer.android.com/static/images/training/data-storage/kotlin-picker.gif (Figure 1 of https://developer.android.com/training/data-storage/shared/photopicker) | 2026-10-16 | Social pass: two stills (frames 150 and 200 of 227; the animation is not kept) of the Android system photo picker, 412 × 892 px = dp. Selected cell 135 dp: photo inset 12 dp on every side, corners ≈ 16 dp, cell fill #DEE3EA, a 20-dp filled check circle (#0C58CE, white check) with a ≈ 1.5-dp white outline centred (20, 19) dp from the cell's top-left; unselected: no mark (`week.edit.layout.selectionMark`) | page as of 2026-10-16 |
| `chromium-tab-reorder-a11y-strings-excerpt.txt` | https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/android/features/tab_ui/java/strings/android_chrome_tab_ui_strings.grd | 2026-10-16 | Social pass: Chrome for Android's accessibility actions for reordering tabs in its grid: "Move tab left", "Move tab right", "Move tab up", "Move tab down" (`week.edit.a11y.moveLeft` / `.moveRight`) | Chromium main 2026-10 |
