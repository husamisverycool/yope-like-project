// invitation.fire {invitation_id, group_id} at fires_at and invitation.end at closes_at.
//
// Every member of the group gets the invitation in ONE concurrent batch (APNs requests share one
// HTTP/2 connection; FCM likewise); the batch's dispatch spread is logged (docs/SPEC_FLAGS.md P4).
//   iOS with a push-to-start token: Live Activity push-to-start with the alert, stale-date =
//     closes_at, subscribed to a per-invitation broadcast channel (iOS 18+) for the end push
//     (docs/PLATFORM_CONSTRAINTS.md §2: "The start alert *is* the daily invitation").
//   iOS without one (Live Activities off, iOS < 17.2): a time-sensitive alert.
//   Android: high-priority data message → ongoing chronometer countdown notification.
// Muted members get nothing (no alert; their widgets update with the collage later). Quiet
// hours: no sound (iOS passive alert; Android applies quiet hours on the device).
// At-most-once: the invitation is marked `fired` before the batch goes out, so a job that runs
// twice never starts a second Live Activity.

import { maybe, must } from "../db.js";
import { copyText } from "../copy.js";
import { loadAudience } from "../push/audience.js";
import {
  apnsInvitationAlert,
  apnsLiveActivityStart,
  fcmInvitation,
  fcmInvitationEnded,
  liveActivityEndPayload,
  type InvitationSpec,
} from "../push/payloads.js";
import type { DeviceSend } from "../push/service.js";
import { enqueue, optStr, str, type JobContext } from "../services.js";
import { unixSeconds } from "../time.js";
import type { InvitationRow } from "../types.js";

/** Channel creation must not hold up the dispatch at fires_at for long. */
export const CHANNEL_CREATE_BUDGET_MS = 3000;
/** A Live Activity is "active for up to eight hours" [LAD]; the end push is useful that long. */
export const LIVE_ACTIVITY_MAX_ACTIVE_S = 8 * 3600;

async function loadInvitation(ctx: JobContext, id: string): Promise<InvitationRow | null> {
  return maybe(await ctx.db.from("daily_invitations").select("id, group_id, local_date, fires_at, closes_at, status").eq("id", id).maybeSingle(), "invitation") as InvitationRow | null;
}

