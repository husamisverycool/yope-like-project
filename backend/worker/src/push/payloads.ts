// Push payloads in the wire format shared with the apps:
//   android/core/model/.../PushMessage.kt (PushKeys, PushTypes), DeepLink.kt
//   ios/Packages/AppCore/Sources/AppModels/PushPayload.swift (PushKey, PushType), DeepLinkParser.swift,
//   WidgetDelivery.swift (WidgetPushPayload), DailyInvitationAttributes.swift
// Pure functions (no I/O) so the format is unit-tested key by key.

import type { ApnsNotification } from "./apns.js";
import type { FcmMessage } from "./fcm.js";
import { unixSeconds } from "../time.js";

/** PushKeys / PushKey */
export const K = {
  type: "type",
  groupId: "group_id",
  groupName: "group_name",
  postId: "post_id",
  collageId: "collage_id",
  messageId: "message_id",
  invitationId: "invitation_id",
  recapId: "recap_id",
  requestId: "request_id",
  tributeId: "tribute_id",
  year: "year",
  planId: "plan_id",
  revealedAt: "revealed_at",
  kind: "kind",
  renditionUrl: "rendition_url",
  senderName: "sender_name",
  senderAvatarUrl: "sender_avatar_url",
  caption: "caption",
  postedAt: "posted_at",
  closesAt: "closes_at",
  sentAt: "sent_at",
  title: "title",
  body: "body",
  collapseKey: "collapse_key",
  widget: "widget",
} as const;

/** PushTypes / PushType */
export type PushType =
  | "widget"
  | "daily_invitation"
  | "daily_invitation_ended"
  | "new_post"
  | "reaction"
  | "reply"
  | "recap_ready"
  | "birthday_request"
  | "tribute"
  | "year_story"
  | "plan";

export type AlertType = Exclude<PushType, "widget" | "daily_invitation_ended">;

/** DailyInvitationAttributes.attributesTypeName */
export const LIVE_ACTIVITY_ATTRIBUTES_TYPE = "DailyInvitationAttributes";

/** APNs: 4 KB for alert/background/widget pushes and for Live Activity payloads. */
export const APNS_MAX_PAYLOAD_BYTES = 4096;

/**
 * Widget expiry: the widget's own timeline reload (every 15–60 minutes, docs/PLATFORM_CONSTRAINTS.md
 * §1.1 [KWU]) takes over after an hour, so a widget push older than that is not worth delivering.
 */
export const WIDGET_PUSH_TTL_SECONDS = 3600;

/** The platform default notification sound (aps.sound "default"); omitted during quiet hours. */
const DEFAULT_SOUND = "default";

export interface WidgetFields {
  groupId: string;
  groupName: string;
  kind: "photo" | "collage";
  postId?: string;
  collageId?: string;
  renditionUrl: string;
  senderName?: string | null;
  senderAvatarUrl?: string | null;
  caption?: string | null;
  postedAt: string;
}

export interface AlertSpec {
  type: AlertType;
  groupId: string;
  ids: Partial<Record<"post_id" | "message_id" | "recap_id" | "request_id" | "tribute_id" | "invitation_id" | "year" | "plan_id" | "revealed_at", string>>;
  title: string;
  body: string;
  /** apns-collapse-id / Android notification tag: a re-sent alert replaces the shown one */
  collapseKey: string;
  /** quiet hours: delivered silently (passive, no sound) */
  quiet: boolean;
  /** iOS: carried as the nested "widget" object with mutable-content so the NSE fetches it */
  widget?: WidgetFields;
  /** UNIX seconds after which the alert is pointless (header omitted when undefined) */
  expiresAt?: number;
}

function compact<T extends Record<string, unknown>>(o: T): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(o)) if (v !== undefined && v !== null && v !== "") out[k] = String(v);
  return out;
}

export function widgetFlat(w: WidgetFields): Record<string, string> {
  return compact({
    [K.type]: "widget",
    [K.groupId]: w.groupId,
    [K.groupName]: w.groupName,
    [K.kind]: w.kind,
    [K.postId]: w.postId,
    [K.collageId]: w.collageId,
    [K.renditionUrl]: w.renditionUrl,
    [K.senderName]: w.senderName,
    [K.senderAvatarUrl]: w.senderAvatarUrl,
    [K.caption]: w.caption,
    [K.postedAt]: w.postedAt,
  });
}

/** The nested "widget" object of an iOS alert (WidgetPushPayload, alert-push shape). */
export function widgetNested(w: WidgetFields): Record<string, unknown> {
  const sender: Record<string, string> = compact({ display_name: w.senderName, avatar_url: w.senderAvatarUrl });
  const out: Record<string, unknown> = compact({
    [K.groupId]: w.groupId,
    [K.groupName]: w.groupName,
    [K.kind]: w.kind,
    [K.postId]: w.postId,
    [K.collageId]: w.collageId,
    [K.renditionUrl]: w.renditionUrl,
    [K.caption]: w.caption,
    [K.postedAt]: w.postedAt,
  });
  if (Object.keys(sender).length) out.sender = sender;
  return out;
}

