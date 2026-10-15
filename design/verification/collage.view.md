# Verification — `collage.view` (iOS)

Same-moment collage, option B pages — `ios/App/Sources/Features/Capture/Collage/`.

Checklist written from the spec (`design/surfaces/collage.view.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/collage.view.png` next to the reference image(s) below.

Reference image(s): `design/collage-options/option-B.jpg`, `references/auto/yope/frames/b-alexaa-7652512140875566349-t5.33-day-view-recap.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t50.60-loading-hud.png`

Snapshots (CI): `collage.view-loading.png`, `collage.view-ready.png`, `collage.view-ready-one-page.png`, `collage.view-empty.png`, `collage.view-error.png`, `collage.view-offline.png`

**Summary: 17 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `collage.view.layout.screen` | headerCenterFromTop: 81; dotsCenterFromTop: 125; pageTop: 145; pageFit: 9:16, aspect-fit in the space above the home indicator, centred (SOURCED) | header centre 81, dots 125, page from 145, 9:16 aspect-fit above home indicator | offsets from the screen top |
| matched | `size.global.headerButton` | 44 pt (SOURCED) | back circle | shared HeaderCircleButton |
| matched | `icon.global.back` | ios: chevron.left; android: AutoMirrored.Rounded.KeyboardArrowLeft (PLATFORM) | back | Image |
| matched | `collage.view.fontSize.title` | 16 pt (SOURCED) | 16 | DSTextStyle (callout) |
| matched | `collage.view.fontWeight.title` | semibold (SOURCED) | semibold | DSTextStyle |
| matched | `collage.view.title` | “{date}” (SOURCED) | {date} 'd Month' | CaptureFormat.collageDate |
| matched | `collage.view.layout.pageDots` | diameter: 7.6; pitch: 15.5; inactive: color.global.controlRaised; ios: native page control (UIPageControl / TabView .page index) (SOURCED) | iOS: native page control | UIPageControl (2+ pages) |
| matched | `collage.view.layout.page` | columns: 3; rowsPerPage: 4; gapRatio: 0; outerRadiusRatio: 0.0498; canvasAspect: 0.5625; canvasWidthPx: 1080 (SOURCED) | 9:16, 1080 px, corners in the JPEG | Image scaledToFit (matte corners in the file) |
| matched | `collage.view.layout.hud` | width: 100; height: 99; cornerRadius: 8.5 (SOURCED) | HUD 100 × 99 r 8.5 | loadingHUD |
| matched | `collage.view.color.hud` | #0C0C0C (SOURCED) | #0C0C0C | fill |
| matched | `collage.view.loading` | “Loading” (SOURCED) | ‘Loading’ | body role |
| matched | `collage.view.empty.title` | “no photos from this moment” (SOURCED) | empty | CaptureEmptyState → camera with the group |
| matched | `collage.view.error.title` | “these photos didn’t load” (SOURCED) | error | CaptureEmptyState + refetch |
| matched | `collage.view.offline.title` | “you’re offline” (SOURCED) | offline | cached pages first, else this layout |
| matched | `collage.view.a11y.collage` | “photos from {group}, {date}” (SOURCED) | page label | image element |
| matched | `collage.view.a11y.back` | “back” (SOURCED) | back | label |
| matched | `duration.global.photoSwipe` | 167 ms (SOURCED) | page swipe | TabView .page (system paging physics, easing.global.photoSwipe) |

## Notes

- Recomposing: the shown pages stay until the new version's first page is decoded, then swap in one frame.
- Pages are decoded off the main actor and the next page is prefetched.
