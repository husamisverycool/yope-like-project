// RevenueCat webhook → entitlements (premium active / expires), idempotent on the event id
// (https://www.revenuecat.com/docs/integrations/webhooks: shared-secret Authorization header,
// at-least-once delivery, retries; respond 200 quickly). The apps identify the RevenueCat customer
// with the Supabase user id, so app_user_id (or an alias) is the profile id.

import { createHash, timingSafeEqual } from "node:crypto";
import { rpc, type Db } from "./db.js";
import type { Logger } from "./log.js";

/** config/app.json revenuecat.entitlement */
export const PREMIUM_ENTITLEMENT = "premium";

/** Events that carry the subscription's current expiry (the entitlement stays active until then). */
const SETS_EXPIRY = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "TEMPORARY_ENTITLEMENT_GRANT",
  "CANCELLATION",
  "BILLING_ISSUE",
  "SUBSCRIPTION_PAUSED",
  "REFUND_REVERSED",
  "EXPIRATION",
]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface RevenueCatEvent {
  id?: string;
  type?: string;
  app_user_id?: string;
  original_app_user_id?: string;
  aliases?: string[];
  entitlement_ids?: string[] | null;
  entitlement_id?: string | null;
  expiration_at_ms?: number | null;
  grace_period_expiration_at_ms?: number | null;
  event_timestamp_ms?: number;
  transferred_from?: string[];
  transferred_to?: string[];
}

export function authorized(header: string | undefined, secret: string): boolean {
  if (!header) return false;
  const a = createHash("sha256").update(header).digest();
  const b = createHash("sha256").update(secret).digest();
  return timingSafeEqual(a, b);
}

export function userIdOf(e: RevenueCatEvent): string | null {
  for (const c of [e.app_user_id, e.original_app_user_id, ...(e.aliases ?? [])]) if (c && UUID.test(c)) return c.toLowerCase();
  return null;
}

function touchesPremium(e: RevenueCatEvent): boolean {
  return (e.entitlement_ids ?? []).includes(PREMIUM_ENTITLEMENT) || e.entitlement_id === PREMIUM_ENTITLEMENT;
}

export interface WebhookOutcome {
  status: number;
  body: Record<string, unknown>;
}

export async function handleRevenueCat(db: Db, log: Logger, authHeader: string | undefined, secret: string | null, rawBody: string): Promise<WebhookOutcome> {
  if (!secret) return { status: 503, body: { error: "webhook not configured" } };
  if (!authorized(authHeader, secret)) return { status: 401, body: { error: "unauthorized" } };
  let event: RevenueCatEvent;
  try {
    event = (JSON.parse(rawBody) as { event?: RevenueCatEvent }).event ?? {};
  } catch {
    return { status: 400, body: { error: "invalid json" } };
  }
  if (!event.id || !event.type) return { status: 400, body: { error: "missing event id or type" } };
  const at = new Date(event.event_timestamp_ms ?? Date.now()).toISOString();

  const apply = (eventId: string, userId: string | null, expiresAt: string | null, change: boolean) =>
    rpc<string>(db, "apply_revenuecat_event", {
      p_event_id: eventId,
      p_user_id: userId,
      p_event_type: event.type,
      p_event_at: at,
      p_expires_at: expiresAt,
      p_change: change,
    });

  let result: string;
  if (event.type === "TRANSFER") {
    // the purchase moved to another customer: the previous owners lose premium now; the new
    // owner's expiry arrives with their next event (RevenueCat sends no expiry on TRANSFER)
    const from = (event.transferred_from ?? []).filter((u) => UUID.test(u));
    const results: string[] = [];
    // premium ends at the earlier of the event time and now: an event stamped slightly ahead of
    // this server's clock must not leave the previous owner with premium until that instant
    const endsAt = new Date(Math.min(Date.parse(at), Date.now())).toISOString();
    for (const u of from) results.push(await apply(`${event.id}:${u.toLowerCase()}`, u.toLowerCase(), endsAt, true));
    result = results.length ? results.join(",") : await apply(event.id, null, null, false);
  } else if (SETS_EXPIRY.has(event.type) && touchesPremium(event)) {
    const ms = [event.expiration_at_ms, event.grace_period_expiration_at_ms].filter((x): x is number => typeof x === "number");
    const expires = ms.length ? new Date(Math.max(...ms)).toISOString() : null; // no expiry: lifetime purchase
    result = await apply(event.id, userIdOf(event), expires, true);
  } else {
    result = await apply(event.id, userIdOf(event), null, false);
  }
  log.info("revenuecat event", { event_id: event.id, type: event.type, result });
  return { status: 200, body: { result } };
}

/**
 * Deletes the RevenueCat customer of a deleted account (REST API v1 "Delete Customer",
 * `DELETE https://api.revenuecat.com/v1/subscribers/{app_user_id}`, Bearer secret key; read 2026-10-17 at
 * https://www.revenuecat.com/docs/api-v1/customers: "Permanently deletes a customer … treat both 200 and 404 as
 * successful"). The apps log in to RevenueCat with the Supabase user id, so that id is the app user id. It erases
 * RevenueCat's purchase history only: a store subscription keeps renewing until the person cancels it in the store
 * (the delete-account sheet says so, `settings.account.delete.subscriptionNote`).
 * Returns "deleted" (200) or "absent" (404); throws on any other answer.
 */
export async function deleteRevenueCatCustomer(
  userId: string,
  secretKey: string,
  origin = "https://api.revenuecat.com",
): Promise<"deleted" | "absent"> {
  const res = await fetch(`${origin}/v1/subscribers/${encodeURIComponent(userId)}`, {
    method: "DELETE",
    // RevenueCat answers 400 "Content-Type not application/json" to a bare DELETE (community thread 2808)
    headers: { authorization: `Bearer ${secretKey}`, "content-type": "application/json", accept: "application/json" },
    signal: AbortSignal.timeout(15_000),
  });
  if (res.status === 200) return "deleted";
  if (res.status === 404) return "absent";
  throw new RevenueCatError(res.status, (await res.text().catch(() => "")).slice(0, 200));
}

export class RevenueCatError extends Error {
  constructor(readonly status: number, body: string) {
    super(`RevenueCat DELETE /v1/subscribers answered ${status}${body ? `: ${body}` : ""}`);
  }
}
