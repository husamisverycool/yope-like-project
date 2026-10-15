// The worker's payloads against the wire contract the apps already parse:
//   android/core/model/.../PushMessage.kt (PushKeys, PushTypes)
//   ios/Packages/AppCore/Sources/AppModels/PushPayload.swift (PushKey, PushType),
//   WidgetDelivery.swift (WidgetPushPayload), DailyInvitationAttributes.swift
import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT } from "../../src/config.js";
import {
  APNS_MAX_PAYLOAD_BYTES,
  K,
  LIVE_ACTIVITY_ATTRIBUTES_TYPE,
  apnsAlert,
  apnsInvitationAlert,
  apnsLiveActivityStart,
  apnsWidgetBackground,
  apnsWidgetKit,
  fcmAlert,
  fcmInvitation,
  fcmInvitationEnded,
  fcmWidget,
  fitText,
  liveActivityEndPayload,
  payloadBytes,
  type AlertType,
  type WidgetFields,
} from "../../src/push/payloads.js";

const kotlin = fs.readFileSync(path.join(REPO_ROOT, "android/core/model/src/main/kotlin/app/model/PushMessage.kt"), "utf8");
const swiftPush = fs.readFileSync(path.join(REPO_ROOT, "ios/Packages/AppCore/Sources/AppModels/PushPayload.swift"), "utf8");
const swiftAttrs = fs.readFileSync(path.join(REPO_ROOT, "ios/Packages/AppCore/Sources/AppModels/DailyInvitationAttributes.swift"), "utf8");