export type ApnsDraft = Omit<ApnsNotification, "token">;
export type FcmDraft = Omit<FcmMessage, "token">;

/** FCM: "The maximum payload for both message types is 4096 bytes" (data map). */
export const FCM_MAX_DATA_BYTES = 4096;

/** Shortens text (at a word boundary when one is close) until `size(text)` fits `max`. */
export function shortenToFit(text: string, size: (t: string) => number, max: number): string {
  let t = text;
  while (size(t) > max && t.length > 0) {
    const over = size(t) - max;
    let cut = Math.max(0, t.length - Math.max(1, over));
    const space = t.lastIndexOf(" ", cut);
    if (space > cut * 0.8) cut = space;
    t = t.slice(0, cut).trimEnd();
  }
  return t;
}

/** A widget payload whose caption (user text, ≤ 1000 chars) would overflow the push limit gets a shorter caption. */
function fitWidgetCaption<T>(w: WidgetFields, build: (w: WidgetFields) => T, size: (d: T) => number, max: number): T {
  const d = build(w);
  if (size(d) <= max || !w.caption) return d;
  const caption = shortenToFit(w.caption, (c) => size(build({ ...w, caption: c })), max);
  return build({ ...w, caption: caption || null });
}

const dataBytes = (d: FcmDraft) => Buffer.byteLength(JSON.stringify(d.data));

export function apnsAlert(spec: AlertSpec): ApnsDraft {
  if (spec.widget) return fitWidgetCaption(spec.widget, (w) => buildApnsAlert({ ...spec, widget: w }), payloadBytes, APNS_MAX_PAYLOAD_BYTES);
  return buildApnsAlert(spec);
}

function buildApnsAlert(spec: AlertSpec): ApnsDraft {
  const aps: Record<string, unknown> = {
    alert: { title: spec.title, body: spec.body },
    category: spec.type,
    "thread-id": spec.groupId,
    // Every alert is `active` (`passive` in quiet hours); none is time-sensitive, the daily
    // invitation included: tenet 5 "invitations, never obligations" (design/surfaces/
    // daily.notification.md, token daily.notification.layout.delivery, MERGE_DECISIONS C-10).
    "interruption-level": spec.quiet ? "passive" : "active",
  };
  if (!spec.quiet) aps.sound = DEFAULT_SOUND;
  if (spec.widget) aps["mutable-content"] = 1;
  const payload: Record<string, unknown> = { aps, [K.type]: spec.type, [K.groupId]: spec.groupId, ...compact(spec.ids) };
  if (spec.widget) payload[K.widget] = widgetNested(spec.widget);
  return {
    pushType: "alert",
    // priority 5 lets the system deliver a silent (quiet-hours) alert by power considerations
    priority: spec.quiet ? 5 : 10,
    expiration: spec.expiresAt,
    collapseId: spec.collapseKey,
    payload,
  };
}

export function fcmAlert(spec: AlertSpec, now: Date): FcmDraft {
  return {
    data: compact({ [K.type]: spec.type, [K.groupId]: spec.groupId, ...spec.ids, [K.title]: spec.title, [K.body]: spec.body, [K.collapseKey]: spec.collapseKey }),
    // a visible notification results (quiet hours make it silent on the device, not invisible)
    priority: "high",
    ttlSeconds: spec.expiresAt !== undefined ? Math.max(0, spec.expiresAt - unixSeconds(now)) : undefined,
  };
}

/** Silent push for iOS < 26 / members without alerts for the group (flat widget keys). */
export function apnsWidgetBackground(w: WidgetFields, now: Date): ApnsDraft {
  return fitWidgetCaption(w, (x) => buildWidgetBackground(x, now), payloadBytes, APNS_MAX_PAYLOAD_BYTES);
}

function buildWidgetBackground(w: WidgetFields, now: Date): ApnsDraft {
  return {
    pushType: "background",
    // "Using priority 10 is an error" for background pushes [APNS]
    priority: 5,
    expiration: unixSeconds(now) + WIDGET_PUSH_TTL_SECONDS,
    collapseId: `widget:${w.groupId}`,
    payload: { aps: { "content-available": 1 }, ...widgetFlat(w) },
  };
}

/** WidgetKit push (iOS 26+): reloads the push-enabled widgets on the device. */
export function apnsWidgetKit(now: Date): ApnsDraft {
  return {
    pushType: "widgets",
    // apns-priority omitted, as in Apple's sample request [WKP]
    expiration: unixSeconds(now) + WIDGET_PUSH_TTL_SECONDS,
    payload: { aps: { "content-changed": true } },
  };
}

