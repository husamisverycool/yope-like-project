// (a) A group of 5 gets the daily invitation: real scheduler tick + running job runner; every
// member's push goes out in one concurrent batch to mock APNs / FCM; the Live Activity start
// and end pushes are correct.
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { unixSeconds } from "../../src/time.js";
import { closeDb, createGroup, createUsers, registerDevice, rpc, sql, waitFor, type TestGroup, type TestUser } from "../helpers/db.js";
import { apnsDeviceSends, BUNDLE_ID, startWorld, type World } from "../helpers/world.js";

let w: World;
let u: TestUser[];
let g: TestGroup;
let inv: { id: string; fires_at: string; closes_at: string };
const dev: Record<string, any> = {};

beforeAll(async () => {
  w = await startWorld({ lanes: { realtime: { concurrency: 8, pollMs: 5_000 } } });
  u = await createUsers(5, "Inv");
  // a waking window covering the whole day, so tomorrow's invitation is always schedulable
  g = await createGroup(u[0]!, u.slice(1), { name: "Lima family", tz: "UTC", start: "00:00", end: "23:59" });
  dev.u0 = await registerDevice(u[0]!, "ios", { pushToStart: `pts0${Date.now()}`, widget: `wid0${Date.now()}` });
  dev.u1 = await registerDevice(u[1]!, "ios", { pushToStart: `pts1${Date.now()}` });
  dev.u2 = await registerDevice(u[2]!, "ios"); // Live Activities off / iOS < 17.2
  dev.u3 = await registerDevice(u[3]!, "android");
  dev.u4 = await registerDevice(u[4]!, "android");

  // The real scheduler step creates the invitation (+ invitation.fire and collage.compose jobs).
  // The stack is shared with other suites, so the tick schedules a far-future date nobody else
  // uses (schedule_daily_invitations covers every group) and skips the global due_* helpers.
  const far = `${2031 + Math.floor(Math.random() * 40)}-0${1 + Math.floor(Math.random() * 9)}-1${Math.floor(Math.random() * 9)}`;
  const report = await w.scheduler.tick(new Date(), { dates: [far], steps: ["invitations"] });
  expect(report.errors).toEqual([]);
  expect(report.invitations.created + report.invitations.existing).toBeGreaterThan(0);
  const [row] = await sql(`select id from public.daily_invitations where group_id = $1 and local_date = $2`, [g.id, far]);
  // bring the moment to "in 3 seconds" with a short window, so the test sees fire and close
  const [moved] = await sql(
    `update public.daily_invitations set fires_at = now() + interval '3 seconds', closes_at = now() + interval '8 seconds' where id = $1 returning id, fires_at, closes_at`,
    [row.id],
  );
  inv = { id: moved.id, fires_at: new Date(moved.fires_at).toISOString(), closes_at: new Date(moved.closes_at).toISOString() };
  await sql(`update public.jobs set run_at = $2 where dedupe_key = $1`, [`invitation.fire:${inv.id}`, inv.fires_at]);
  await sql(`update public.jobs set run_at = $2 where dedupe_key = $1`, [`collage.compose:${inv.id}`, inv.closes_at]);
  w.runner.start();
  // a second tick arms the runner's wake-ups for fires_at / closes_at (the poll interval is 5 s)
  const armed = await w.scheduler.tick(new Date(), { steps: ["arm"] });
  expect(armed.armed).toBeGreaterThanOrEqual(2);
});

afterAll(async () => {
  await w.close();
  await closeDb();
});

