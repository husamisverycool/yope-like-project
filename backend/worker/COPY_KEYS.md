# Worker copy keys and design tokens

The worker sends text to people (push notifications, the recap fallback text, the tribute video
cards). Every string comes from `design/copy.json` through `node tools/designgen.mjs` →
`backend/worker/src/generated/copy.ts` (docs/CONVENTIONS.md §5). Until a key exists, the job that
needs it fails with `MissingCopyError` and is retried with backoff; nothing is sent with
invented text. Source of truth for this list: `WORKER_COPY_KEYS` in `src/copy.ts` (a test checks
that this file names every key and placeholder).

Placeholders the worker fills (use only the ones listed for each key; any other placeholder fails
the job as a contract error):

| placeholder | value |
|---|---|
| `{name}` | a person's first name (first word of `display_name`) — the poster, the replier, the reactor, or the birthday person |
| `{group}` | the group's name |
| `{emoji}` | the reaction emoji |
| `{message}` | the text of a chat reply (shortened only if the push would exceed APNs' 4 KB) |

Rules from the tenets for every string here: no counts, no streaks, no "late", no guilt or
nagging, no urgency (docs/CONVENTIONS.md §6, docs/SPEC_FLAGS.md T4/T5).

## Push notifications (`notifications.push`, `daily.notification`)

Each notification has a title and a body (Android requires a title; iOS shows both).

| key | placeholders | surface | meaning |
|---|---|---|---|
| `notifications.push.dailyInvitation.title` | `{group}` | `daily.notification` | Title of the daily same-moment invitation: iOS Live Activity start alert, iOS alert when Live Activities are off, Android ongoing countdown notification. |
| `notifications.push.dailyInvitation.body` | `{group}` | `daily.notification` | Body of the daily invitation. BeReal's wording minus its urgency (bereal.copy.json `daily.notification.*.reference`). |
| `notifications.push.newPost.title` | `{name}`, `{group}` | `notifications.push` | Someone in the group posted a photo. |
| `notifications.push.newPost.body` | `{name}`, `{group}` | `notifications.push` | Body of the new-photo notification (Locket pattern `notifications.push.newPost.body.single`, without counts). |
| `notifications.push.reaction.title` | `{name}`, `{emoji}`, `{group}` | `notifications.push` | Someone reacted to your photo. Repeated reactions to one photo replace each other on the device. |
| `notifications.push.reaction.body` | `{name}`, `{emoji}`, `{group}` | `notifications.push` | Body of the reaction notification (`messaging.reaction` content pattern, design/copy-patterns.md). Never a number. |
| `notifications.push.reply.title` | `{name}`, `{group}` | `notifications.push` | Someone replied to your photo or your message. |
| `notifications.push.reply.body.text` | `{name}`, `{group}`, `{message}` | `notifications.push` | Body of a text reply. |
| `notifications.push.reply.body.voice` | `{name}`, `{group}` | `notifications.push` | Body of a voice-message reply. |
| `notifications.push.reply.body.photo` | `{name}`, `{group}` | `notifications.push` | Body when someone answers your photo with a photo. |
| `notifications.push.recapReady.title` | `{group}` | `notifications.push` | The group's weekly recap is ready. |
| `notifications.push.recapReady.body` | `{group}` | `notifications.push` | Body of the recap-ready notification. |
| `notifications.push.birthdayRequest.title` | `{name}`, `{group}` | `notifications.push` | Private request to contribute a photo and a line to `{name}`'s birthday tribute. Never sent to `{name}`. Sent once, no reminders. |
| `notifications.push.birthdayRequest.body` | `{name}`, `{group}` | `notifications.push` | Body of the request (wrapped-tribute-partiful.copy.json proposes `notifications.push.birthdayRequest` as one string; split here into title/body). |
| `notifications.push.tribute.title` | `{group}` | `notifications.push` | To the birthday person: the tribute their group made is ready. |
| `notifications.push.tribute.body` | `{group}` | `notifications.push` | Body of the tribute-for-you notification. No number of contributors. |

Not sent (no type in the shared push contract, or not in the brief): ordinary chat messages that
are not replies; "year story ready" (`year_story` exists in the contract but the brief does not
list it — owner decision).

## Weekly recap (`week.recap`)

| key | placeholders | surface | meaning |
|---|---|---|---|
| `week.recap.template` | `{group}` | `week.recap` | Recap text used when no AI text is available (no `ANTHROPIC_API_KEY`, refusal, API error) or when the AI text fails the copy rules. One line, lowercase, second person (the recap voice). |

The AI-drafted text is checked against the recap voice pattern. When `design/copy-patterns.md`
gains a fenced block tagged `recap-text-rules` (JSON with any of `lowercase`, `secondPerson`,
`maxSentences`, `maxChars`, `noDigits`, `banned`), those rules replace the minimum rules in
`src/recap/validate.ts` (lowercase, second person, one sentence, no digits, no count / streak /
guilt words).

## Tribute video (`birthday.tribute`)

| key | placeholders | surface | meaning |
|---|---|---|---|
| `birthday.tribute.titleCard` | `{name}` | `birthday.tribute` | Title card at the start of the video (`{name}` = the birthday person). Proposed in wrapped-tribute-partiful.copy.json (VidDay pattern P-BT-1). |
| `birthday.tribute.endCard` | — | `birthday.tribute` | End card of the video ("We love you!", VidDay end card; MERGE_DECISIONS G2). |

Each contribution card shows the contributor's first name and their own line (user content, not copy).

## Design tokens the worker reads

Read by name at runtime (`src/tokens.ts`: canonical `design/tokens.json`, then non-BLOCKED
proposal values). A missing token fails the job with `missing design token <name>`.

### Tribute video (`src/tribute/render.ts`)

| token | shape | status (latest `designgen`, 2026-10-15) |
|---|---|---|
| `layout.birthday.tribute.video` | `{ "width": px, "height": px, "fps": n }` | canonical: 1920×1080 @ 29.97 |
| `duration.birthday.tribute.titleHold` | ms | canonical: 1167 |
| `duration.birthday.tribute.titleCrossfade` | ms | canonical: 600 |
| `duration.birthday.tribute.photoHold` | ms | canonical: 4000 (VidDay documented default) |
| `duration.birthday.tribute.clipTransition` | ms, 0 = hard cut | canonical: 0 |
| `duration.birthday.tribute.endTransition` | ms, 0 = hard cut | canonical: 0 |
| `duration.birthday.tribute.endHold` | ms | canonical: 10003 |
| `color.birthday.tribute.pillarbox` | `#RRGGBB` | canonical: `#000000` |
| `layout.birthday.tribute.titleCard` | `{ background, textColor, fontWeight, fontSizeRatio, maxWidthRatio, centerYRatio }` (ratios of video height/width) | canonical |
| `layout.birthday.tribute.endCard` | same as titleCard | canonical (VidDay: end card in the title-card style) |
| `layout.birthday.tribute.caption` | `{ textColor, nameFontWeight, nameFontSizeRatio, lineFontWeight, lineFontSizeRatio, leftRatio, bottomRatio, maxWidthRatio, gapRatio, scrim? }` | canonical (Tribute "Name badges": bottom-left, dark band) |

All tribute tokens are canonical. If one goes missing, `tribute.render` fails with
`missing design token …` and is retried; no tribute is delivered.

Card text is set in the app's faces (vendored in `fonts/`, SIL OFL, `fonts/SOURCE.txt`): title and end cards in Roboto
Serif Headline, captions in Inter (weights map to the nearest of the vendored 400 / 600). Names and lines in other scripts
and emoji come from the fallback fonts of `../../fonts/fallback/` (Noto, SIL OFL; colour emoji via Noto Color Emoji
COLRv1) through `fonts/fonts.conf` — see `fonts/fallback/SOURCE.txt`.

### Collage and media

| token | used for | status today |
|---|---|---|
| `daily.dualimage.layout.composition` | each answer tile (mainAspect → tileAspect, insetAspect, insetWidthRatio, insetMarginRatio, insetBorderRatio, insetOuterRadiusRatio; mainRadiusRatio unused: tiles touch) | canonical (capture.json) |
| `collage.view.layout.page` | option B pages (columns, rowsPerPage, gapRatio, outerRadiusRatio, canvasAspect) and the collage width (canvasWidthPx) | canonical (capture.json) |
| `color.global.backgroundDeep` | matte (page corners, empty cells in the JPEGs) and the inset border | canonical (global.json) |
| `collage.share.layout.export` | the 9:16 share image (widthPx × heightPx) | canonical (capture.json) |
| options A and C | none in production: `collage_option` 'A' / 'C' fails with `MissingTokenError`; their proposals `layout.collage.option{A,C}` are read only by `scripts/render-collage-options.ts` | proposals only (C-21) |

The collage reads these through `canonicalToken` (`src/tokens.ts`): no proposal fallback.
| `layout.media.renditions` | thumb / widget / display sizes `{ thumb|widget|display: { width, height, fit } }` | missing → derived sizes in `src/media/renditions.ts` (iOS widget sizes @3x) |