export function fcmWidget(w: WidgetFields): FcmDraft {
  return fitWidgetCaption(w, buildFcmWidget, dataBytes, FCM_MAX_DATA_BYTES);
}

function buildFcmWidget(w: WidgetFields): FcmDraft {
  return {
    data: widgetFlat(w),
    priority: "normal",
    ttlSeconds: WIDGET_PUSH_TTL_SECONDS,
    collapseKey: `widget:${w.groupId}`,
  };
}

export interface InvitationSpec {
  groupId: string;
  groupName: string;
  invitationId: string;
  closesAt: string;
  title: string;
  body: string;
  quiet: boolean;
  /** iOS 18+ broadcast channel the activity subscribes to (for the end push) */
  channelId?: string | null;
}

export function liveActivityContentState(spec: { closesAt: string; groupName: string }): Record<string, unknown> {
  // DailyInvitationAttributes.ContentState: closes_at in UNIX seconds, group_name
  return { closes_at: unixSeconds(spec.closesAt), group_name: spec.groupName };
}

/** ActivityKit push-to-start ([LAP]): event start + attributes + alert + stale-date at window close. */
export function apnsLiveActivityStart(spec: InvitationSpec, now: Date): ApnsDraft {
  const alert: Record<string, unknown> = { title: spec.title, body: spec.body };
  if (!spec.quiet) alert.sound = DEFAULT_SOUND;
  const aps: Record<string, unknown> = {
    timestamp: unixSeconds(now),
    event: "start",
    "content-state": liveActivityContentState(spec),
    "stale-date": unixSeconds(spec.closesAt),
    "attributes-type": LIVE_ACTIVITY_ATTRIBUTES_TYPE,
    attributes: { group_id: spec.groupId, invitation_id: spec.invitationId },
    alert,
  };
  if (spec.channelId) aps["input-push-channel"] = spec.channelId;
  return {
    pushType: "liveactivity",
    priority: 10,
    // a start that arrives after the window closed would show a finished countdown
    expiration: unixSeconds(spec.closesAt),
    payload: { aps },
  };
}

/** event end with the final content-state and a dismissal-date at window close (past = immediate). */
export function liveActivityEndPayload(spec: { closesAt: string; groupName: string }, now: Date): Record<string, unknown> {
  return {
    aps: {
      timestamp: unixSeconds(now),
      event: "end",
      "content-state": liveActivityContentState(spec),
      "dismissal-date": unixSeconds(spec.closesAt),
    },
  };
}

/**
 * Alert fallback for iOS devices without a push-to-start token (Live Activities off, iOS < 17.2):
 * a standard alert, interruption level `active` (`passive` in quiet hours), thread = group
 * (daily.notification.layout.delivery).
 */
export function apnsInvitationAlert(spec: InvitationSpec): ApnsDraft {
  return apnsAlert({
    type: "daily_invitation",
    groupId: spec.groupId,
    ids: { invitation_id: spec.invitationId },
    title: spec.title,
    body: spec.body,
    collapseKey: `daily:${spec.invitationId}`,
    quiet: spec.quiet,
    expiresAt: unixSeconds(spec.closesAt),
  });
}

/** Android: data message → ongoing chronometer countdown notification (DailyInvitationNotifier). */
export function fcmInvitation(spec: InvitationSpec, now: Date): FcmDraft {
  return {
    data: compact({
      [K.type]: "daily_invitation",
      [K.groupId]: spec.groupId,
      [K.invitationId]: spec.invitationId,
      [K.closesAt]: new Date(spec.closesAt).toISOString(),
      [K.title]: spec.title,
      [K.body]: spec.body,
      [K.sentAt]: now.toISOString(),
    }),
    priority: "high",
    ttlSeconds: Math.max(0, unixSeconds(spec.closesAt) - unixSeconds(now)),
  };
}

export function fcmInvitationEnded(groupId: string, invitationId: string): FcmDraft {
  return {
    data: { [K.type]: "daily_invitation_ended", [K.groupId]: groupId, [K.invitationId]: invitationId },
    // removes a notification; nothing visible results
    priority: "normal",
    // the notification already removes itself at closes_at (setTimeoutAfter); late delivery adds nothing
    ttlSeconds: 0,
  };
}

export function payloadBytes(d: ApnsDraft): number {
  return Buffer.byteLength(JSON.stringify(d.payload));
}

/**
 * Shortens user text inside a payload until it fits APNs' 4 KB (only ever needed for long chat
 * replies). `build(text)` rebuilds the draft from the shortened text.
 */
export function fitText(text: string, build: (t: string) => ApnsDraft): { draft: ApnsDraft; text: string } {
  const t = shortenToFit(text, (x) => payloadBytes(build(x)), APNS_MAX_PAYLOAD_BYTES);
  return { draft: build(t), text: t };
}