function kotlinObject(name: string): Record<string, string> {
  const block = new RegExp(`object ${name} \\{([\\s\\S]*?)\\n\\}`).exec(kotlin)?.[1] ?? "";
  return Object.fromEntries([...block.matchAll(/const val (\w+) = "([^"]*)"/g)].map((m) => [m[1], m[2]]));
}
const PUSH_KEYS = kotlinObject("PushKeys");
const PUSH_TYPES = kotlinObject("PushTypes");
const SWIFT_KEYS = new Set([...swiftPush.matchAll(/static let \w+ = "([^"]+)"/g)].map((m) => m[1]));
const SWIFT_TYPES = new Set([...swiftPush.matchAll(/case \w+(?: = "([^"]+)")?/g)].map((m) => m[1] ?? m[0].replace("case ", "")));

const now = new Date("2026-10-15T12:00:00Z");
const widget: WidgetFields = {
  groupId: "11111111-1111-4111-8111-111111111111",
  groupName: "Lima family",
  kind: "photo",
  postId: "22222222-2222-4222-8222-222222222222",
  renditionUrl: "https://x.supabase.co/storage/v1/object/sign/media/u/a/b/r/widget.jpg?token=t",
  senderName: "Ana Lima",
  senderAvatarUrl: "https://x.supabase.co/storage/v1/object/sign/media/avatars/a/1.jpg?token=t",
  caption: "sunday",
  postedAt: "2026-10-15T11:59:00.000Z",
};

describe("shared push vocabulary", () => {
  it("every key the worker sends exists in both apps' contracts", () => {
    for (const v of Object.values(K)) {
      if (v === "widget") {
        expect(SWIFT_KEYS.has(v)).toBe(true); // iOS-only nested object
        continue;
      }
      expect(Object.values(PUSH_KEYS), `android PushKeys has ${v}`).toContain(v);
      if (!["title", "body", "collapse_key", "sent_at"].includes(v)) expect(SWIFT_KEYS.has(v), `ios PushKey has ${v}`).toBe(true);
    }
  });

  it("every type the worker sends exists in both apps' contracts", () => {
    const types: AlertType[] = ["daily_invitation", "new_post", "reaction", "reply", "recap_ready", "birthday_request", "tribute", "year_story"];
    for (const t of [...types, "widget", "daily_invitation_ended"]) {
      expect(Object.values(PUSH_TYPES)).toContain(t);
      expect(SWIFT_TYPES.has(t), t).toBe(true);
    }
  });

  it("the Live Activity attributes type name matches DailyInvitationAttributes", () => {
    expect(swiftAttrs).toContain(`attributesTypeName = "${LIVE_ACTIVITY_ATTRIBUTES_TYPE}"`);
  });
});

describe("APNs payloads", () => {
  it("alert: title/body from copy, category = type, ids flat, widget nested with mutable-content", () => {
    const d = apnsAlert({ type: "new_post", groupId: widget.groupId, ids: { post_id: widget.postId }, title: "T", body: "B", collapseKey: `post:${widget.postId}`, quiet: false, widget });
    expect(d.pushType).toBe("alert");
    expect(d.priority).toBe(10);
    expect(d.collapseId).toBe(`post:${widget.postId}`);
    expect(d.expiration).toBeUndefined();
    expect(d.payload).toEqual({
      aps: { alert: { title: "T", body: "B" }, category: "new_post", "thread-id": widget.groupId, "interruption-level": "active", sound: "default", "mutable-content": 1 },
      type: "new_post",
      group_id: widget.groupId,
      post_id: widget.postId,
      widget: {
        group_id: widget.groupId,
        group_name: "Lima family",
        kind: "photo",
        post_id: widget.postId,
        rendition_url: widget.renditionUrl,
        caption: "sunday",
        posted_at: widget.postedAt,
        sender: { display_name: "Ana Lima", avatar_url: widget.senderAvatarUrl },
      },
    });
  });

  it("quiet hours: passive, no sound, priority 5", () => {
    const d = apnsAlert({ type: "reaction", groupId: "g", ids: { post_id: "p" }, title: "T", body: "B", collapseKey: "reaction:p", quiet: true });
    expect(d.priority).toBe(5);
    expect((d.payload.aps as any)["interruption-level"]).toBe("passive");
    expect((d.payload.aps as any).sound).toBeUndefined();
    expect((d.payload.aps as any)["mutable-content"]).toBeUndefined();
  });

  it("background widget push: content-available, priority 5, flat widget keys, 1 h expiry", () => {
    const d = apnsWidgetBackground(widget, now);
    expect(d.pushType).toBe("background");
    expect(d.priority).toBe(5);
    expect(d.expiration).toBe(Math.floor(now.getTime() / 1000) + 3600);
    expect(d.payload).toMatchObject({ aps: { "content-available": 1 }, type: "widget", group_id: widget.groupId, rendition_url: widget.renditionUrl, sender_name: "Ana Lima", kind: "photo", post_id: widget.postId });
    expect((d.payload.aps as any).alert).toBeUndefined();
  });

  it("WidgetKit push: push type widgets, content-changed only", () => {
    const d = apnsWidgetKit(now);
    expect(d.pushType).toBe("widgets");
    expect(d.priority).toBeUndefined();
    expect(d.payload).toEqual({ aps: { "content-changed": true } });
  });

  it("Live Activity start: event start, attributes, content-state in UNIX seconds, stale-date, alert, channel", () => {
    const closesAt = "2026-10-15T12:02:00.000Z";
    const d = apnsLiveActivityStart({ groupId: "g1", groupName: "Lima", invitationId: "i1", closesAt, title: "T", body: "B", quiet: false, channelId: "Y2g=" }, now);
    expect(d.pushType).toBe("liveactivity");
    expect(d.priority).toBe(10);
    expect(d.expiration).toBe(Date.parse(closesAt) / 1000);
    expect(d.payload).toEqual({
      aps: {
        timestamp: now.getTime() / 1000,
        event: "start",
        "content-state": { closes_at: Date.parse(closesAt) / 1000, group_name: "Lima" },
        "stale-date": Date.parse(closesAt) / 1000,
        "attributes-type": "DailyInvitationAttributes",
        attributes: { group_id: "g1", invitation_id: "i1" },
        alert: { title: "T", body: "B", sound: "default" },
        "input-push-channel": "Y2g=",
      },
    });
  });

  it("Live Activity end: final content-state and a dismissal-date at window close", () => {
    const p = liveActivityEndPayload({ closesAt: "2026-10-15T12:02:00Z", groupName: "Lima" }, now) as any;
    expect(p.aps).toEqual({ timestamp: now.getTime() / 1000, event: "end", "content-state": { closes_at: Date.parse("2026-10-15T12:02:00Z") / 1000, group_name: "Lima" }, "dismissal-date": Date.parse("2026-10-15T12:02:00Z") / 1000 });
  });

  it("invitation alert fallback is time-sensitive and expires at window close", () => {
    const d = apnsInvitationAlert({ groupId: "g", groupName: "G", invitationId: "i", closesAt: "2026-10-15T12:02:00Z", title: "T", body: "B", quiet: false });
    expect((d.payload.aps as any)["interruption-level"]).toBe("time-sensitive");
    expect(d.payload).toMatchObject({ type: "daily_invitation", group_id: "g", invitation_id: "i" });
    expect(d.collapseId).toBe("daily:i");
  });

  it("a long caption is shortened so alert, background and FCM widget payloads stay within 4 KB", () => {
    const long = { ...widget, caption: "🎉 ".repeat(1000).trim() }; // 1000 chars, ~5 KB in UTF-8
    const alert = apnsAlert({ type: "new_post", groupId: "g", ids: { post_id: "p" }, title: "T", body: "B", collapseKey: "post:p", quiet: false, widget: long });
    expect(payloadBytes(alert)).toBeLessThanOrEqual(APNS_MAX_PAYLOAD_BYTES);
    expect((alert.payload.widget as any).caption.length).toBeGreaterThan(100);
    expect(payloadBytes(apnsWidgetBackground(long, now))).toBeLessThanOrEqual(APNS_MAX_PAYLOAD_BYTES);
    expect(Buffer.byteLength(JSON.stringify(fcmWidget(long).data))).toBeLessThanOrEqual(4096);
    expect(apnsAlert({ type: "new_post", groupId: "g", ids: {}, title: "T", body: "B", collapseKey: "c", quiet: false, widget }).payload.widget).toMatchObject({ caption: "sunday" });
  });

  it("long reply text is shortened to fit the 4 KB APNs limit", () => {
    const long = "word ".repeat(2000);
    const r = fitText(long, (t) => apnsAlert({ type: "reply", groupId: "g", ids: { message_id: "m" }, title: "T", body: t, collapseKey: "c", quiet: false }));
    expect(payloadBytes(r.draft)).toBeLessThanOrEqual(APNS_MAX_PAYLOAD_BYTES);
    expect(r.text.length).toBeGreaterThan(1000);
  });
});

describe("FCM data messages", () => {
  it("alerts: string map with title/body, high priority (a notification is shown)", () => {
    const m = fcmAlert({ type: "reply", groupId: "g", ids: { message_id: "m" }, title: "T", body: "B", collapseKey: "reply:m", quiet: true }, now);
    expect(m.priority).toBe("high");
    expect(m.data).toEqual({ type: "reply", group_id: "g", message_id: "m", title: "T", body: "B", collapse_key: "reply:m" });
    for (const v of Object.values(m.data)) expect(typeof v).toBe("string");
  });

  it("widget: normal priority, collapsible per group, flat keys", () => {
    const m = fcmWidget(widget);
    expect(m.priority).toBe("normal");
    expect(m.collapseKey).toBe(`widget:${widget.groupId}`);
    expect(m.data).toMatchObject({ type: "widget", group_id: widget.groupId, group_name: "Lima family", rendition_url: widget.renditionUrl, kind: "photo", posted_at: widget.postedAt, sender_name: "Ana Lima" });
  });

  it("daily invitation: closes_at + sent_at ISO, high priority, TTL until close; ended: normal", () => {
    const m = fcmInvitation({ groupId: "g", groupName: "G", invitationId: "i", closesAt: "2026-10-15T12:02:00Z", title: "T", body: "B", quiet: false }, now);
    expect(m.priority).toBe("high");
    expect(m.ttlSeconds).toBe(120);
    expect(m.data).toEqual({ type: "daily_invitation", group_id: "g", invitation_id: "i", closes_at: "2026-10-15T12:02:00.000Z", title: "T", body: "B", sent_at: now.toISOString() });
    const e = fcmInvitationEnded("g", "i");
    expect(e.priority).toBe("normal");
    expect(e.data).toEqual({ type: "daily_invitation_ended", group_id: "g", invitation_id: "i" });
  });
});
