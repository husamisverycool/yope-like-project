import fs from "node:fs";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { copyText, hasCopy, setCopyTable, WORKER_COPY_KEYS, type WorkerCopyKey } from "../../src/copy.js";
import { copy as generatedCopy } from "../../src/generated/copy.js";
import { checkRecapText, recapTextRules } from "../../src/recap/validate.js";
import { MissingCopyError, MissingTokenError, PermanentError } from "../../src/errors.js";
import { designToken, setTokenOverrides, tokenSource } from "../../src/tokens.js";
import { WORKER_ROOT } from "../../src/config.js";

afterEach(() => {
  setCopyTable(null);
  setTokenOverrides(null);
});

describe("copyText", () => {
  it("throws MissingCopyError (a retryable failure) while the key is not in the generated table", () => {
    setCopyTable({});
    expect(() => copyText("notifications.push.newPost.title", { name: "Ana", group: "G" })).toThrow(MissingCopyError);
    expect(() => copyText("notifications.push.newPost.title", { name: "Ana", group: "G" })).toThrow(/missing copy key notifications\.push\.newPost\.title/);
  });

  it("fills the placeholders the worker provides", () => {
    setCopyTable({ "notifications.push.reaction.body": "{name} {emoji} in {group}" });
    expect(copyText("notifications.push.reaction.body", { name: "Ana", emoji: "🔥", group: "Lima" })).toBe("Ana 🔥 in Lima");
    expect(hasCopy("notifications.push.reaction.body")).toBe(true);
  });

  it("refuses a placeholder the worker does not provide for that key (contract error, not retried)", () => {
    setCopyTable({ "notifications.push.recapReady.body": "{group} {count}" });
    expect(() => copyText("notifications.push.recapReady.body", { group: "G" })).toThrow(PermanentError);
  });

  it("COPY_KEYS.md lists every key the worker reads, with its surface", () => {
    const md = fs.readFileSync(path.join(WORKER_ROOT, "COPY_KEYS.md"), "utf8");
    for (const [key, spec] of Object.entries(WORKER_COPY_KEYS)) {
      expect(md, key).toContain(`\`${key}\``);
      expect(md, key).toContain(spec.surface);
      for (const p of spec.params) expect(md, `${key} {${p}}`).toContain(`{${p}}`);
    }
  });
});

describe("the real generated copy table (design/copy/*.json → src/generated/copy.ts)", () => {
  // The other worker tests run on a test copy table (test/helpers/world.ts); this guard is what
  // proves the shipped table has every key the worker reads, so no job fails with MissingCopyError.
  it("resolves every WORKER_COPY_KEYS key, using only the placeholders the worker provides", () => {
    setCopyTable(null);
    const missing = Object.keys(WORKER_COPY_KEYS).filter((k) => !Object.prototype.hasOwnProperty.call(generatedCopy, k));
    expect(missing).toEqual([]);
    for (const [key, spec] of Object.entries(WORKER_COPY_KEYS)) {
      expect(hasCopy(key as WorkerCopyKey), key).toBe(true);
      const params = Object.fromEntries(spec.params.map((p) => [p, `<${p}>`]));
      const text = copyText(key as WorkerCopyKey, params);
      expect(text.trim(), key).not.toBe("");
      expect(text, key).not.toMatch(/\{[a-zA-Z_][a-zA-Z0-9_]*\}/);
    }
  });

  it("the recap template passes the recap-text rules of design/copy-patterns.md itself", () => {
    setCopyTable(null);
    const { rules, source } = recapTextRules();
    expect(source).toBe("design/copy-patterns.md");
    expect(checkRecapText(copyText("week.recap.template", { group: "Lima" }), rules)).toEqual({ ok: true, problems: [] });
  });
});

describe("designToken", () => {
  it("reads a non-BLOCKED proposal value until the canonical tokens carry it (not for the collage: canonicalToken)", () => {
    expect(designToken<number>("font.size.textStyle.ios.title1")).toBe(28);
    expect(tokenSource("font.size.textStyle.ios.title1")).toBe("proposal");
  });

  it("treats BLOCKED and unknown tokens as missing, with the token's name in the error", () => {
    expect(() => designToken("paywall.layout.iconTileArt")).toThrow(MissingTokenError);
    expect(() => designToken("paywall.layout.iconTileArt")).toThrow("missing design token paywall.layout.iconTileArt");
    expect(() => designToken("layout.no.such.token")).toThrow(MissingTokenError);
  });

  it("test overrides layer over the real sources; null reads as missing", () => {
    const real = designToken("duration.birthday.tribute.titleHold");
    setTokenOverrides({ "duration.birthday.tribute.photoHold": 2500, "font.size.textStyle.ios.title1": null });
    expect(designToken("duration.birthday.tribute.photoHold")).toBe(2500);
    expect(() => designToken("font.size.textStyle.ios.title1")).toThrow(MissingTokenError);
    expect(designToken("duration.birthday.tribute.titleHold")).toBe(real); // not overridden: the real value
  });
});
