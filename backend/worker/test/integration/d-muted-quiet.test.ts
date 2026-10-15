// (d) Muted group: no alert, widget update only. Quiet hours: delivered silently.
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { closeDb, createGroup, createUsers, postPhoto, registerDevice, rpc, sql, type TestGroup, type TestUser } from "../helpers/db.js";
import { apnsDeviceSends, startWorld, type World } from "../helpers/world.js";

let w: World;
let u: TestUser[];
let g: TestGroup;
const d: Record<string, any> = {};

beforeAll(async () => {
  w = await startWorld();
  u = await createUsers(5, "Quiet");
  g = await createGroup(u[0]!, u.slice(1), { name: "Muted test", tz: "UTC" });
  d.mutedIos = await registerDevice(u[1]!, "ios"); // iOS < 26, muted
  d.mutedIos26 = await registerDevice(u[2]!, "ios", { pushToStart: `ptsm${Date.now()}`, widget: `widm${Date.now()}` }); // iOS 26, muted
  d.mutedAndroid = await registerDevice(u[3]!, "android"); // muted
  d.quietIos = await registerDevice(u[4]!, "ios", { pushToStart: `ptsq${Date.now()}` }); // quiet hours
  for (const m of [u[1]!, u[2]!, u[3]!]) await rpc(m.client, "set_group_muted", { p_group_id: g.id, p_muted: true });
  const [{ s, e }] = await sql(`select to_char(now() at time zone 'UTC' - interval '1 hour', 'HH24:MI') as s, to_char(now() at time zone 'UTC' + interval '1 hour', 'HH24:MI') as e`);
  await rpc(u[4]!.client, "set_quiet_hours", { p_start: s, p_end: e, p_time_zone: "UTC" });
});

afterAll(async () => {
  await w.close();
  await closeDb();
});

describe("a new photo", () => {
  it("muted members get no alert but their widgets update; quiet hours get a silent alert", async () => {
    const { post } = await postPhoto(u[0]!, [g.id]);
    await w.runner.runUntilIdle();
    const ios = apnsDeviceSends(w.apns);
    const to = (token: string) => ios.filter((s) => s.token === token);
    // muted iOS < 26: a silent background push with the widget fields, no alert
    expect(to(d.mutedIos.push_token).map((s) => s.pushType)).toEqual(["background"]);
    expect(to(d.mutedIos.push_token)[0]!.payload).toMatchObject({ type: "widget", post_id: post.id });
    // muted iOS 26: a WidgetKit push only
    expect(to(d.mutedIos26.push_token)).toEqual([]);
    expect(to(d.mutedIos26.widget_push_token).map((s) => s.pushType)).toEqual(["widgets"]);
    // muted Android: the widget data message (normal priority) only
    const andr = w.fcm.messages().filter((m) => m.token === d.mutedAndroid.push_token);
    expect(andr.map((m) => [m.data.type, m.android.priority])).toEqual([["widget", "NORMAL"]]);
    // quiet hours: the alert arrives silently, and the Notification Service Extension updates the widget
    const quiet = to(d.quietIos.push_token);
    expect(quiet.map((s) => s.pushType)).toEqual(["alert"]);
    expect(quiet[0]!.priority).toBe("5");
    expect(quiet[0]!.payload.aps["interruption-level"]).toBe("passive");
    expect(quiet[0]!.payload.aps.sound).toBeUndefined();
    expect(quiet[0]!.payload.aps["mutable-content"]).toBe(1);
    expect(quiet[0]!.payload.widget.post_id).toBe(post.id);
  });
});

describe("the daily invitation", () => {
  it("is not sent to muted members; in quiet hours the Live Activity starts without sound", async () => {
    w.apns.reset();
    w.fcm.reset();
    const [inv] = await sql(
      `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at) values ($1, current_date + 3, now(), now() + interval '2 minutes') returning id`,
      [g.id],
    );
    await rpc(w.svc.db, "enqueue_job", { p_kind: "invitation.fire", p_payload: { invitation_id: inv.id, group_id: g.id } });
    await w.runner.runUntilIdle({ kinds: ["invitation.fire"] });
    const ios = apnsDeviceSends(w.apns);
    expect(ios.map((s) => s.token)).toEqual([d.quietIos.push_to_start_token]);
    expect(ios[0]!.pushType).toBe("liveactivity");
    expect(ios[0]!.payload.aps.alert.sound).toBeUndefined();
    expect(w.fcm.messages()).toEqual([]);
    const batch = w.logs.find((l) => l.msg === "push batch" && l.batch === "invitation" && l.invitation_id === inv.id)!;
    expect(batch.muted).toBe(3);
  });
});
