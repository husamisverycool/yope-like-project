# Running costs (worker)

What the worker spends per job, measured or estimated on 2026-10-15 with
`cd backend/worker && npm run measure:costs` (`scripts/measure-costs.ts`). Re-run it after changing
the recap prompt, the model, or the tribute design tokens.

Machine: 4 vCPU Intel Xeon @ 2.80 GHz container, ffmpeg 6.1 (the image ships Debian's ffmpeg 5.1;
same libx264), sharp 0.35.5 / libvips 8.18.

## 1. AI: weekly recap (one `recap.generate` job per group per week)

Model `claude-opus-5-5` (env `RECAP_MODEL`), $4 per million input tokens, $20 per million output
tokens (cache reads $0.20, 5-minute cache writes $5; claude-api skill, "Migrating to Claude Opus
5.5"). Effort `low`, structured JSON output, server-side refusal fallback `"default"` (a fallback
attempt, if any, is priced at its own model's rates: Claude Opus 5 / Opus 4.8 at $5 / $25).

**These token counts are ESTIMATES.** No `ANTHROPIC_API_KEY` was available, so input tokens were
estimated from the prompt size (characters ÷ 3, deliberately on the high side for compact JSON),
not counted by the API. With a key, the same script counts them with `messages.countTokens`.
Output = the chosen references (≈ 3 tokens each) + one line of text + adaptive thinking at effort
`low` (not measurable without the API; budgeted here at 1,000 tokens; `max_tokens` is 8,000).

| mocked week (same request the worker sends) | photos | prompt chars | input tokens (est.) | output tokens (est.) | cost per job (est.) |
|---|---|---|---|---|---|
| 5 members, everyone answers daily, 2 more photos a day | 49 | 7,105 | ≈ 2,400 | ≈ 1,200 | **≈ $0.033** |
| 30 members, 20 answers a day, 15 more photos a day | 245 | 29,577 | ≈ 9,900 | ≈ 1,800 | **≈ $0.075** |

Per group: ≈ 4.3 recaps a month → **≈ $0.14 – $0.32 per group per month**; a group with no
photos that week gets no recap job. The real figures are logged per job: every model attempt is a
row in `ai_cost_log` (`job_id`, `group_id`, `model`, `input_tokens` incl. cache, `output_tokens`,
`cost_usd`):

```sql
select date_trunc('month', created_at) as month, count(distinct job_id) as jobs,
       sum(input_tokens) as input_tokens, sum(output_tokens) as output_tokens, sum(cost_usd) as usd
from public.ai_cost_log where purpose = 'recap' group by 1 order by 1 desc;
```

Without `ANTHROPIC_API_KEY` recaps cost nothing (deterministic order + the template text).

## 2. CPU: tribute videos (`tribute.render` / `tribute.rerender`)

The tribute's timings and frame size come from design tokens that are not all sourced yet
(`layout.birthday.tribute.video`, `duration.birthday.tribute.photoHold`, …; COPY_KEYS.md). The
measurement used these **measurement inputs only**: 1080×1920 at 30 fps, title 1.3 s (the
VidDay-sourced value) + 0.6 s crossfade, 3 s per contribution, 2 s end card, hard cuts. Cost scales
with video length × frame size. (The canonical `layout.birthday.tribute.video` that landed later the
same day is 1920×1080 at 29.97 fps: the same pixel count, so the per-second figures hold; its
canonical 10 s end card adds ≈ 8 s of video, ≈ 15 CPU-seconds, to each row.)

| contributions | video length | ffmpeg CPU (user + sys, from `-benchmark`) | worker process CPU (cards, sharp) | wall time (4 vCPU) | MP4 size |
|---|---|---|---|---|---|
| 5 | 18.9 s | **39 s** | 1.6 s | 20 s | 0.22 MB |
| 15 | 48.9 s | **88 s** | 3.4 s | 39 s | 0.48 MB |
| 29 (a full group) | 90.9 s | **154 s** | 6.5 s | 68 s | 0.90 MB |

≈ 1.7–2.1 CPU-seconds per second of video, almost all of it H.264 encoding (x264, default preset,
`-tune stillimage`; each card is decoded once and repeated in the filter graph). At most one
tribute per member per year per group, so even a busy deployment renders a few a day; a re-render
happens only when a contribution is withdrawn or its photo deleted. On the recommended 1 vCPU
worker a full-group tribute takes ≈ 2.5 minutes of CPU and can delay other heavy-lane jobs
(renditions, collages) by that much.

## 3. CPU: other jobs (measured the same way)

| job | CPU | output |
|---|---|---|
| `media.renditions`, 12 MP JPEG → thumb / widget / display | 0.5–0.6 s | ≈ 5 / 13 / 17 KB for a flat test image (real photos are larger) |
| `media.renditions`, premium video (10 s synthetic 1080p30 test clip → H.264/AAC MP4) | 32 s (≈ 3.2 CPU-s per second of video; 12 s wall on 4 vCPU) | MP4 + poster; real footage varies with motion and resolution |
| `collage.compose`, 5 answers (option B, 1 page) | 0.9 s | master PNG + display / share / widget JPEG |
| `collage.compose`, 30 answers (option B, 3 pages) | 2.8–3.4 s | 3 pages |
| `push.*`, `widget.refresh`, `invitation.*` | milliseconds (HTTP/2 requests) | — |

## 4. Third-party services the worker calls

| service | cost |
|---|---|
| APNs (alerts, background, Live Activity, WidgetKit, broadcast channels) | free (Apple Developer Program) |
| FCM HTTP v1 | free |
| Anthropic API | section 1 |
| Supabase Storage | per GB stored / transferred on the owner's plan; the worker adds per photo three JPEG renditions (+ two for a dual capture), per collage one PNG master + JPEG pages, per tribute one MP4 + poster |
