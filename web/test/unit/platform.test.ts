import { describe, expect, it } from "vitest";
import { parseAppIdentity } from "../../src/config.js";
import { appClipUrl, detectPlatform, getAppUrl, letsGoUrl, playStoreUrl, referrerFor } from "../../src/platform.js";
import { clientAddress, RateLimiter } from "../../src/rateLimit.js";
import { isTokenFormat } from "../../src/token.js";
import { ANDROID, DESKTOP, FULL_APP_JSON, IPHONE } from "../support/app.js";

const app = parseAppIdentity(FULL_APP_JSON);
const TOKEN = "AbC-123_xyzAbC-123_xyz12";

describe("store hand-off", () => {
  it("detects the platform", () => {
    expect(detectPlatform(IPHONE)).toBe("ios");
    expect(detectPlatform(ANDROID)).toBe("android");
    expect(detectPlatform(DESKTOP)).toBe("other");
    expect(detectPlatform(undefined)).toBe("other");
  });

  it("Android goes to the Play listing with an install referrer carrying the token", () => {
    const url = new URL(getAppUrl(app, "android", TOKEN)!);
    expect(url.origin + url.pathname).toBe("https://play.google.com/store/apps/details");
    expect(url.searchParams.get("id")).toBe("com.example.groupphotos");
    expect(url.searchParams.get("referrer")).toBe(referrerFor(TOKEN));
    expect(referrerFor(TOKEN)).toBe(`invite_token=${TOKEN}`);
    expect(new URL(playStoreUrl(app, null)).searchParams.has("referrer")).toBe(false);
  });

  it("iOS goes to the App Store listing (null while its id is BLOCKED)", () => {
    expect(getAppUrl(app, "ios", TOKEN)).toBe("https://apps.apple.com/app/id1234567890");
    const blocked = parseAppIdentity({ ...FULL_APP_JSON, ios: { ...FULL_APP_JSON.ios, appStoreId: null } });
    expect(getAppUrl(blocked, "ios", TOKEN)).toBeNull();
    expect(getAppUrl(blocked, "other", TOKEN)).toContain("play.google.com");
  });
});

describe("'Let's go'", () => {
  it("opens the App Clip on iOS (Retro: appclip.apple.com/id?p=<clip bundle id>&…)", () => {
    const url = new URL(letsGoUrl(app, "ios", TOKEN)!);
    expect(url.origin + url.pathname).toBe("https://appclip.apple.com/id");
    expect(url.searchParams.get("p")).toBe("com.example.groupphotos.Clip");
    expect(url.searchParams.get("token")).toBe(TOKEN);
    expect(appClipUrl(app, TOKEN)).toBe(url.toString());
  });

  it("goes to Play with the referrer on Android and to a store elsewhere", () => {
    expect(letsGoUrl(app, "android", TOKEN)).toBe(getAppUrl(app, "android", TOKEN));
    expect(letsGoUrl(app, "other", TOKEN)).toBe("https://apps.apple.com/app/id1234567890");
  });

  it("is null on iOS while the App Store presence is BLOCKED", () => {
    expect(letsGoUrl(parseAppIdentity({ ...FULL_APP_JSON, ios: { ...FULL_APP_JSON.ios, teamId: null } }), "ios", TOKEN)).toBeNull();
    expect(letsGoUrl(parseAppIdentity({ ...FULL_APP_JSON, ios: { ...FULL_APP_JSON.ios, appStoreId: null } }), "ios", TOKEN)).toBeNull();
  });
});

describe("tokens", () => {
  it("accepts exactly 24 base64url characters", () => {
    expect(isTokenFormat(TOKEN)).toBe(true);
    for (const bad of ["", "short", TOKEN + "a", TOKEN.slice(1), "AbC-123_xyzAbC-123_xyz1/", "AbC-123_xyzAbC-123_xyz1=", "../../etc/passwd/aaaaaaa", "AbC 123_xyzAbC-123_xyz12"]) expect(isTokenFormat(bad)).toBe(false);
  });
});

describe("rate limiting", () => {
  it("counts per key within a window", () => {
    let t = 0;
    const rl = new RateLimiter(2, 60_000, () => t);
    expect(rl.take("a").ok).toBe(true);
    expect(rl.take("a").ok).toBe(true);
    const third = rl.take("a");
    expect(third.ok).toBe(false);
    expect(third.retryAfterSeconds).toBe(60);
    expect(rl.take("b").ok).toBe(true);
    t = 60_000;
    expect(rl.take("a").ok).toBe(true);
  });

  it("trusts X-Forwarded-For only for configured proxy hops", () => {
    expect(clientAddress("10.0.0.1", "1.2.3.4, 5.6.7.8", 0)).toBe("10.0.0.1");
    expect(clientAddress("10.0.0.1", "1.2.3.4, 5.6.7.8", 1)).toBe("5.6.7.8");
    expect(clientAddress("10.0.0.1", "1.2.3.4, 5.6.7.8", 2)).toBe("1.2.3.4");
    expect(clientAddress(undefined, undefined, 1)).toBe("unknown");
  });
});
