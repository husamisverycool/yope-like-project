import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { ApnsClient, PROVIDER_TOKEN_MAX_AGE_MS } from "../../src/push/apns.js";
import { FcmClient } from "../../src/push/fcm.js";
import { decodeJwt, verifyEs256 } from "../../src/push/jwt.js";
import { pushKeys, selfSignedCert, startMockApns, startMockFcm, type MockApns, type MockFcm } from "../helpers/mockPush.js";

const keys = pushKeys();
let apnsMock: MockApns;
let fcmMock: MockFcm;

beforeAll(async () => {
  apnsMock = await startMockApns({ publicKey: keys.apnsPublic, teamId: "TEAM123456", keyId: "KEY1234567", bundleId: "com.example.app" });
  fcmMock = await startMockFcm({ publicKey: keys.fcmPublic, projectId: "p1", clientEmail: "w@p1.iam.gserviceaccount.com" });
});
afterAll(async () => {
  await apnsMock.close();
  await fcmMock.close();
});

function apnsClient(now?: () => number) {
  return new ApnsClient(
    { keyP8: keys.apnsP8, keyId: "KEY1234567", teamId: "TEAM123456", bundleId: "com.example.app", env: "sandbox", origin: apnsMock.origin, manageOrigin: apnsMock.origin, ca: selfSignedCert().cert },
    { now },
  );
}

describe("APNs client", () => {
  it("signs an ES256 provider token (kid, iss, iat) and reuses it for up to 50 minutes", () => {
    let t = 1_700_000_000_000;
    const c = apnsClient(() => t);
    const a = c.providerToken();
    const d = decodeJwt(a);
    expect(d.header).toEqual({ alg: "ES256", kid: "KEY1234567" });
    expect(d.claims).toEqual({ iss: "TEAM123456", iat: 1_700_000_000 });
    expect(verifyEs256(a, keys.apnsPublic)).toBe(true);
    t += PROVIDER_TOKEN_MAX_AGE_MS - 1;
    expect(c.providerToken()).toBe(a);
    t += 1;
    expect(c.providerToken()).not.toBe(a);
    c.close();
  });

  it("sends over HTTP/2 with push type, topic suffix, priority, expiration and collapse id", async () => {
    apnsMock.reset();
    const c = apnsClient();
    const r1 = await c.send({ token: "abc", pushType: "alert", priority: 10, collapseId: "post:1", payload: { aps: { alert: { title: "t" } } } });
    const r2 = await c.send({ token: "pts", pushType: "liveactivity", priority: 10, expiration: 123, payload: { aps: { event: "start" } } });
    const r4 = await c.send({ token: "bg", pushType: "background", priority: 5, expiration: 0, payload: { aps: { "content-available": 1 } } });
    expect([r1.ok, r2.ok, r4.ok]).toEqual([true, true, true]);
    const [a, b, bg] = apnsMock.requests;
    expect(a!.path).toBe("/3/device/abc");
    expect(a!.headers["apns-push-type"]).toBe("alert");
    expect(a!.headers["apns-topic"]).toBe("com.example.app");
    expect(a!.headers["apns-priority"]).toBe("10");
    expect(a!.headers["apns-collapse-id"]).toBe("post:1");
    expect(a!.headers["apns-expiration"]).toBeUndefined();
    expect(b!.headers["apns-topic"]).toBe("com.example.app.push-type.liveactivity");
    expect(b!.headers["apns-push-type"]).toBe("liveactivity");
    expect(b!.headers["apns-expiration"]).toBe("123");
    expect(bg!.headers["apns-topic"]).toBe("com.example.app");
    expect(bg!.headers["apns-priority"]).toBe("5");
    expect(bg!.headers["apns-expiration"]).toBe("0");
    c.close();
  });

  it("marks 410 Unregistered and 400 BadDeviceToken as invalid tokens; 429/5xx as retryable", async () => {
    const c = apnsClient();
    expect(await c.send({ token: "gone1", pushType: "alert", priority: 10, payload: {} })).toMatchObject({ ok: false, status: 410, reason: "Unregistered", invalidToken: true });
    expect(await c.send({ token: "bad1", pushType: "alert", priority: 10, payload: {} })).toMatchObject({ ok: false, status: 400, reason: "BadDeviceToken", invalidToken: true });
    apnsMock.respond.set("busy", { status: 429, reason: "TooManyRequests" });
    expect(await c.send({ token: "busy", pushType: "alert", priority: 10, payload: {} })).toMatchObject({ ok: false, invalidToken: false, retryable: true });
    apnsMock.respond.set("topic", { status: 400, reason: "DeviceTokenNotForTopic" });
    expect(await c.send({ token: "topic", pushType: "alert", priority: 10, payload: {} })).toMatchObject({ invalidToken: false, retryable: false });
    c.close();
  });

  it("re-signs the provider token after 403 ExpiredProviderToken and retries once", async () => {
    apnsMock.reset();
    apnsMock.respond.set("exp", { status: 403, reason: "ExpiredProviderToken" });
    const c = apnsClient();
    const r = await c.send({ token: "exp", pushType: "alert", priority: 10, payload: {} });
    expect(apnsMock.requests).toHaveLength(2);
    expect(r.status).toBe(403);
    c.close();
  });

  it("creates a broadcast channel, broadcasts on it and deletes it (iOS 18+ Live Activity channels)", async () => {
    apnsMock.reset();
    const c = apnsClient();
    const id = await c.createChannel(1);
    expect(apnsMock.channels.has(id)).toBe(true);
    const create = apnsMock.requests[0]!;
    expect(create.path).toBe("/1/apps/com.example.app/channels");
    expect(create.json).toEqual({ "message-storage-policy": 1, "push-type": "LiveActivity" });
    const b = await c.broadcast({ channelId: id, priority: 10, expiration: 999, payload: { aps: { event: "end" } } });
    expect(b.ok).toBe(true);
    const sent = apnsMock.requests[1]!;
    expect(sent.path).toBe("/4/broadcasts/apps/com.example.app");
    expect(sent.headers["apns-channel-id"]).toBe(id);
    expect(sent.headers["apns-push-type"]).toBe("liveactivity");
    expect(sent.headers["apns-expiration"]).toBe("999");
    expect((await c.deleteChannel(id)).ok).toBe(true);
    expect(apnsMock.channels.has(id)).toBe(false);
    c.close();
  });
});

