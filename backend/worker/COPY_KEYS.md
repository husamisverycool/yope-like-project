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
| `notifications.push.reaction.body` | `{name}`, `{emoji}`, `{group}` | `notifications.push` | Body of the reaction notification (Locket `notifications.push.reaction.inApp.reference` pattern). Never a number. |
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
| `birthday.tribute.endCard` | `{group}` | `birthday.tribute` | End card of the video. Not found in the research (design/research/wrapped-tribute-partiful.md §4.5). |

Each contribution card shows the contributor's first name and their own line (user content, not copy).

## Design tokens the worker reads

Read by name at runtime (`src/tokens.ts`: canonical `design/tokens.json`, then non-BLOCKED
proposal values). A missing token fails the job with `missing design token <name>`.

### Tribute video (`src/tribute/render.ts`)

| token | shape | status today |
|---|---|---|
| `layout.birthday.tribute.video` | `{ "width": px, "height": px, "fps": n }` | missing |
| `duration.birthday.tribute.titleHold` | ms | proposal 1300 (VidDay, lower bound) |
| `duration.birthday.tribute.titleCrossfade` | ms | proposal 600 (VidDay) |
| `duration.birthday.tribute.photoHold` | ms | BLOCKED (not found) |
| `duration.birthday.tribute.clipTransition` | ms, 0 = hard cut | proposal 0 (Tribute) |
| `duration.birthday.tribute.endTransition` | ms, 0 = hard cut | missing |
| `duration.birthday.tribute.endHold` | ms | missing |
| `color.birthday.tribute.pillarbox` | `#RRGGBB` | proposal `#000000` (Tribute) |
| `layout.birthday.tribute.titleCard` | `{ background, textColor, fontWeight, fontSizeRatio, maxWidthRatio, centerYRatio }` (ratios of video height/width) | missing |
| `layout.birthday.tribute.endCard` | same as titleCard | missing |
| `layout.birthday.tribute.caption` | `{ textColor, nameFontWeight, nameFontSizeRatio, lineFontWeight, lineFontSizeRatio, leftRatio, bottomRatio, maxWidthRatio, gapRatio, scrim? }` | missing (research §4.5: "per-contribution layout with name + one line over a photo" not found) |

The font is Roboto (vendored in `fonts/`, Apache 2.0, level PLATFORM); weights map to the
nearest of Thin/Light/Regular/Medium/Bold/Black.

### Collage and media

| token | used for | status today |
|---|---|---|
| `layout.collage.dualTile`, `layout.collage.option{A,B,C}`, `color.collage.matte`, `color.collage.insetBorder` | collage composition (`src/collage/params.ts`) | proposals (collage.tokens.json) |
| `dimension.collage.share.storyCanvas` | collage width and the 9:16 share image | proposal 1080×1920 (platform) |
| `layout.media.renditions` | thumb / widget / display sizes `{ thumb|widget|display: { width, height, fit } }` | missing → derived sizes in `src/media/renditions.ts` (iOS widget sizes @3x) |
