// Store hand-off. iOS: the App Clip (design/surfaces/invite.web.md "Let's go": an App Clip link,
// as Retro's /u/ page opens its clip card) or the App Store listing; Safari also adds the App Clip
// card from the apple-itunes-app meta tag. Android: Play listing with an install referrer carrying
// the invite token, read after install with the Play Install Referrer API to join the group
// (docs/PLATFORM_CONSTRAINTS.md §4.1: Google Play Instant ended in December 2025).

import { appClipBundleId, type AppIdentity } from "./config.js";

export type Platform = "ios" | "android" | "other";

export function detectPlatform(userAgent: string | undefined): Platform {
  const ua = userAgent ?? "";
  if (/\bAndroid\b/i.test(ua)) return "android";
  if (/\b(iPhone|iPad|iPod)\b/.test(ua)) return "ios";
  return "other";
}

/** Install-referrer payload the Android app parses: `invite_token=<token>`. */
export const referrerFor = (token: string): string => `invite_token=${token}`;

export const appStoreUrl = (app: AppIdentity): string | null =>
  app.ios.appStoreId ? `https://apps.apple.com/app/id${encodeURIComponent(app.ios.appStoreId)}` : null;

export function playStoreUrl(app: AppIdentity, token: string | null): string {
  const u = new URL("https://play.google.com/store/apps/details");
  u.searchParams.set("id", app.android.applicationId);
  if (token) u.searchParams.set("referrer", referrerFor(token));
  return u.toString();
}

/**
 * Where "Get the app" goes. Unknown platforms (desktop, iPadOS with a desktop user agent) get the
 * App Store listing when it exists, else the Play listing. Null while the iOS store id is BLOCKED
 * on iOS: the link is then rendered without a destination (development only; production refuses
 * to start without it).
 */
export function getAppUrl(app: AppIdentity, platform: Platform, token: string | null): string | null {
  if (platform === "android") return playStoreUrl(app, token);
  if (platform === "ios") return appStoreUrl(app);
  return appStoreUrl(app) ?? playStoreUrl(app, token);
}

/**
 * App Clip link of an invite (`https://appclip.apple.com/id?p=<bundle id>.Clip&token=<token>`), or null while the
 * App Store presence it needs is BLOCKED (App Store id and Team ID, as for the apple-itunes-app meta tag).
 */
export function appClipUrl(app: AppIdentity, token: string): string | null {
  if (!app.ios.appStoreId || !app.ios.teamId) return null;
  const u = new URL("https://appclip.apple.com/id");
  u.searchParams.set("p", appClipBundleId(app));
  u.searchParams.set("token", token);
  return u.toString();
}

/** Where "Let's go" goes: the App Clip on iOS, the Play listing (with the referrer) on Android, else the store. */
export function letsGoUrl(app: AppIdentity, platform: Platform, token: string): string | null {
  if (platform === "ios") return appClipUrl(app, token);
  return getAppUrl(app, platform, token);
}
