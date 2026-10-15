// Measures what docs/COSTS.md reports:
//   1. recap AI tokens and cost per job, for a realistic mocked week (the exact request the
//      worker sends: src/recap/ai.ts recapRequest). With ANTHROPIC_API_KEY set, input tokens are
//      counted by the API (messages.countTokens); without it they are estimated from the prompt
//      size, and the output says so.
//   2. ffmpeg + sharp CPU time per tribute video, rendered locally.
// Usage: npm run measure:costs
//
// The tribute timings and sizes below are measurement inputs only (the design tokens for the
// tribute video are not sourced yet); the cost scales with duration × frame size.

import Anthropic from "@anthropic-ai/sdk";
import path from "node:path";
import sharp from "sharp";
import { RECAP_SYSTEM_PROMPT, recapRequest, type RecapCandidate, type RecapInput } from "../src/recap/ai.js";
import { costUsd } from "../src/recap/pricing.js";
import { setTokenOverrides } from "../src/tokens.js";
import { renderTribute, tributeTokens, TRIBUTE_TOKEN_NAMES } from "../src/tribute/render.js";
import { WORKER_ROOT, DEFAULT_RECAP_MODEL } from "../src/config.js";
import { renderAll } from "../src/media/renditions.js";
import { composeCollage } from "../src/collage/pipeline.js";

const CAPTIONS = ["sunday lunch", "first coffee", null, "look who's here", "the view from work", null, "rain again", "made it", "tiny garden", null, "late train", "birthday cake for nobody in particular"];
const DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

function week(members: number, momentAnswersPerDay: number, otherPostsPerDay: number): RecapInput {
  const photos: RecapCandidate[] = [];
  const moments = DAYS.map((d, i) => ({ ref: `m${i + 1}`, local_time: `${d} ${String(10 + i).padStart(2, "0")}:${String((i * 7) % 60).padStart(2, "0")}`, answered_by_everyone: momentAnswersPerDay >= members }));
  let n = 0;
  DAYS.forEach((d, i) => {
    for (let a = 0; a < momentAnswersPerDay; a++) photos.push({ ref: `p${++n}`, local_time: `${d} ${String(10 + i).padStart(2, "0")}:${String(((i * 7) % 60) + 1).padStart(2, "0")}`, kind: "photo", caption: CAPTIONS[n % CAPTIONS.length] ?? null, reactions: (n * 7) % 5, moment: `m${i + 1}` });
    for (let o = 0; o < otherPostsPerDay; o++) photos.push({ ref: `p${++n}`, local_time: `${d} ${String(8 + o * 2).padStart(2, "0")}:15`, kind: n % 11 === 0 ? "live_photo" : "photo", caption: CAPTIONS[(n + 3) % CAPTIONS.length] ?? null, reactions: (n * 3) % 4, moment: null });
  });
  return { group_kind: "family", week: { from: "2026-10-05", to: "2026-10-11" }, photos, moments };
}

async function recapTokens(): Promise<void> {
  const model = process.env.RECAP_MODEL ?? DEFAULT_RECAP_MODEL;
  const cases: Array<[string, RecapInput]> = [
    ["small group: 5 members, everyone answers daily, 2 more photos a day", week(5, 5, 2)],
    ["full group: 30 members, 20 answers a day, 15 more photos a day", week(30, 20, 15)],
  ];
  const client = process.env.ANTHROPIC_API_KEY ? new Anthropic() : null;
  for (const [name, input] of cases) {
    const req = recapRequest(model, input);
    const promptChars = RECAP_SYSTEM_PROMPT.length + JSON.stringify(input).length + JSON.stringify(req.output_config).length;
    let inputTokens: number;
    let method: string;
    if (client) {
      const counted = await client.messages.countTokens({ model, system: req.system as string, messages: req.messages as Anthropic.MessageParam[] });
      inputTokens = counted.input_tokens;
      method = "counted by the API (messages.countTokens; the output schema adds a little)";
    } else {
      // ESTIMATE: no API key here. JSON with short keys, references and times tokenizes densely;
      // 3 characters per token is used as a conservative (high) estimate.
      inputTokens = Math.ceil(promptChars / 3);
      method = "ESTIMATED from prompt size (no ANTHROPIC_API_KEY): characters ÷ 3";
    }
    // output: the chosen references (≈ 3 tokens each, at most all photos) + one line of text,
    // plus adaptive thinking at effort low (not measurable without the API; budget bounded by max_tokens)
    const answerTokens = input.photos.length * 3 + 40;
    const thinkingLow = 1000;
    const outputTokens = answerTokens + thinkingLow;
    const cost = costUsd({ model, inputTokens, outputTokens, cacheReadTokens: 0, cacheWriteTokens: 0 });
    console.log(JSON.stringify({ case: name, photos: input.photos.length, prompt_chars: promptChars, input_tokens: inputTokens, input_method: method, output_tokens_estimate: outputTokens, cost_usd_estimate: cost }));
  }
}

