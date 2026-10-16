# Overnight photos and the weekly question — what the backend needs (data note)

Draft, 2026-10-16. Design evidence: `design/research/overnight-and-questions.md` (OQ). Surfaces:
`design/surfaces/camera.overnight.md`, `design/surfaces/question.weekly.md`. Names below extend `docs/API.md`; nothing
here is implemented. Design values (09:00, the copy keys) are SOURCED in OQ; numbers marked *engineering* are not
design values.

## 1. Overnight posts — columns and `create_post`

`posts` (API §5.8) gains:

| column | type | notes |
|---|---|---|
| `reveal_at` | timestamptz? | null = an ordinary post. Set only by `create_post` when `p_develop = true`: the **first 09:00 after `p_captured_at` in that group's `groups.time_zone`** (wall clock, so DST-safe). One value per post row, so a photo sent to two groups in different zones reveals at each group's own 09:00 |
| `revealed_at` | timestamptz? | set by the reveal job (§4); used for the push and the "revealed this morning" viewer query, never for visibility |

`create_post` gains `p_develop boolean = false` and `p_captured_at timestamptz = null`:

- `p_develop = true` requires `media.kind = 'photo'` (`develop_photo_only`; no Live Photo motion, no video — OQ O-11),
  no caption, voice note, invitation or reply (`develop_options_not_allowed`).
- `p_captured_at` (required with `p_develop`): the device's capture time, so a photo taken offline at 08:50 and uploaded
  at 10:00 still belongs to the 09:00 reveal. Rejected if in the future (+ *engineering* clock skew) or older than an
  *engineering* bound (`invalid_captured_at`). If its computed `reveal_at` is already past at insert, the post is
  created revealed (`reveal_at = captured`, OQ: "reveals on arrival") and joins the next reveal push only if that push
  has not been sent yet.
- For develop posts `created_at := p_captured_at`, so the strip, weeks (`week_start`) and paging place the photo at
  capture time once visible (Dispo dates photos by capture, DLIB "March 1").
- Jobs: `media.renditions` as today (service role; renditions exist before the reveal but are unreadable, §2).
  **Not** enqueued for develop posts: `push.new_post`, `widget.refresh`, and the chat `photo` message. Enqueue one
  `overnight.reveal` job per `(group_id, reveal_at)` (idempotent key).
- `app_config`: `overnight_reveal_local_time` = `"09:00"` (public; source Dispo, OQ O-1).

## 2. Who can see a developing photo: nobody

The author included. Enforced on the server, not by the client:

- `posts` read policy adds `and (reveal_at is null or reveal_at <= now())` for **every** reader — no author exception.
- `media` read policy (owner, or a member of a group with a visible post): the owner branch also requires that the
  media is not develop-only-and-unrevealed (e.g. `media.develop_until timestamptz?`, the earliest `reveal_at` of its
  posts, null for ordinary media).
- Storage: signed URLs under `u/<owner>/<media_id>/…` are issued only when the `media` row is readable; the same
  function guards renditions and `widget_path`.
- Realtime `postgres_changes` inserts are filtered by RLS, so a develop insert reaches nobody (no count leak).
- Clients never save a develop photo to the system photo library before its reveal (camera.overnight Platform notes);
  the local file is deleted after upload.

## 3. Developing status without a number

The UI shows one tile per group and never a count or a name (OQ O-6, F-1). Two SECURITY DEFINER reads return only a
boolean and a time:

- `group_developing(p_group_id) → (developing boolean, reveal_at timestamptz)` — members only.
- `my_developing() → (developing boolean, reveal_at timestamptz)` — for the camera's stack (when built).

No endpoint returns the number of developing posts or their authors.

## 4. The reveal job `overnight.reveal (group_id, reveal_at)`

At `reveal_at`:
1. Set `revealed_at = now()` on the group's posts with that `reveal_at` (visibility is already time-based).
2. Create the chat `photo` messages for those posts now (Lapse 2021 sent developed photos into the group chat, TC21) —
   **lead decision**; the alternative is no chat message for develop posts.
3. Broadcast `overnight_revealed {group_id, reveal_at}` on the private channel `group:<id>`; clients refetch posts.
4. One push per member of the group — not muted (`group_members.muted`), notification switch `overnight` on (new column
   `notification_settings.overnight boolean default true`), quiet hours → passive / silent. Copy keys
   `camera.overnight.push.title` ({group}) / `.push.body`; payload `type = overnight_revealed`, `group_id`, `reveal_at`.
   Never per photo, never with a count.
5. `widget.refresh` for the group.

Late uploads after step 4 are visible on arrival and refresh the group by the existing insert channel; no second push.

## 5. Weekly question — records

| table / column | fields | notes |
|---|---|---|
| `group_questions` | `id` uuid, `group_id` uuid, `week_start` date (group-local, `week_start_isodow`), `question_key` text (e.g. `q01` → copy `question.weekly.q01`), `created_at` | unique `(group_id, week_start)`; read: members. Created lazily by `current_group_question` or by a weekly job at week start — **no push** (OQ Q-5) |
| `group_question_hides` | `group_question_id`, `user_id`, `created_at` | own rows only; "Remove" (Apple) hides the card for one member for that week |
| `groups.weekly_question` | boolean | the group switch; **default: lead decision (BLOCKED)** |
| `app_config.weekly_question_keys` | text[] | the ordered catalogue of copy keys; **rotation rule: lead decision (BLOCKED)** (Retro cycles its 8 prompts in order) |

`current_group_question(p_group_id) → (id, question_key, week_start, hidden_by_me boolean)` — members only; null when the
switch is off.

## 6. Answers are posts

- `posts.question_id uuid?` → `group_questions.id` (on delete set null).
- `create_post(…, p_question_id uuid = null)`: set only on the post row whose `group_id` is the question's group; other
  groups in the same call get null. Errors: `invalid_question` (unknown / other group), `question_closed` (outside its
  week, group time zone), `question_off` (switch off). Allowed together with `p_develop` (the answer then develops at
  09:00) — the camera drops the question when 9 AM is chosen, so this is an API allowance only.
- More than one answer per member is allowed.
- Viewer: `posts where question_id = X order by created_at asc`; card: the newest one.
- No aggregate endpoint: nothing returns how many answered, who answered or who has not. (A client can count the rows
  it reads; the UI never shows such a number — OQ Q-7.)

## 7. Existing behaviour that applies unchanged

Blocks hide a blocked author's revealed and answer posts as today. Deleting a post / media / account removes develop
posts too (author can delete only after the reveal, because before it the post is unreadable to them — OQ F-2).
Reports work on revealed posts only. Daily invitations: a develop post never carries `invitation_id` (§1).

## 8. Open decisions for the lead

1. Chat messages for revealed photos: at reveal, or never (§4.2).
2. A "delete everything still developing" action (OQ F-2) — no reference.
3. Weekly question: default on / off for new groups; rotation rule; whether old answers show their question anywhere.
4. Edge at 08:59 (reveal one minute later vs the next day) — Dispo's text supports "first 09:00 after capture".
