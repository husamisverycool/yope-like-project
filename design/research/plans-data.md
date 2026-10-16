# Plans — data note (for the backend)

Draft, 2026-10-16. Companion to `design/research/plans.md` (evidence) and the draft specs `design/surfaces/plans.create.md`,
`plans.page.md`, `widget.countdown.md`. Written in the style of `docs/API.md` §4–§6 so the migration, RLS and RPCs can be
built from it; nothing here is in `docs/API.md` yet.

## Enums

| Enum | Values | Evidence |
|---|---|---|
| `plan_answer` | `going`, `maybe`, `cant_go` | Partiful "Going" / "Maybe" / "Can't Go" (help 15525363, RSVP sheet `partiful/web/pf-web-public-light-rsvp-sheet.png`); Apple "Going, Not Going, or Maybe" |
| `plan_status` | `active`, `canceled` | Apple "Cancel Event or Restore Event" (cancel is reversible); no delete in v1 (`plans.md` §8) |

"No answer" is the **absence** of a row, never a stored state (it is never shown; tenet 5).

## Tables

### `plans`

Read: members of `group_id` (RLS as `posts`). Written by RPCs only.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `group_id` | uuid | FK `groups` |
| `created_by` | uuid? | the maker; null once that account is deleted (as `groups.created_by`) |
| `title` | text | 1–80 chars after trimming (`invalid_name` limit used for groups / albums) |
| `starts_at` | timestamptz | the instant the plan starts; for an all-day plan, 00:00 of `local_date` in the group time zone |
| `all_day` | boolean | Apple "whether it's an all-day event" |
| `local_date` | date | the plan's day in `groups.time_zone`, fixed at create / edit (drives the album, the widget's day count and the answer lock) |
| `place` | text? | free text, 1–200 chars; **never coordinates**; no geocoding (the app never collects location) |
| `note` | text? | 1–2,048 chars (WhatsApp's event description limit, faq.whatsapp.com/3313983622238973 — lead file 21 [V], not re-fetched) |
| `cover_path` | text? | storage path, square crop (Partiful cover guideline 1:1, help 15525294) |
| `status` | plan_status | default `active` |
| `canceled_at`, `canceled_by` | timestamptz?, uuid? | set by `cancel_plan`, cleared by `restore_plan` |
| `album_id` | uuid? | set when the album is collected (below) |
| `created_at`, `updated_at` | timestamptz | |

Indexes: `(group_id, local_date)`; `(group_id, starts_at) where status = 'active'` for "next plan".

### `plan_answers`

Read: members of the plan's group, **filtered**: rows with `answer in ('going','maybe')` are visible to every member; a
`cant_go` row is visible only to its own `user_id` and to `plans.created_by` (Partiful: "Guests also cannot see who
RSVP'd "Can't Go."", help 15525438). Written by `answer_plan` only.

| Column | Type | Notes |
|---|---|---|
| `plan_id`, `user_id` | uuid | primary key; `user_id` must be a member of the plan's group |
| `answer` | plan_answer | replaces the previous answer (Partiful: "it will replace your previous RSVP") |
| `answered_at` | timestamptz | ordering of names in a list (oldest first); **never sent as a timestamp to other members** (no activity log) |

No count column, view or aggregate is exposed to clients (SPEC_FLAGS T2 / T7 rule: no number reaches a client).

### Album

A plan's album is an ordinary `albums` row (docs/API.md §5.15) with one new nullable column `albums.plan_id uuid` (unique),
so `albums.list` / `albums.view` show it with no new client code. Its name is the plan's title (renamed with it).

## RPCs

| RPC | Who | Does | Errors |
|---|---|---|---|
| `create_plan(group_id, title, starts_at, all_day, place?, note?, cover_path?)` | any member | inserts `plans`, computes `local_date`; enqueues the "new plan" push (below) | `not_group_member`, `invalid_name`, `invalid_date` (starts before today in the group time zone) |
| `update_plan(plan_id, …same fields…)` | maker or group admin; only while `local_date >= today` | updates; if `starts_at`, `all_day` or `place` changed, enqueues one "changed" push | `not_allowed`, `plan_past`, `plan_canceled` |
| `answer_plan(plan_id, answer)` | any member; only while `status = 'active'` and the plan's day has not ended (lock time BLOCKED, `plans.md` §12 item 3) | upsert `plan_answers` | `not_group_member`, `plan_canceled`, `plan_past` |
| `clear_answer(plan_id)` | the member | deletes their row (back to no answer) | same |
| `cancel_plan(plan_id)` / `restore_plan(plan_id)` | maker or group admin | sets / clears `status`, `canceled_*`; cancel enqueues one push; restore sends none (Apple documents no restore notice) | `not_allowed`, `plan_past` |
| `next_plans(group_id?)` | member | upcoming `active` plans (`local_date >= today` in each group's zone), soonest first, with `title`, `starts_at`, `all_day`, `local_date`, `cover` signed URL, `group_id` — the widget's and the group screen's source | — |

Realtime: broadcast `group:<id>` events `plan_created`, `plan_updated`, `plan_canceled`, `plan_answered` (payload: ids
only; clients refetch), as for posts (docs/API.md §8).

## Jobs (worker)

| job | when | does |
|---|---|---|
| `plan_reminder` | `starts_at − 24 h` (Partiful Group Reminder: "24 hours before") ; skipped if the plan was created or moved to start less than 24 h ahead, or is canceled | one push to members whose answer is `going` or `maybe`; respects `group_members.muted` and quiet hours (silent delivery) |
| `plan_album_collect` | the end of `local_date` in the group time zone (boundary BLOCKED, `plans.md` §12 item 1) | creates the album (if any post exists) and inserts `album_items` for every post of the group with `created_at` inside that day, oldest first; idempotent; canceled plans are skipped (decision pending, `plans.md` §8) |
| widget refresh | on `plan_*` events | the app writes the next-plan snapshot to the App Group / Glance state (as `widget.home.small`); the widget itself re-renders at local midnight |

Push payloads carry `plan_id` and `group_id` for the deep link `DeepLink.plan(planID:)` → `plans.page`.

## Not stored (by design)

Guest counts; "+1" / additional guests; capacity, waitlist, approval; coordinates, maps or weather; RSVP notes (Apple's
optional note is not in the v1 brief); reminder preferences per plan (the push is fixed, like Partiful's schedule); read
receipts of the plan; who viewed it.