describe("daily invitation dispatch", () => {
  it("dispatches to all 5 members at fires_at in one concurrent batch", async () => {
    expect(await waitFor(() => apnsDeviceSends(w.apns).length >= 3 && w.fcm.messages().length >= 2, 20_000)).toBe(true);
    const ios = apnsDeviceSends(w.apns);
    const fcm = w.fcm.messages();
    expect(ios.map((s) => s.token).sort()).toEqual([dev.u0.push_to_start_token, dev.u1.push_to_start_token, dev.u2.push_token].sort());
    expect(fcm.map((m) => m.token).sort()).toEqual([dev.u3.push_token, dev.u4.push_token].sort());

    // on time: the runner woke at fires_at (its poll interval is 5 s)
    const firesAt = Date.parse(inv.fires_at);
    const batch = w.logs.find((l) => l.msg === "push batch" && l.batch === "invitation");
    expect(batch).toBeDefined();
    expect(batch!.total).toBe(5);
    expect(batch!.ok).toBe(5);
    expect(typeof batch!.dispatch_spread_ms).toBe("number");
    expect(batch!.late_by_ms as number).toBeGreaterThanOrEqual(0);
    expect(batch!.late_by_ms as number).toBeLessThan(1500);
    // one batch: all five requests reached the push services within a short spread
    const received = [...ios.map((s) => s.receivedAt), ...fcm.map((m) => m.receivedAt)];
    const spread = Math.max(...received) - Math.min(...received);
    expect(spread).toBeLessThan(500);
    console.log(`invitation dispatch: ${received.length} pushes, logged dispatch spread ${batch!.dispatch_spread_ms} ms, completion spread ${batch!.completion_spread_ms} ms, received spread ${spread} ms, ${batch!.late_by_ms} ms after fires_at`);
    expect(Date.now()).toBeGreaterThan(firesAt);
    const [row] = await sql(`select status from public.daily_invitations where id = $1`, [inv.id]);
    expect(row.status).toBe("fired");
  });

  it("iOS with a push-to-start token: Live Activity push-to-start with the alert, stale-date and the broadcast channel", async () => {
    const start = apnsDeviceSends(w.apns).find((s) => s.token === dev.u0.push_to_start_token)!;
    expect(start.pushType).toBe("liveactivity");
    expect(start.topic).toBe(`${BUNDLE_ID}.push-type.liveactivity`);
    expect(start.priority).toBe("10");
    expect(Number(start.expiration)).toBe(unixSeconds(inv.closes_at));
    const channelCreate = w.apns.requests.find((r) => r.path === `/1/apps/${BUNDLE_ID}/channels` && r.method === "POST");
    expect(channelCreate?.json).toEqual({ "message-storage-policy": 1, "push-type": "LiveActivity" });
    const aps = start.payload.aps;
    expect(aps.event).toBe("start");
    expect(aps["attributes-type"]).toBe("DailyInvitationAttributes");
    expect(aps.attributes).toEqual({ group_id: g.id, invitation_id: inv.id });
    expect(aps["content-state"]).toEqual({ closes_at: unixSeconds(inv.closes_at), group_name: "Lima family" });
    expect(aps["stale-date"]).toBe(unixSeconds(inv.closes_at));
    expect(aps.alert).toEqual({
      title: "[notifications.push.dailyInvitation.title] group=Lima family",
      body: "[notifications.push.dailyInvitation.body] group=Lima family",
      sound: "default",
    });
    expect(typeof aps["input-push-channel"]).toBe("string");
    expect(typeof aps.timestamp).toBe("number");
  });

  it("iOS without a push-to-start token gets an active (not time-sensitive) alert; Android a high-priority countdown data message", async () => {
    const alert = apnsDeviceSends(w.apns).find((s) => s.token === dev.u2.push_token)!;
    expect(alert.pushType).toBe("alert");
    expect(alert.payload).toMatchObject({ type: "daily_invitation", group_id: g.id, invitation_id: inv.id });
    expect(alert.payload.aps["interruption-level"]).toBe("active");
    expect(Number(alert.expiration)).toBe(unixSeconds(inv.closes_at));
    const m = w.fcm.messages().find((x) => x.token === dev.u3.push_token)!;
    expect(m.android.priority).toBe("HIGH");
    expect(m.data).toMatchObject({ type: "daily_invitation", group_id: g.id, invitation_id: inv.id, closes_at: inv.closes_at, title: "[notifications.push.dailyInvitation.title] group=Lima family" });
    expect(Date.parse(m.data.sent_at!)).toBeGreaterThan(0);
  });

  it("at closes_at: one broadcast end push (dismissal-date) on the channel, the channel is deleted, Android gets daily_invitation_ended", async () => {
    expect(await waitFor(() => w.apns.requests.some((r) => r.path === `/4/broadcasts/apps/${BUNDLE_ID}`), 20_000)).toBe(true);
    const start = apnsDeviceSends(w.apns).find((s) => s.token === dev.u0.push_to_start_token)!;
    const end = w.apns.requests.find((r) => r.path === `/4/broadcasts/apps/${BUNDLE_ID}`)!;
    expect(end.headers["apns-channel-id"]).toBe(start.payload.aps["input-push-channel"]);
    expect(end.headers["apns-push-type"]).toBe("liveactivity");
    expect(end.json.aps).toMatchObject({ event: "end", "content-state": { closes_at: unixSeconds(inv.closes_at), group_name: "Lima family" }, "dismissal-date": unixSeconds(inv.closes_at) });
    expect(end.receivedAt).toBeGreaterThanOrEqual(0);
    expect(await waitFor(() => w.apns.channels.size === 0, 10_000)).toBe(true);
    expect(await waitFor(() => w.fcm.messages().filter((m) => m.data.type === "daily_invitation_ended").length === 2, 10_000)).toBe(true);
    const ended = w.fcm.messages().filter((m) => m.data.type === "daily_invitation_ended");
    expect(ended.every((m) => m.android.priority === "NORMAL" && m.data.invitation_id === inv.id)).toBe(true);
  });

  it("is at-most-once: running invitation.fire again starts no second Live Activity", async () => {
    const before = apnsDeviceSends(w.apns).filter((s) => s.pushType === "liveactivity").length;
    await rpc(w.svc.db, "enqueue_job", { p_kind: "invitation.fire", p_payload: { invitation_id: inv.id, group_id: g.id } });
    w.runner.wake();
    await waitFor(async () => (await sql(`select 1 from public.jobs where kind = 'invitation.fire' and payload->>'invitation_id' = $1 and status = 'queued'`, [inv.id])).length === 0, 10_000);
    expect(apnsDeviceSends(w.apns).filter((s) => s.pushType === "liveactivity").length).toBe(before);
    // the window closed with no answers: no collage, invitation closed
    expect(await waitFor(async () => (await sql(`select status from public.daily_invitations where id = $1`, [inv.id]))[0].status === "closed", 15_000)).toBe(true);
    expect(await sql(`select 1 from public.collages where invitation_id = $1`, [inv.id])).toHaveLength(0);
  });
});
