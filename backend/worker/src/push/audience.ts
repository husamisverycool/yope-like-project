// Who receives a push: a group's members with their devices, per-group mute, Pause All, quiet hours and
// blocks (docs/API.md §10: "notify members except the author, muted members, blocks, quiet hours").

import { maybe, must, selectIn, type Db } from "../db.js";
import { isQuietAt } from "../time.js";
import { firstName, type DeviceRow, type GroupRow, type NotificationSettingsRow } from "../types.js";
import { apnsAlert, fcmAlert, type AlertSpec } from "./payloads.js";
import type { DeviceSend } from "./service.js";

export interface Member {
  userId: string;
  /** no alerts: the group is muted, or the person paused every notification for the day (Pause All, until `paused_until`) */
  muted: boolean;
  /** inside their quiet hours now: alerts are delivered silently */
  quiet: boolean;
  displayName: string;
  firstName: string | null;
  avatarPath: string | null;
  joinedAt: string;
  devices: DeviceRow[];
}

export interface Audience {
  group: GroupRow;
  members: Member[];
  byId: Map<string, Member>;
}

export async function loadGroup(db: Db, groupId: string): Promise<GroupRow | null> {
  return maybe(await db.from("groups").select("id, name, kind, time_zone").eq("id", groupId).maybeSingle(), "group");
}

export async function loadAudience(db: Db, groupId: string, now: Date): Promise<Audience | null> {
  const group = await loadGroup(db, groupId);
  if (!group) return null;
  const rows = must(
    await db.from("group_members").select("user_id, joined_at, profiles(display_name, avatar_path)").eq("group_id", groupId),
    "group_members",
  ) as unknown as Array<{ user_id: string; joined_at: string; profiles: { display_name: string; avatar_path: string | null } | null }>;
  const ids = rows.map((r) => r.user_id);
  // per-group mute: own-rows table, private to each person (migration 0056)
  const mutedBy = new Set(
    (must(await db.from("group_mutes").select("user_id").eq("group_id", groupId), "group_mutes") as Array<{ user_id: string }>).map((r) => r.user_id),
  );
  const devices = await selectIn<DeviceRow>(db, "devices", "id, user_id, platform, push_token, push_to_start_token, live_activities_enabled", "user_id", ids);
  const settings = await selectIn<NotificationSettingsRow>(db, "notification_settings", "user_id, quiet_start, quiet_end, time_zone, paused_until", "user_id", ids);
  const quietBy = new Map(settings.map((s) => [s.user_id, isQuietAt(s.quiet_start, s.quiet_end, s.time_zone, now)]));
  // Pause All silences every alert like a mute of every group (widgets still update silently)
  const pausedBy = new Set(settings.filter((s) => isPausedAt(s.paused_until, now)).map((s) => s.user_id));
  const members: Member[] = rows.map((r) => ({
    userId: r.user_id,
    muted: mutedBy.has(r.user_id) || pausedBy.has(r.user_id),
    quiet: quietBy.get(r.user_id) ?? false,
    displayName: r.profiles?.display_name ?? "",
    firstName: firstName(r.profiles?.display_name),
    avatarPath: r.profiles?.avatar_path ?? null,
    joinedAt: r.joined_at,
    devices: devices.filter((d) => d.user_id === r.user_id).sort((a, b) => a.id.localeCompare(b.id)),
  }));
  members.sort((a, b) => a.userId.localeCompare(b.userId));
  return { group, members, byId: new Map(members.map((m) => [m.userId, m])) };
}

/** Pause All (migration 0037): paused while `paused_until` is still ahead of `now`. */
export function isPausedAt(pausedUntil: string | null | undefined, now: Date): boolean {
  return !!pausedUntil && new Date(pausedUntil).getTime() > now.getTime();
}

/** Users who have a block (either direction) with any of `userIds`. */
export async function blockedWith(db: Db, userIds: string[]): Promise<Set<string>> {
  const out = new Set<string>();
  if (!userIds.length) return out;
  const a = await selectIn<{ blocker_id: string; blocked_id: string }>(db, "blocks", "blocker_id, blocked_id", "blocker_id", userIds);
  const b = await selectIn<{ blocker_id: string; blocked_id: string }>(db, "blocks", "blocker_id, blocked_id", "blocked_id", userIds);
  for (const r of a) out.add(r.blocked_id);
  for (const r of b) out.add(r.blocker_id);
  return out;
}

export async function profileOf(db: Db, userId: string): Promise<{ display_name: string; avatar_path: string | null } | null> {
  return maybe(await db.from("profiles").select("display_name, avatar_path").eq("id", userId).maybeSingle(), "profile");
}

/** Alert sends to every device of one member (APNs alert / FCM data alert). */
export function alertSends(member: Member, spec: Omit<AlertSpec, "quiet">, now: Date, label = spec.type): DeviceSend[] {
  const full: AlertSpec = { ...spec, quiet: member.quiet };
  return member.devices.map((d) =>
    d.platform === "ios"
      ? { userId: member.userId, deviceId: d.id, platform: "ios", token: d.push_token, tokenColumn: "push_token", label, apns: apnsAlert(full) }
      : { userId: member.userId, deviceId: d.id, platform: "android", token: d.push_token, tokenColumn: "push_token", label, fcm: fcmAlert(full, now) },
  );
}
