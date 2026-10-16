// push.selfie_reaction, the plan pushes, push.photos_developed and the scheduler's overnight-photo step,
// against the local stack and mock APNs / FCM.
import { randomUUID } from "node:crypto";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { apnsDeviceSends, startWorld, type World } from "../helpers/world.js";
import { closeDb, createGroup, createMedia, createUsers, jobs, postPhoto, registerDevice, rpc, sql, testJpeg, uploadAs, type TestGroup, type TestUser } from "../helpers/db.js";

let w: World;
let u: TestUser[];
let g: TestGroup;
const ios = new Map<string, string>();
const android = new Map<string, string>();

beforeAll(async () => {
  w = await startWorld();
  u = await createUsers(4, "Feat");
  g = await createGroup(u[0]!, u.slice(1), { name: "Cusco crew" });
  for (const m of u.slice(0, 2)) ios.set(m.id, (await registerDevice(m, "ios")).push_token);
  for (const m of u.slice(2)) android.set(m.id, (await registerDevice(m, "android")).push_token);
});
afterAll(async () => {
  await w.close();
  await closeDb();
});
beforeEach(() => {
  w.apns.reset();
  w.fcm.reset();
  w.svc.throttle.reset();
});

const alertsTo = (token: string) => apnsDeviceSends(w.apns).filter((s) => s.token === token && s.pushType === "alert");
const fcmTo = (token: string) => w.fcm.messages().filter((m) => m.token === token);
const inDays = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString();

async function selfie(user: TestUser): Promise<string> {
  return uploadAs(user, `u/${user.id}/selfies/${randomUUID()}.jpg`, await testJpeg(7));
}

describe("push.selfie_reaction", () => {
  it("tells the photo's author once, as a reaction that opens the photo; not after the selfie is removed", async () => {
    const { post } = await postPhoto(u[2]!, [g.id]);
    await rpc(u[0]!.client, "react_with_selfie", { p_post_id: post.id, p_image_path: await selfie(u[0]!) });
    await rpc(u[0]!.client, "react_with_selfie", { p_post_id: post.id, p_image_path: await selfie(u[0]!) }); // a new selfie: no second push
    await rpc(u[1]!.client, "react_with_selfie", { p_post_id: post.id, p_image_path: await selfie(u[1]!) });
    await rpc(u[1]!.client, "remove_selfie_reaction", { p_post_id: post.id });
    await w.runner.runUntilIdle({ kinds: ["push.selfie_reaction"] });
    const msgs = fcmTo(android.get(u[2]!.id)!);
    expect(msgs).toHaveLength(1);
    expect(msgs[0]!.data).toMatchObject({ type: "reaction", post_id: post.id, group_id: g.id, collapse_key: `reaction:${post.id}` });
    expect(msgs[0]!.data.body).toBe("[notifications.push.selfieReaction.body] name=Feat0 group=Cusco crew");
    expect(apnsDeviceSends(w.apns).filter((s) => s.pushType === "alert")).toHaveLength(0);
  });
});