describe("FCM HTTP v1 client", () => {
  function fcmClient() {
    return new FcmClient({
      serviceAccount: { project_id: "p1", client_email: "w@p1.iam.gserviceaccount.com", private_key: keys.fcmPrivate, token_uri: fcmMock.tokenUri },
      origin: fcmMock.origin,
      ca: selfSignedCert().cert,
    });
  }

  it("gets an OAuth token with the JWT bearer grant (RS256), caches it, and sends data messages", async () => {
    fcmMock.reset();
    const c = fcmClient();
    const r = await Promise.all([
      c.send({ token: "t1", data: { type: "widget" }, priority: "normal", ttlSeconds: 3600, collapseKey: "widget:g" }),
      c.send({ token: "t2", data: { type: "new_post", title: "T" }, priority: "high" }),
    ]);
    expect(r.every((x) => x.ok)).toBe(true);
    expect(fcmMock.tokenRequests).toHaveLength(1);
    const [m1, m2] = fcmMock.messages().sort((a, b) => a.token.localeCompare(b.token));
    expect(m1).toMatchObject({ token: "t1", data: { type: "widget" }, android: { priority: "NORMAL", ttl: "3600s", collapse_key: "widget:g" } });
    expect(m2).toMatchObject({ token: "t2", data: { type: "new_post", title: "T" }, android: { priority: "HIGH" } });
    expect(fcmMock.requests[0]!.path).toBe("/v1/projects/p1/messages:send");
    c.close();
  });

  it("reports UNREGISTERED as an invalid token", async () => {
    const c = fcmClient();
    const r = await c.send({ token: "gone-x", data: { type: "widget" }, priority: "normal" });
    expect(r).toMatchObject({ ok: false, status: 404, errorCode: "UNREGISTERED", invalidToken: true });
    c.close();
  });
});
