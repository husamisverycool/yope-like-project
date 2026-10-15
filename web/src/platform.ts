// Store hand-off. iOS: App Store listing (the Smart App Banner / App Clip card is added by Safari
// from the apple-itunes-app meta tag). Android: Play listing with an install referrer carrying the
// invite token, read after install with the Play Install Referrer API to join the group
// (docs/PLATFORM_CONSTRAINTS.md §4.1: Google Play Instant ended in December 2025).

import type { AppIdentity } from "./config.js";

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