async function tributeCpu(): Promise<void> {
  const w = 1080;
  const h = 1920;
  setTokenOverrides({
    [TRIBUTE_TOKEN_NAMES.video]: { width: w, height: h, fps: 30 },
    [TRIBUTE_TOKEN_NAMES.titleHoldMs]: 1300,
    [TRIBUTE_TOKEN_NAMES.titleCrossfadeMs]: 600,
    [TRIBUTE_TOKEN_NAMES.photoHoldMs]: 3000,
    [TRIBUTE_TOKEN_NAMES.clipTransitionMs]: 0,
    [TRIBUTE_TOKEN_NAMES.endTransitionMs]: 0,
    [TRIBUTE_TOKEN_NAMES.endHoldMs]: 2000,
    [TRIBUTE_TOKEN_NAMES.pillarbox]: "#000000",
    [TRIBUTE_TOKEN_NAMES.titleCard]: { background: "#000000", textColor: "#FFFFFF", fontWeight: 700, fontSizeRatio: 0.04, maxWidthRatio: 0.8, centerYRatio: 0.5 },
    [TRIBUTE_TOKEN_NAMES.endCard]: { background: "#000000", textColor: "#FFFFFF", fontWeight: 400, fontSizeRatio: 0.03, maxWidthRatio: 0.8, centerYRatio: 0.5 },
    [TRIBUTE_TOKEN_NAMES.caption]: { textColor: "#FFFFFF", nameFontWeight: 700, nameFontSizeRatio: 0.03, lineFontWeight: 400, lineFontSizeRatio: 0.025, leftRatio: 0.06, bottomRatio: 0.06, maxWidthRatio: 0.88, gapRatio: 0.01 },
  });
  for (const contributions of [5, 15, 29]) {
    const cards = [];
    for (let i = 0; i < contributions; i++) {
      const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1290" height="1720"><rect width="100%" height="100%" fill="hsl(${(i * 47) % 360},60%,50%)"/><circle cx="${300 + i * 20}" cy="${600 + i * 15}" r="400" fill="hsl(${(i * 47 + 180) % 360},60%,40%)"/></svg>`;
      cards.push({ image: await sharp(Buffer.from(svg)).jpeg().toBuffer(), name: `Person${i}`, line: "the summer we spent at the lake, and every sunday since" });
    }
    const before = process.cpuUsage();
    const t0 = Date.now();
    const v = await renderTribute(cards, { title: "Happy birthday, Lea!", end: "from Lima family" }, tributeTokens(), path.join(WORKER_ROOT, "fonts"));
    const sharpCpu = process.cpuUsage(before);
    console.log(JSON.stringify({
      tribute_contributions: contributions,
      frame: `${w}x${h}@30`,
      video_seconds: v.durationMs / 1000,
      ffmpeg_cpu_seconds: v.cpuSeconds,
      worker_process_cpu_seconds: Math.round(((sharpCpu.user + sharpCpu.system) / 1e6) * 100) / 100,
      wall_seconds: (Date.now() - t0) / 1000,
      mp4_mb: Math.round((v.mp4.length / 1e6) * 100) / 100,
    }));
  }
  setTokenOverrides(null);
}

function cpuSince(before: NodeJS.CpuUsage): number {
  const d = process.cpuUsage(before);
  return Math.round(((d.user + d.system) / 1e6) * 100) / 100;
}

async function mediaCpu(): Promise<void> {
  const photo = await sharp({ create: { width: 3024, height: 4032, channels: 3, background: "#4a7" } })
    .composite([{ input: Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="3024" height="4032"><circle cx="1500" cy="2000" r="1200" fill="#a47"/></svg>`) }])
    .jpeg({ quality: 90 })
    .toBuffer();
  let before = process.cpuUsage();
  const r = await renderAll(photo);
  console.log(JSON.stringify({ renditions_12mp_cpu_seconds: cpuSince(before), bytes: { thumb: r.thumb.length, widget: r.widget.length, display: r.display.length } }));
  const display = r.display;
  for (const n of [5, 30]) {
    const images = Array.from({ length: n }, () => ({ back: display, front: display }));
    before = process.cpuUsage();
    const t0 = Date.now();
    const files = await composeCollage(images, "B");
    console.log(JSON.stringify({ collage_answers: n, option: "B", pages: files.masters.length, cpu_seconds: cpuSince(before), wall_seconds: (Date.now() - t0) / 1000 }));
  }
}

await recapTokens();
await mediaCpu();
await tributeCpu();
