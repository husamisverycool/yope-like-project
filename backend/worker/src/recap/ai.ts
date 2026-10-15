// AI choice/order of a week's photos + recap text, with the Anthropic TypeScript SDK, following
// the claude-api skill:
//   - model from RECAP_MODEL (default claude-opus-5-5); thinking is always on for this model and
//     controlled by output_config.effort ("low");
//   - structured output: output_config.format = { type: "json_schema", schema };
//   - server-side refusal fallback opted in from day one: fallbacks: "default" with the beta
//     header server-side-fallback-2026-07-01 (Claude Opus 5.5 "Safeguards");
//   - stop_reason "refusal" is checked before reading content; then the deterministic path is used;
//   - usage per attempt from usage.iterations (fallback attempts bill at their own model's rates).
// Only the group's own content is sent: per-photo short references (p1, p2, …), local capture
// times, captions, kind, reaction totals and which daily moments everyone answered. No names, no
// ids, no other group.

import type Anthropic from "@anthropic-ai/sdk";
import type { UsageLine } from "./pricing.js";

export interface RecapCandidate {
  ref: string;
  /** e.g. "tue 18:04" (group time zone) */
  local_time: string;
  kind: "photo" | "live_photo" | "video";
  caption: string | null;
  /** total reactions on the photo; used only for choosing and ordering, never shown */
  reactions: number;
  /** the daily moment it answered on time, if any (m1, m2, …) */
  moment: string | null;
}

export interface RecapMoment {
  ref: string;
  local_time: string;
  answered_by_everyone: boolean;
}

export interface RecapInput {
  group_kind: string;
  week: { from: string; to: string };
  photos: RecapCandidate[];
  moments: RecapMoment[];
}

export interface RecapDraft {
  items: string[];
  text: string;
}

export interface RecapModelResult {
  draft: RecapDraft | null;
  refused: boolean;
  stopReason: string | null;
  /** model that produced the final message */
  model: string;
  usage: UsageLine[];
}

export interface RecapModel {
  readonly model: string;
  draft(input: RecapInput): Promise<RecapModelResult>;
}

export const RECAP_SYSTEM_PROMPT = [
  "You assemble the weekly recap of a private photo group of close friends or family.",
  "You get the week's photos as references with their local time, caption, kind, a reaction total, and the daily same-moment prompt they answered on time (if any), plus which moments every member answered.",
  "Choose the photos that tell the group's week and put them in the order they should be seen. Prefer moments everyone shared and photos the group reacted to, keep the week's variety, and keep the order easy to follow.",
  "Then write one short line of recap text addressed to the group as \"you\": all lowercase, second person, one sentence.",
  "The text must not contain any number or count, must not mention reactions, streaks or who did or did not post, and must not suggest guilt, lateness or obligation.",
  "Use only the references you were given.",
].join(" ");

export function recapSchema(refs: string[]): Record<string, unknown> {
  return {
    type: "object",
    properties: {
      items: { type: "array", items: { type: "string", enum: refs } },
      text: { type: "string" },
    },
    required: ["items", "text"],
    additionalProperties: false,
  };
}

/** Recap output budget: room for adaptive thinking at effort low plus a short JSON answer. */
export const RECAP_MAX_TOKENS = 8000;

function usageLines(res: Anthropic.Beta.BetaMessage): UsageLine[] {
  const iterations = res.usage.iterations ?? [];
  const sampled = iterations.filter((i) => i.type === "message" || i.type === "fallback_message") as Array<{
    type: string;
    model?: string | null;
    input_tokens: number;
    output_tokens: number;
    cache_creation_input_tokens: number;
    cache_read_input_tokens: number;
  }>;
  if (sampled.length) {
    return sampled.map((i) => ({
      model: i.model ?? res.model,
      inputTokens: i.input_tokens,
      outputTokens: i.output_tokens,
      cacheWriteTokens: i.cache_creation_input_tokens ?? 0,
      cacheReadTokens: i.cache_read_input_tokens ?? 0,
    }));
  }
  return [
    {
      model: res.model,
      inputTokens: res.usage.input_tokens,
      outputTokens: res.usage.output_tokens,
      cacheWriteTokens: res.usage.cache_creation_input_tokens ?? 0,
      cacheReadTokens: res.usage.cache_read_input_tokens ?? 0,
    },
  ];
}

export function recapRequest(model: string, input: RecapInput): Anthropic.Beta.MessageCreateParamsNonStreaming {
  return {
    model,
    max_tokens: RECAP_MAX_TOKENS,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    system: RECAP_SYSTEM_PROMPT,
    messages: [{ role: "user", content: JSON.stringify(input) }],
    output_config: { effort: "low", format: { type: "json_schema", schema: recapSchema(input.photos.map((p) => p.ref)) } },
  };
}

export class AnthropicRecapModel implements RecapModel {
  constructor(
    private readonly client: Pick<Anthropic, "beta">,
    readonly model: string,
  ) {}

  async draft(input: RecapInput): Promise<RecapModelResult> {
    const res = (await this.client.beta.messages.create(recapRequest(this.model, input))) as Anthropic.Beta.BetaMessage;
    const usage = usageLines(res);
    if (res.stop_reason === "refusal") {
      return { draft: null, refused: true, stopReason: res.stop_reason, model: res.model, usage };
    }
    const text = res.content.filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === "text").map((b) => b.text).join("");
    let draft: RecapDraft | null = null;
    try {
      const parsed = JSON.parse(text) as Partial<RecapDraft>;
      if (Array.isArray(parsed.items) && typeof parsed.text === "string") {
        const allowed = new Set(input.photos.map((p) => p.ref));
        const seen = new Set<string>();
        const items = parsed.items.filter((r): r is string => typeof r === "string" && allowed.has(r) && !seen.has(r) && (seen.add(r), true));
        draft = { items, text: parsed.text };
      }
    } catch {
      draft = null;
    }
    return { draft, refused: false, stopReason: res.stop_reason ?? null, model: res.model, usage };
  }
}
