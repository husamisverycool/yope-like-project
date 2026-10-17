# camera.trim — a library video trimmed to the length a post may hold

**Short videos.** The camera stops a recording at `camera.capture.duration.videoMax` (10 s, Locket's "Record up to 10
seconds"). A video picked from the library (camera.capture's library circle) whose length, in whole seconds as the apps
show it ("0:10" = 10,000–10,999 ms), is longer goes through a trimmer before `camera.sendto`. **The server enforces the
same limit** (`app_config.video_max_ms`, migration 0029): `create_post` refuses a longer video (`video_too_long`) and
the worker cuts the stored video to the limit when it transcodes, writing the real length into `media.duration_ms` —
a client that skips this screen still never posts a longer video.

**Mechanics.** Retro's composer trims videos ("Trim Video", its Android `video_editor_*` strings) and refuses a video it
cannot take ("Video too long" / "Please select a video under %1$s"). **iOS** uses the system trimmer
(`UIVideoEditorController`, PLATFORM: "an editing interface for trimming video", `videoMaximumDuration`). **Android** has
no system trimmer: the screen below is composed of existing components and Material 3's range slider (PLATFORM) with
Retro's editor wording. Token: `camera.trim.layout.screen`. Copy: `camera.trim.*`, `camera.capture.videoTooLong.*`.

## References

| id | file / URL | used for |
|---|---|---|
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | "Trim Video", "Done", "Cancel", "%1$s – %2$s (%3$s)", "Video trim timeline", "Start / End one second earlier / later", "Play", "Pause", "Error loading video…", "Retry", "Video too long", "Please select a video under %1$s" |
| UIK | https://developer.apple.com/documentation/uikit/uivideoeditorcontroller | iOS: the system trimmer, `videoMaximumDuration`, `canEditVideo(atPath:)` |
| M3 | https://m3.material.io/components/sliders/overview ("Range sliders") | Android range control |
| LK | `design/research/locket.md` §10 ("Longer videos / Record up to 10 seconds") | the limit |

## Structure (Android; iOS shows the system trimmer)

Full screen over the camera, media surface (`color.global.backgroundDeep`, dark appearance), edge to edge with the
system bars' insets:
1. **Header** — C-29 `SheetHeader`: leading `camera.trim.cancel`, title `camera.trim.title` (text role `sheetTitle`),
   trailing `camera.trim.done` (text buttons in the platform primary; disabled while the clip is written or when the
   video cannot load).
2. **Video** — the picked video, aspect-fit in the space between the header and the slider, playing the chosen range in
   a loop (a preview, as the system trimmers do), sound at the media volume; tap = play / pause.
3. **Range** — `size.global.screenMargin` below the video, inside `size.global.screenMargin`: Material 3 `RangeSlider`
   (default colours) over the whole video. It opens on the first `camera.capture.duration.videoMax`; the range is at most
   the limit and at least one second (Retro's steps are one second); dragging one end past the limit moves the other.
4. **Range line** — `camera.trim.range` ("0:12 – 0:22 (0:10)"; times in `chat.voice.layout.durationFormat`), text role
   `listSubtitle`, `color.global.textSecondary`, centred, first baseline `size.global.sectionHeaderToContent` below the
   slider, `size.global.screenMargin` above the bottom inset.

**Done** writes the range as an MP4 with Media3 Transformer (on the device) and opens `camera.sendto` with it.

## States

| state | what shows | copy |
|---|---|---|
| ready | as above | — |
| writing the clip | C-28 `BusyOverlay` on the video; header actions and slider disabled | `camera.trim.a11y.busy` ("Trimming…", `retro.voice.progress`) |
| video cannot load (Android) | `camera.trim.error.load` (text role `body`, `color.global.textSecondary`) and `camera.trim.error.retry` (text button) centred in the video area; Done disabled | APK-S |
| cannot trim (iOS: `canEditVideo` false or the trimmer failed; Android: the clip could not be written) | native alert: `camera.capture.videoTooLong.title` / `.message` ({duration} = the limit in words, platform formatter: "10 seconds") / `.dismiss`; back to the camera | Retro verbatim |
| cancelled | back to the camera, the picked copy deleted | — |
| empty / offline / permission | not applicable (a local file; the system picker needs no permission) | — |

## Motion

None of its own: the screen appears over the camera without a transition (Android) / the system's full-screen
presentation (iOS). The preview loop is video playback, not interface motion; it stops on tap.

## Haptics

| interaction | token |
|---|---|
| header buttons, play / pause (Android) | `haptic.global.tap` |
| the range passes a whole second while dragging (Android) | `haptic.global.select` (Retro: "dial / scrubber … video trim") |

## Accessibility

- Android: the slider is labelled `camera.trim.a11y.timeline` with the platform's per-thumb values, plus custom actions
  `camera.trim.a11y.startEarlier` / `.startLater` / `.endEarlier` / `.endLater` (one-second steps, Retro's own actions);
  the video's click label is `camera.trim.a11y.play` / `.pause`; the busy indicator reads `camera.trim.a11y.busy`.
- iOS: the system trimmer's own accessibility.
- Font scale: the header, range line and error text use text roles (scale); the slider keeps the platform size.
- Contrast: `color.global.textSecondary` on `color.global.backgroundDeep` 7.37:1 (dark), passes; slider colours are the
  platform's.

## Platform notes

- iOS: `CameraCaptureModel.didPick` → `trimming` → `.fullScreenCover` with `VideoTrimmer` (`UIVideoEditorController`,
  `videoMaximumDuration = camera.capture.duration.videoMax`, `videoQuality = .typeHigh`); the export is copied out of the
  editor's folder; its length is measured again before send-to.
- Android: `CameraViewModel.onPicked` → `UiState.trim` → `VideoTrimRoute` (ExoPlayer preview, `RangeSlider`, Media3
  Transformer `ClippingConfiguration`); `onTrimmed` measures the clip and hands it to `camera.sendto`.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| Retro's own trimmer layout (thumbnail strip, handles) | not captured: Android draws Material 3's range slider instead | one screenshot of Retro's "Trim Video" editor |
