// The recap AI client with a mocked Anthropic SDK (no network, no key).
import { describe, expect, it, vi } from "vitest";
import { AnthropicRecapModel, recapRequest, type RecapInput } from "../../src/recap/ai.js";
import { costUsd } from "../../src/recap/pricing.js";

const input: RecapInput = {
  group_kind: "family",
  week: { from: "2026-10-05", to: "2026-10-11" },
  photos: [
    { ref: "p1", local_time: "mon 18:04", kind: "photo", caption: "dinner", reactions: 3, moment: "m1" },
    { ref: "p2", local_time: "wed 09:10", kind: "photo", caption: null, reactions: 0, moment: null },
  ],
  moments: [{ ref: "m1", local_time: "mon 18:02", answered_by_everyone: true }],
};

function fakeClient(response: unknown) {
  const create = vi.fn().mockResolvedValue(response);
  return { client: { beta: { messages: { create } } } as any, create };
}

const usage = (extra: Record<string, unknown> = {}) => ({ input_tokens: 900, output_tokens: 120, cache_creation_input_tokens: 0, cache_read_input_tokens: 0, iterations: null, ...extra });

describe("recap request (claude-api skill)", () => {
  it("uses the configured model, effort low, a JSON schema output format and the default server-side fallback", () => {
    const req = recapRequest("claude-opus-5-5", input) as any;
    expect(req.model).toBe("claude-opus-5-5");
    expect(req.output_config.effort).toBe("low");
    expect(req.output_config.format.type).toBe("json_schema");
    expect(req.output_config.format.schema.properties.items.items.enum).toEqual(["p1", "p2"]);
    expect(req.output_config.format.schema.required).toEqual(["items", "text"]);
    expect(req.output_config.format.schema.additionalProperties).toBe(false);
    expect(req.fallbacks).toBe("default");
    expect(req.betas).toEqual(["server-side-fallback-2026-07-01"]);
    expect(req.thinking).toBeUndefined(); // always on for Claude Opus 5.5; effort controls it
    expect(JSON.parse(req.messages[0].content)).toEqual(input);
  });

  it("sends only that group's week: references, times, captions, kinds, reaction totals and moments", () => {
    const req = recapRequest("claude-opus-5-5", input) as any;
    const sent = req.messages[0].content as string;
    expect(sent).not.toMatch(/[0-9a-f]{8}-[0-9a-f]{4}-/); // no ids
  });
});

describe("AnthropicRecapModel", () => {
  it("parses the structured answer and drops unknown or repeated references", async () => {
    const { client, create } = fakeClient({
      model: "claude-opus-5-5",
      stop_reason: "end_turn",
      content: [{ type: "thinking", thinking: "" }, { type: "text", text: JSON.stringify({ items: ["p2", "p1", "p2", "p9"], text: "you made it a warm week." }) }],
      usage: usage(),
    });
    const r = await new AnthropicRecapModel(client, "claude-opus-5-5").draft(input);
    expect(create).toHaveBeenCalledOnce();
    expect(r.refused).toBe(false);
    expect(r.draft).toEqual({ items: ["p2", "p1"], text: "you made it a warm week." });
    expect(r.usage).toEqual([{ model: "claude-opus-5-5", inputTokens: 900, outputTokens: 120, cacheWriteTokens: 0, cacheReadTokens: 0 }]);
    expect(costUsd(r.usage[0]!)).toBeCloseTo(900 * 4e-6 + 120 * 20e-6, 9);
  });

  it("handles stop_reason refusal before reading content", async () => {
    const { client } = fakeClient({ model: "claude-opus-5-5", stop_reason: "refusal", stop_details: { category: null }, content: [], usage: usage() });
    const r = await new AnthropicRecapModel(client, "claude-opus-5-5").draft(input);
    expect(r).toMatchObject({ draft: null, refused: true, stopReason: "refusal" });
  });

  it("prices each attempt at its own model when the server-side fallback ran", async () => {
    const { client } = fakeClient({
      model: "claude-opus-5",
      stop_reason: "end_turn",
      content: [{ type: "fallback", from: { model: "claude-opus-5-5" }, to: { model: "claude-opus-5" } }, { type: "text", text: JSON.stringify({ items: ["p1"], text: "you were close." }) }],
      usage: usage({
        iterations: [
          { type: "message", model: "claude-opus-5-5", input_tokens: 900, output_tokens: 0, cache_creation_input_tokens: 0, cache_read_input_tokens: 0, cache_creation: null },
          { type: "fallback_message", model: "claude-opus-5", input_tokens: 900, output_tokens: 110, cache_creation_input_tokens: 0, cache_read_input_tokens: 0, cache_creation: null },
        ],
      }),
    });
    const r = await new AnthropicRecapModel(client, "claude-opus-5-5").draft(input);
    expect(r.draft?.items).toEqual(["p1"]);
    expect(r.usage.map((u) => u.model)).toEqual(["claude-opus-5-5", "claude-opus-5"]);
    expect(costUsd(r.usage[1]!)).toBeCloseTo(900 * 5e-6 + 110 * 25e-6, 9);
  });

  it("returns no draft for output that is not the schema", async () => {
    const { client } = fakeClient({ model: "claude-opus-5-5", stop_reason: "end_turn", content: [{ type: "text", text: "not json" }], usage: usage() });
    expect((await new AnthropicRecapModel(client, "claude-opus-5-5").draft(input)).draft).toBeNull();
  });
});
