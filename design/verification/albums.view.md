# Verification — `albums.view` (iOS)

One album — `ios/App/Sources/Features/Social/UI/AlbumViews.swift` (`AlbumScreen`), `Core/AlbumModels.swift` (`AlbumModel`).

Checklist written from the spec (`design/surfaces/albums.view.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/albums.view.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/owner/yope-week-recap.jpg`, `references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png`

Snapshots (CI): `albums.view-ready.png`, `albums.view-loading.png`, `albums.view-empty.png`, `albums.view-not-found.png`, `albums.view-error.png`, `albums.view-offline.png`, `albums.view-rename.png`

**Summary: 9 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Layout and menu

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.background`<br>`size.global.headerButton`<br>`color.global.controlOnDeep`<br>`size.global.headerInset`<br>`icon.global.back`<br>`icon.global.more`<br>`photo.viewer.a11y.more` | #171717 (SOURCED)<br>44 pt (SOURCED)<br>#101010 (SOURCED)<br>11.5 pt (SOURCED)<br>ios: chevron.left; android: AutoMirrored.Rounded.KeyboardArrowLeft (PLATFORM)<br>ios: ellipsis; android: Rounded.MoreHoriz (PLATFORM)<br>“more” (SOURCED) | header: ‹, album name, ••• circle | SocialCenteredHeader + HeaderCircleMenu |
| matched | `week.recap.count.picsColumns`<br>`week.recap.dimension.picsGap`<br>`week.recap.aspectRatio.picsTile`<br>`photo.viewer.a11y.photo` | 3 (CAPTURED)<br>1 pt (CAPTURED)<br>width: 131; height: 175 (CAPTURED)<br>“{name}’s pic, {date}” (SOURCED) | grid in position order | WeekPicsGrid; tap → viewer (album order) |
| matched | `albums.view.menu.rename`<br>`icon.global.edit`<br>`albums.view.rename.title`<br>`week.edit.save` | “rename” (SOURCED)<br>ios: pencil; android: Rounded.Edit (PLATFORM)<br>“rename album” (SOURCED)<br>“save” (SOURCED) | rename (every member) | name sheet; optimistic rename, rolled back with week.edit.error.save on failure (unit-tested) |
| matched | `albums.view.menu.delete`<br>`photo.viewer.icon.delete`<br>`albums.view.delete.title`<br>`albums.view.delete.message`<br>`albums.view.delete.confirm`<br>`photo.viewer.delete.cancel` | “delete album” (SOURCED)<br>ios: trash; android: Rounded.Delete (PLATFORM)<br>“delete this album?” (SOURCED)<br>“the pics stay in your group — only the album goes away.” (SOURCED)<br>“delete” (SOURCED)<br>“cancel” (SOURCED) | delete (creator / admins) with confirmation | confirmationDialog → delete_album → pop + toast |
| matched | `albums.view.toast.renamed`<br>`albums.view.toast.deleted` | “album renamed” (SOURCED)<br>“album deleted” (SOURCED) | toasts | shared ToastCenter |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `groups.create.size.hud`<br>`groups.create.color.hud`<br>`groups.create.fontSize.hudLabel`<br>`chat.thread.radius.loadingHud`<br>`groups.create.hud.loading` | 100 pt (SOURCED)<br>#0C0C0C (SOURCED)<br>15 pt (SOURCED)<br>10.5 pt (SOURCED)<br>“Loading” (SOURCED) | loading | HUD only when nothing is cached |
| matched | `albums.view.empty.title`<br>`albums.view.empty.detail` | “nothing left in this album” (SOURCED)<br>“pics taken down by the people who shared them leave albums too” (SOURCED) | empty / not found | EmptyStateView |
| matched | `albums.list.error.title`<br>`chat.thread.error.detail`<br>`chat.thread.error.retry` | “couldn’t load your albums” (SOURCED)<br>“check your connection and try again — your pics are safe” (SOURCED)<br>“try again” (SOURCED) | error | EmptyStateView + retry |
| matched | `week.edit.error.albumName` | “give your album a name” (SOURCED) | rename with an empty name | inline line |