describe("plans", () => {
  it("push.plan_created: every member but the maker, typed plan, expiring at the start", async () => {
    const plan = await rpc(u[1]!.client, "create_plan", { p_group_id: g.id, p_title: "Picnic", p_starts_at: inDays(4) });
    await w.runner.runUntilIdle({ kinds: ["push.plan_created"] });
    expect(alertsTo(ios.get(u[1]!.id)!)).toHaveLength(0);
    const [a] = alertsTo(ios.get(u[0]!.id)!);
    expect(a!.payload).toMatchObject({ type: "plan", plan_id: plan.id, group_id: g.id });
    expect(a!.collapseId).toBe(`plan:${plan.id}`);
    expect(a!.payload.aps.alert.body).toBe("[notifications.push.planNew.body] name=Feat1 group=Cusco crew title=Picnic");
    expect(Number(a!.expiration)).toBe(Math.floor(new Date(plan.starts_at).getTime() / 1000));
    for (const m of [u[2]!, u[3]!]) expect(fcmTo(android.get(m.id)!)[0]!.data).toMatchObject({ type: "plan", plan_id: plan.id });
  });

  it("push.plan_tomorrow: only Going and Maybe, the maker included; the start time in the group's zone", async () => {
    const plan = await rpc(u[0]!.client, "create_plan", { p_group_id: g.id, p_title: "Hike", p_starts_at: "2031-05-10T17:30:00Z" });
    await rpc(u[2]!.client, "answer_plan", { p_plan_id: plan.id, p_answer: "maybe" });
    await rpc(u[3]!.client, "answer_plan", { p_plan_id: plan.id, p_answer: "cant_go" });
    // u1 never answered
    await w.runner.runUntilIdle({ kinds: ["push.plan_created"] });
    w.apns.reset();
    w.fcm.reset();
    const [reminder] = await jobs("push.plan_tomorrow", { plan_id: plan.id });
    expect(reminder.status).toBe("queued");
    await sql(`update public.jobs set run_at = now() where id = $1`, [reminder.id]);
    await w.runner.runUntilIdle({ kinds: ["push.plan_tomorrow"] });
    const [a] = alertsTo(ios.get(u[0]!.id)!);
    const [{ tz }] = await sql(`select time_zone as tz from public.groups where id = $1`, [g.id]);
    const time = new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit", timeZone: tz }).format(new Date("2031-05-10T17:30:00Z"));
    expect(a!.payload.aps.alert.title).toBe("[notifications.push.planTomorrow.title] group=Cusco crew title=Hike");
    expect(a!.payload.aps.alert.body).toBe(`[notifications.push.planTomorrow.body.timed] group=Cusco crew title=Hike time=${time}`);
    expect(alertsTo(ios.get(u[1]!.id)!)).toHaveLength(0);
    expect(fcmTo(android.get(u[2]!.id)!)).toHaveLength(1);
    expect(fcmTo(android.get(u[3]!.id)!)).toHaveLength(0);
  });

  it("push.plan_changed and push.plan_canceled: Going and Maybe except who did it; nothing after a restore", async () => {
    const plan = await rpc(u[1]!.client, "create_plan", { p_group_id: g.id, p_title: "Dinner", p_starts_at: inDays(5), p_all_day: true });
    await rpc(u[0]!.client, "answer_plan", { p_plan_id: plan.id, p_answer: "going" });
    await rpc(u[2]!.client, "answer_plan", { p_plan_id: plan.id, p_answer: "maybe" });
    await w.runner.runUntilIdle({ kinds: ["push.plan_created"] });
    w.apns.reset();
    w.fcm.reset();

    await rpc(u[1]!.client, "update_plan", { p_plan_id: plan.id, p_title: "Dinner", p_starts_at: plan.starts_at, p_all_day: true, p_place: "Ana's" });
    await w.runner.runUntilIdle({ kinds: ["push.plan_changed"] });
    expect(alertsTo(ios.get(u[1]!.id)!)).toHaveLength(0); // the maker changed it
    expect(alertsTo(ios.get(u[0]!.id)!)[0]!.payload.aps.alert.body).toBe(
      "[notifications.push.planChanged.body.place] name=Feat1 group=Cusco crew title=Dinner place=Ana's",
    );
    expect(fcmTo(android.get(u[2]!.id)!)).toHaveLength(1);
    expect(fcmTo(android.get(u[3]!.id)!)).toHaveLength(0); // no answer
    w.apns.reset();
    w.fcm.reset();

    // cancelled then restored before the job ran: nothing
    await rpc(u[0]!.client, "cancel_plan", { p_plan_id: plan.id }).catch(() => undefined); // u0 is the admin
    await rpc(u[1]!.client, "restore_plan", { p_plan_id: plan.id });
    await w.runner.runUntilIdle({ kinds: ["push.plan_canceled"] });
    expect(apnsDeviceSends(w.apns)).toHaveLength(0);
    expect(w.fcm.messages()).toHaveLength(0);

    await rpc(u[1]!.client, "cancel_plan", { p_plan_id: plan.id });
    await w.runner.runUntilIdle({ kinds: ["push.plan_canceled"] });
    expect(alertsTo(ios.get(u[0]!.id)!)[0]!.payload.aps.alert.body).toBe("[notifications.push.planCanceled.body] name=Feat1 group=Cusco crew title=Dinner");
    expect(alertsTo(ios.get(u[1]!.id)!)).toHaveLength(0);
  });
});

describe("overnight photos", () => {
  it("the scheduler develops them; the group hears once per reveal, the senders included, unless alerts are off", async () => {
    await rpc(u[2]!.client, "set_overnight_alerts", { p_on: false });
    try {
      const m1 = await createMedia(u[3]!);
      const m2 = await createMedia(u[0]!);
      const [d1] = await rpc<any[]>(u[3]!.client, "create_overnight_post", { p_media_id: m1.id, p_group_ids: [g.id] });
      await rpc(u[0]!.client, "create_overnight_post", { p_media_id: m2.id, p_group_ids: [g.id] });
      const report = await w.scheduler.tick(new Date(d1.develops_at), { steps: ["developed"] });
      expect(report.errors).toEqual([]);
      expect(report.developed).toBeGreaterThanOrEqual(2);
      const posts = await sql(`select id from public.posts where media_id = any($1::uuid[])`, [[m1.id, m2.id]]);
      expect(posts).toHaveLength(2);
      expect(await jobs("push.photos_developed", { group_id: g.id })).toHaveLength(1);
      await w.runner.runUntilIdle({ kinds: ["push.photos_developed"] });
      for (const m of [u[0]!, u[1]!]) {
        const [a] = alertsTo(ios.get(m.id)!);
        expect(a!.payload).toMatchObject({ type: "new_post", group_id: g.id });
        expect(posts.map((p) => p.id)).toContain(a!.payload.post_id);
        expect(a!.payload.aps.alert.title).toBe("[camera.overnight.push.title] group=Cusco crew");
      }
      expect(fcmTo(android.get(u[3]!.id)!)).toHaveLength(1); // a sender hears too
      expect(fcmTo(android.get(u[2]!.id)!)).toHaveLength(0); // alerts off
    } finally {
      await rpc(u[2]!.client, "set_overnight_alerts", { p_on: true });
    }
  });
});