export async function invitationFire(ctx: JobContext): Promise<void> {
  const id = str(ctx.job.payload, "invitation_id");
  const inv = await loadInvitation(ctx, id);
  if (!inv) return;
  if (inv.status !== "scheduled") {
    ctx.log.info("invitation already dispatched or cancelled", { invitation_id: id, status: inv.status });
    return;
  }
  const now = ctx.now();
  if (now.getTime() >= new Date(inv.closes_at).getTime()) {
    ctx.log.warn("invitation window closed before dispatch; nothing sent", { invitation_id: id, fires_at: inv.fires_at, closes_at: inv.closes_at });
    return;
  }
  const audience = await loadAudience(ctx.db, inv.group_id, now);
  if (!audience) return;
  // copy first: a missing key fails the job before anything is marked or sent
  const title = copyText("notifications.push.dailyInvitation.title", { group: audience.group.name });
  const body = copyText("notifications.push.dailyInvitation.body", { group: audience.group.name });

  const recipients = audience.members.filter((m) => !m.muted);
  const wantsLiveActivity = recipients.some((m) => m.devices.some((d) => d.platform === "ios" && d.push_to_start_token));

  // claim the dispatch (at-most-once)
  const claimed = must(await ctx.db.from("daily_invitations").update({ status: "fired" }).eq("id", id).eq("status", "scheduled").select("id"), "fire") as Array<{ id: string }>;
  if (!claimed.length) return;

  let channelId: string | null = null;
  if (wantsLiveActivity && ctx.push.apns) {
    const apns = ctx.push.apns;
    channelId = await Promise.race([
      apns.createChannel(1).catch((e) => {
        ctx.log.warn("live activity channel not created; activities end by stale-date and the app", { error: e });
        return null;
      }),
      new Promise<null>((r) => setTimeout(() => r(null), CHANNEL_CREATE_BUDGET_MS)),
    ]);
  }

  const lateness = ctx.now().getTime() - new Date(inv.fires_at).getTime();
  const sends: DeviceSend[] = [];
  for (const m of recipients) {
    const spec: InvitationSpec = {
      groupId: inv.group_id,
      groupName: audience.group.name,
      invitationId: inv.id,
      closesAt: inv.closes_at,
      title,
      body,
      quiet: m.quiet,
      channelId,
    };
    for (const d of m.devices) {
      if (d.platform === "ios" && d.push_to_start_token) {
        sends.push({ userId: m.userId, deviceId: d.id, platform: "ios", token: d.push_to_start_token, tokenColumn: "push_to_start_token", label: "liveactivity.start", apns: apnsLiveActivityStart(spec, now) });
      } else if (d.platform === "ios") {
        sends.push({ userId: m.userId, deviceId: d.id, platform: "ios", token: d.push_token, tokenColumn: "push_token", label: "invitation.alert", apns: apnsInvitationAlert(spec) });
      } else {
        sends.push({ userId: m.userId, deviceId: d.id, platform: "android", token: d.push_token, tokenColumn: "push_token", label: "invitation.android", fcm: fcmInvitation(spec, now) });
      }
    }
  }
  await ctx.push.dispatch(sends, {
    label: "invitation",
    group_id: inv.group_id,
    invitation_id: inv.id,
    members: audience.members.length,
    muted: audience.members.length - recipients.length,
    late_by_ms: lateness,
    channel: channelId !== null,
  });

  await enqueue(
    ctx.db,
    "invitation.end",
    { invitation_id: inv.id, group_id: inv.group_id, channel_id: channelId, apns_env: ctx.push.apns?.environment ?? null },
    { runAt: new Date(inv.closes_at), dedupeKey: `invitation.end:${inv.id}` },
  );
}

export async function invitationEnd(ctx: JobContext): Promise<void> {
  const id = str(ctx.job.payload, "invitation_id");
  const channelId = optStr(ctx.job.payload, "channel_id");
  const inv = await loadInvitation(ctx, id);
  const apns = ctx.push.apns;
  if (!inv) {
    if (channelId && apns) await apns.deleteChannel(channelId);
    return;
  }
  const now = ctx.now();
  const audience = await loadAudience(ctx.db, inv.group_id, now);
  if (channelId && apns) {
    if (optStr(ctx.job.payload, "apns_env") && optStr(ctx.job.payload, "apns_env") !== apns.environment) {
      ctx.log.warn("channel belongs to another APNs environment; not used", { channel_id: channelId });
    } else {
      const r = await apns.broadcast({
        channelId,
        priority: 10,
        expiration: unixSeconds(inv.fires_at) + LIVE_ACTIVITY_MAX_ACTIVE_S,
        payload: liveActivityEndPayload({ closesAt: inv.closes_at, groupName: audience?.group.name ?? "" }, now),
      });
      ctx.log.info("live activity end broadcast", { invitation_id: id, status: r.status, reason: r.reason });
      // "APNs may still deliver stored messages after you delete the channel"
      const d = await apns.deleteChannel(channelId);
      if (!d.ok) ctx.log.warn("channel delete failed", { channel_id: channelId, status: d.status, reason: d.reason });
    }
  }
  if (!audience) return;
  const sends: DeviceSend[] = [];
  for (const m of audience.members) {
    for (const d of m.devices) {
      if (d.platform !== "android") continue;
      sends.push({ userId: m.userId, deviceId: d.id, platform: "android", token: d.push_token, tokenColumn: "push_token", label: "invitation.ended", fcm: fcmInvitationEnded(inv.group_id, inv.id) });
    }
  }
  await ctx.push.dispatch(sends, { label: "invitation.end", group_id: inv.group_id, invitation_id: inv.id });
}
