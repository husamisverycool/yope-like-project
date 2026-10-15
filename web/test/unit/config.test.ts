import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { blockedConfig, loadConfig, parseAppIdentity } from "../../src/config.js";
import { REQUIRED_COPY, blockedMarker, missingCopy, text } from "../../src/design.js";
import { startupProblems } from "../../src/startup.js";
import { FULL_APP_JSON, testConfig } from "../support/app.js";

const repoAppJson = JSON.parse(fs.readFileSync(path.resolve(__dirname, "../../../config/app.json"), "utf8"));
const fullCopy = Object.fromEntries(REQUIRED_COPY.map((k) => [k, k === "invite.web.documentTitle" ? "{title} | Name" : "x"]));

describe("config", () => {
  it("reads config/app.json and treats unset owner values as BLOCKED", () => {
    const app = parseAppIdentity(repoAppJson);
    expect(app.ios.bundleId).toBe(repoAppJson.ios.bundleId);
    expect(app.android.applicationId).toBe(repoAppJson.android.applicationId);
    const blocked = blockedConfig(testConfig({}, repoAppJson));
    if (!repoAppJson.ios.teamId) expect(blocked.join()).toContain("ios.teamId");
    if (!repoAppJson.domain.value) expect(blocked.join()).toContain("domain");
  });

  it("rejects malformed identity values", () => {
    expect(() => parseAppIdentity({ ...FULL_APP_JSON, ios: { ...FULL_APP_JSON.ios, teamId: "nope" } })).toThrow(/teamId/);
    expect(() => parseAppIdentity({ ...FULL_APP_JSON, domain: { value: "https://x.com/" } })).toThrow(/domain/);
    expect(() => parseAppIdentity({ ...FULL_APP_JSON, android: { ...FULL_APP_JSON.android, sha256CertFingerprints: ["AB:CD"] } })).toThrow(/fingerprints/);
    expect(() => parseAppIdentity({ ...FULL_APP_JSON, legal: { privacyUrl: "http://insecure.example.com" } })).toThrow(/https/);
  });

  it("normalises fingerprints to upper case", () => {
    const fp = FULL_APP_JSON.android.sha256CertFingerprints[0]!.toLowerCase();
    expect(parseAppIdentity({ ...FULL_APP_JSON, android: { ...FULL_APP_JSON.android, sha256CertFingerprints: [fp] } }).android.sha256CertFingerprints[0]).toBe(fp.toUpperCase());
  });

  it("production needs every copy string and config value (startup error otherwise)", () => {
    const config = testConfig({ mode: "production" });
    expect(startupProblems(config, fullCopy)).toEqual([]);
    const { "invite.web.documentTitle": _, ...withoutTitle } = fullCopy;
    expect(startupProblems(config, withoutTitle)).toEqual(["copy invite.web.documentTitle (BLOCKED or missing; see design/BLOCKED.md)"]);
    expect(startupProblems(testConfig({ supabase: null }, repoAppJson), fullCopy).length).toBeGreaterThan(0);
  });

  it("the repository's copy is BLOCKED exactly where it names the app", () => {
    // config/app.json has no displayName yet → designgen leaves {app_name} strings out.
    if (!repoAppJson.displayName.value) expect(missingCopy()).toEqual(["invite.web.documentTitle"]);
    else expect(missingCopy()).toEqual([]);
  });

  it("renders a visible marker for a BLOCKED string", () => {
    expect(text("invite.web.documentTitle", { title: "x" }, {})).toBe(blockedMarker("invite.web.documentTitle"));
    expect(text("invite.web.invitedBy", { first_name: "Ana" })).toBe("Invited by Ana");
  });

  it("parses the environment", () => {
    const appPath = path.resolve(__dirname, "../../../config/app.json");
    const c = loadConfig({ NODE_ENV: "test", APP_CONFIG_PATH: appPath, SUPABASE_URL: "http://127.0.0.1:54321/", SUPABASE_ANON_KEY: "a", SUPABASE_SERVICE_ROLE_KEY: "s", INVITE_CACHE_SECONDS: "30" });
    expect(c.supabase?.url).toBe("http://127.0.0.1:54321");
    expect(c.inviteCacheSeconds).toBe(30);
    expect(() => loadConfig({ NODE_ENV: "production", APP_CONFIG_PATH: appPath, SUPABASE_URL: "http://x.test", SUPABASE_ANON_KEY: "a", SUPABASE_SERVICE_ROLE_KEY: "s" })).toThrow(/https/);
    expect(() => loadConfig({ APP_CONFIG_PATH: appPath, PORT: "abc" })).toThrow(/PORT/);
  });
});
