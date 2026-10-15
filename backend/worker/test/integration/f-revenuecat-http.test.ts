// (f) RevenueCat webhook: shared-secret auth, entitlement upsert, idempotency on the event id;
// plus the health endpoint.
import type { AddressInfo } from "node:net";
import type http from "node:http";
import { randomUUID } from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createHttpServer } from "../../src/http.js";
import { memoryLogger } from "../../src/log.js";
import { admin, closeDb, createUsers, sql, type TestUser } from "../helpers/db.js";

const SECRET = "Bearer rc-test-secret-value";
let server: http.Server;
let base: string;
let u: TestUser[];

beforeAll(async () => {
  u = await createUsers(3, "Rc");
  server = createHttpServer({ db: admin, log: memoryLogger().log, workerId: "test", revenuecatAuth: SECRET });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
afterAll(async () => {
  await new Promise<void>((r) => server.close(() => r()));
  await closeDb();
});

function event(type: string, userId: string, extra: Record<string, unknown> = {}) {
  return { api_version: "1.0", event: { id: randomUUID().toUpperCase(), type, app_user_id: userId, original_app_user_id: userId, aliases: [userId], entitlement_ids: ["premium"], event_timestamp_ms: Date.now(), ...extra } };
}

async function post(body: unknown, auth: string | null = SECRET) {
  const res = await fetch(`${base}/webhooks/revenuecat`, { method: "POST", headers: { "content-type": "application/json", ...(auth ? { authorization: auth } : {}) }, body: JSON.stringify(body) });
  return { status: res.status, body: (await res.json()) as any };
}

async function entitlement(userId: string) {
  return (await sql(`select * from public.entitlements where user_id = $1`, [userId]))[0];
}

describe("POST /webhooks/revenuecat", () => {
  it("rejects a missing or wrong Authorization header without touching anything", async () => {
    const e = event("INITIAL_PURCHASE", u[0]!.id, { expiration_at_ms: Date.now() + 86_400_000 });
    expect((await post(e, null)).status).toBe(401);
    expect((await post(e, "Bearer wrong")).status).toBe(401);
    expect(await entitlement(u[0]!.id)).toBeUndefined();
  });

  it("upserts premium with its expiry, once per event id", async () => {
    const exp = Date.now() + 30 * 86_400_000;
    const e = event("INITIAL_PURCHASE", u[0]!.id, { expiration_at_ms: exp });
    expect(await post(e)).toEqual({ status: 200, body: { result: "applied" } });
    const row = await entitlement(u[0]!.id);
    expect(row).toMatchObject({ entitlement: "premium", source: "revenuecat" });
    expect(new Date(row.expires_at).getTime()).toBe(exp);
    // RevenueCat delivers at least once: the same event again changes nothing
    const updatedAt = row.updated_at;
    expect(await post(e)).toEqual({ status: 200, body: { result: "duplicate" } });
    expect((await entitlement(u[0]!.id)).updated_at).toEqual(updatedAt);
  });

  it("an older event arriving late does not overwrite a newer one; EXPIRATION ends premium", async () => {
    const t = Date.now();
    const renewal = event("RENEWAL", u[1]!.id, { expiration_at_ms: t + 60 * 86_400_000, event_timestamp_ms: t });
    const older = event("INITIAL_PURCHASE", u[1]!.id, { expiration_at_ms: t + 30 * 86_400_000, event_timestamp_ms: t - 86_400_000 });
    expect((await post(renewal)).body.result).toBe("applied");
    expect((await post(older)).body.result).toBe("stale");
    expect(new Date((await entitlement(u[1]!.id)).expires_at).getTime()).toBe(t + 60 * 86_400_000);
    const expired = event("EXPIRATION", u[1]!.id, { expiration_at_ms: t - 1000, event_timestamp_ms: t + 1000 });
    expect((await post(expired)).body.result).toBe("applied");
    const [premium] = await sql(`select private.has_premium($1) as p`, [u[1]!.id]);
    expect(premium.p).toBe(false);
  });

  it("ignores unknown customers, other entitlements and informational events (200, recorded once)", async () => {
    expect((await post(event("INITIAL_PURCHASE", "$RCAnonymousID:abc", { aliases: [], expiration_at_ms: Date.now() + 1000 }))).body.result).toBe("ignored");
    expect((await post(event("INITIAL_PURCHASE", u[2]!.id, { entitlement_ids: ["other"], expiration_at_ms: Date.now() + 1000 }))).body.result).toBe("ignored");
    expect((await post(event("TEST", u[2]!.id))).body.result).toBe("ignored");
    expect(await entitlement(u[2]!.id)).toBeUndefined();
    expect((await post({ nope: true })).status).toBe(400);
  });

  it("TRANSFER: the previous owner loses premium", async () => {
    await post(event("INITIAL_PURCHASE", u[2]!.id, { expiration_at_ms: Date.now() + 86_400_000 }));
    const res = await post({ event: { id: randomUUID(), type: "TRANSFER", transferred_from: [u[2]!.id], transferred_to: [u[0]!.id], event_timestamp_ms: Date.now() + 5 } });
    expect(res.body.result).toBe("applied");
    const [premium] = await sql(`select private.has_premium($1) as p`, [u[2]!.id]);
    expect(premium.p).toBe(false);
  });
});

describe("GET /healthz", () => {
  it("answers 200 with the worker id", async () => {
    const res = await fetch(`${base}/healthz`);
    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({ status: "ok", worker_id: "test" });
  });
});
