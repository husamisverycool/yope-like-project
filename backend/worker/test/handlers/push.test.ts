// push.new_post, push.new_message, push.reaction, push.birthday_request, push.recap_ready,
// push.tribute against the local stack and mock APNs / FCM.
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { apnsDeviceSends, startWorld, type World } from "../helpers/world.js";
import { closeDb, createGroup, createUsers, jobs, parkQueuedJobs, postPhoto, registerDevice, rpc, sql, type TestGroup, type TestUser } from "../helpers/db.js";

let w: World;
let u: TestUser[];
let g: TestGroup;
const ios = new Map<string, string>();
const android = new Map<string, string>();

beforeAll(async () => {
  await parkQueuedJobs();
  w = await startWorld();
  u = await createUsers(5, "Push");
  g = await createGroup(u[0]!, u.slice(1), { name: "Lima family" });
  for (const m of u.slice(0, 3)) ios.set(m.id, (await registerDevice(m, "ios")).push_token);
  for (const m of u.slice(3)) android.set(m.id, (await registerDevice(m, "android")).push_token);
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

describe("push.new_post", () => {
  it("notifies every member except the author, with the widget fields for the Notification Service Extension", async () => {
    const { post } = await postPhoto(u[0]!, [g.id], { p_caption: "sunday lunch" });
    await w.runner.runUntilIdle({ kinds: ["push.new_post"] });
    expect(alertsTo(ios.get(u[0]!.id)!)).toHaveLength(0);
    for (const m of [u[1]!, u[2]!]) {
      const [a] = alertsTo(ios.get(m.id)!);
      expect(a, m.name).toBeDefined();
      expect(a!.priority).toBe("10");
      expect(a!.collapseId).toBe(`post:${post.id}`);
      expect(a!.payload.type).toBe("new_post");
      expect(a!.payload.post_id).toBe(post.id);
      expect(a!.payload.group_id).toBe(g.id);
      expect(a!.payload.aps.alert).toEqual({ title: "[notifications.push.newPost.title] name=Push0 group=Lima family", body: "[notifications.push.newPost.body] name=Push0 group=Lima family" });
      expect(a!.payload.aps["mutable-content"]).toBe(1);
      expect(a!.payload.widget).toMatchObject({ group_id: g.id, post_id: post.id, kind: "photo", caption: "sunday lunch", group_name: "Lima family", sender: { display_name: "Push0 Lastname" } });
      expect(a!.payload.widget.rendition_url).toMatch(/\/storage\/v1\/object\/sign\/media\/u\/.+\/r\/widget\.jpg\?token=/);
    }
    for (const m of [u[3]!, u[4]!]) {
      const [msg] = fcmTo(android.get(m.id)!);
      expect(msg!.android.priority).toBe("HIGH");
      expect(msg!.data).toMatchObject({ type: "new_post", group_id: g.id, post_id: post.id, collapse_key: `post:${post.id}` });
    }
    // the widget rendition exists in storage
    const [media] = await sql(`select widget_path from public.media where id = $1`, [post.media_id]);
    expect(media.widget_path).toMatch(/\/r\/widget\.jpg$/);
  });

  it("skips muted members and anyone with a block with the author; quiet hours are silent", async () => {
    await rpc(u[1]!.client, "set_group_muted", { p_group_id: g.id, p_muted: true });
    await rpc(u[3]!.client, "block_user", { p_user_id: u[0]!.id });
    const quiet = await sql<{ t: string }>(`select to_char(now() at time zone 'UTC' - interval '1 hour', 'HH24:MI') as t`);
    const quietEnd = await sql<{ t: string }>(`select to_char(now() at time zone 'UTC' + interval '1 hour', 'HH24:MI') as t`);
    await rpc(u[2]!.client, "set_quiet_hours", { p_start: quiet[0]!.t, p_end: quietEnd[0]!.t, p_time_zone: "UTC" });
    try {
      await postPhoto(u[0]!, [g.id]);
      await w.runner.runUntilIdle({ kinds: ["push.new_post"] });
      expect(alertsTo(ios.get(u[1]!.id)!)).toHaveLength(0);
      expect(fcmTo(android.get(u[3]!.id)!)).toHaveLength(0);
      const [a] = alertsTo(ios.get(u[2]!.id)!);
      expect(a!.priority).toBe("5");
      expect(a!.payload.aps["interruption-level"]).toBe("passive");
      expect(a!.payload.aps.sound).toBeUndefined();
      expect(fcmTo(android.get(u[4]!.id)!)).toHaveLength(1);
    } finally {
      await rpc(u[1]!.client, "set_group_muted", { p_group_id: g.id, p_muted: false });
      await rpc(u[3]!.client, "unblock_user", { p_user_id: u[0]!.id });
      await rpc(u[2]!.client, "set_quiet_hours", { p_start: null, p_end: null, p_time_zone: null });
    }
  });

  it("a photo answering a photo is a 'reply' for that photo's author", async () => {
    const { post: original } = await postPhoto(u[1]!, [g.id]);
    w.apns.reset();
    await w.runner.runUntilIdle({ kinds: ["push.new_post"] });
    w.apns.reset();
    const { post: answer } = await postPhoto(u[2]!, [g.id], { p_reply_to_post_id: original.id });
    await w.runner.runUntilIdle({ kinds: ["push.new_post"] });
    const [r] = alertsTo(ios.get(u[1]!.id)!);
    expect(r!.payload.type).toBe("reply");
    expect(r!.payload.post_id).toBe(answer.id);
    expect(r!.payload.aps.alert.body).toContain("[notifications.push.reply.body.photo]");
    expect(alertsTo(ios.get(u[0]!.id)!)[0]!.payload.type).toBe("new_post");
  });

  it("removes a device whose token APNs reports as unregistered (410)", async () => {
    const [extra] = await createUsers(1, "Gone");
    const invite = await rpc(u[0]!.client, "create_invite", { p_group_id: g.id });
    await rpc(extra!.client, "join_group", { p_token: invite.token });
    const dev = await registerDevice(extra!, "ios", { token: `gone${Date.now()}` });
    await postPhoto(u[0]!, [g.id]);
    await w.runner.runUntilIdle({ kinds: ["push.new_post"] });
    expect(await sql(`select 1 from public.devices where id = $1`, [dev.id])).toHaveLength(0);
    await rpc(extra!.client, "leave_group", { p_group_id: g.id });
  });
});

describe("push.new_message", () => {
  it("only replies notify, and only the author of what was replied to", async () => {
    const m1 = await rpc(u[1]!.client, "send_message", { p_group_id: g.id, p_kind: "text", p_body: "hello" });
    await rpc(u[2]!.client, "send_message", { p_group_id: g.id, p_kind: "text", p_body: "ok so this is a longer reply", p_reply_to_message_id: m1.id });
    await w.runner.runUntilIdle({ kinds: ["push.new_message"] });
    const sends = apnsDeviceSends(w.apns);
    expect(sends).toHaveLength(1);
    expect(sends[0]!.token).toBe(ios.get(u[1]!.id));
    expect(sends[0]!.payload).toMatchObject({ type: "reply", group_id: g.id });
    expect(sends[0]!.payload.message_id).toBeDefined();
    expect(sends[0]!.payload.aps.alert.body).toBe("[notifications.push.reply.body.text] name=Push2 group=Lima family message=ok so this is a longer reply");
    expect(w.fcm.messages()).toHaveLength(0);
  });
});

describe("push.reaction", () => {
  it("notifies the photo's author once per photo (collapsed), never the reactor themself, and not after an un-react", async () => {
    const { post } = await postPhoto(u[3]!, [g.id]);
    await w.runner.runUntilIdle({ kinds: ["push.new_post"] });
    w.fcm.reset();
    await rpc(u[0]!.client, "react", { p_post_id: post.id, p_emoji: "🔥" });
    await rpc(u[3]!.client, "react", { p_post_id: post.id, p_emoji: "😂" }); // own photo
    await rpc(u[1]!.client, "react", { p_post_id: post.id, p_emoji: "❤️" });
    await rpc(u[1]!.client, "unreact", { p_post_id: post.id, p_emoji: "❤️" });
    await w.runner.runUntilIdle({ kinds: ["push.reaction"] });
    const msgs = fcmTo(android.get(u[3]!.id)!);
    expect(msgs).toHaveLength(1);
    expect(msgs[0]!.data).toMatchObject({ type: "reaction", post_id: post.id, collapse_key: `reaction:${post.id}` });
    expect(msgs[0]!.data.title).toBe("[notifications.push.reaction.title] name=Push0 emoji=🔥 group=Lima family");
  });
});

describe("push.birthday_request", () => {
  it("goes to the members except the honoree and anyone blocked with them", async () => {
    await rpc(u[4]!.client, "block_user", { p_user_id: u[2]!.id });
    try {
      const [req] = await sql(
        `insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at) values ($1, $2, current_date + 7, now() + interval '7 days') returning id`,
        [g.id, u[2]!.id],
      );
      await rpc(w.svc.db, "enqueue_job", { p_kind: "push.birthday_request", p_payload: { request_id: req.id, group_id: g.id, honoree_id: u[2]!.id } });
      await w.runner.runUntilIdle({ kinds: ["push.birthday_request"] });
      const iosTokens = apnsDeviceSends(w.apns).map((s) => s.token);
      const fcmTokens = w.fcm.messages().map((m) => m.token);
      expect(iosTokens.sort()).toEqual([ios.get(u[0]!.id), ios.get(u[1]!.id)].sort());
      expect(iosTokens).not.toContain(ios.get(u[2]!.id)); // the honoree
      expect(fcmTokens).toEqual([android.get(u[3]!.id)]); // u4 blocked the honoree
      const a = apnsDeviceSends(w.apns)[0]!;
      expect(a.payload).toMatchObject({ type: "birthday_request", request_id: req.id, group_id: g.id });
      expect(a.payload.aps.alert.title).toBe("[notifications.push.birthdayRequest.title] name=Push2 group=Lima family");
      expect(Number(a.expiration)).toBeGreaterThan(Date.now() / 1000);
    } finally {
      await rpc(u[4]!.client, "unblock_user", { p_user_id: u[2]!.id });
    }
  });
});

describe("push.tribute and push.recap_ready", () => {
  it("push.tribute: only a rendered and delivered tribute, only to the honoree", async () => {
    const [req] = await sql(`insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at, closed_at) values ($1, $2, current_date, now() - interval '1 hour', now()) returning id`, [g.id, u[0]!.id]);
    const [t] = await sql(`insert into public.tributes (request_id, group_id, honoree_id) values ($1, $2, $3) returning id`, [req.id, g.id, u[0]!.id]);
    await rpc(w.svc.db, "enqueue_job", { p_kind: "push.tribute", p_payload: { tribute_id: t.id, group_id: g.id } });
    await w.runner.runUntilIdle({ kinds: ["push.tribute"] });
    expect(apnsDeviceSends(w.apns)).toHaveLength(0); // not rendered: nothing implied
    await sql(`update public.tributes set status = 'ready', video_path = $2, poster_path = $3, rendered_at = now(), delivered_at = now() where id = $1`, [t.id, `g/${g.id}/tributes/${t.id}/v/tribute.mp4`, `g/${g.id}/tributes/${t.id}/v/poster.jpg`]);
    await rpc(w.svc.db, "enqueue_job", { p_kind: "push.tribute", p_payload: { tribute_id: t.id, group_id: g.id } });
    await w.runner.runUntilIdle({ kinds: ["push.tribute"] });
    const sends = apnsDeviceSends(w.apns);
    expect(sends.map((s) => s.token)).toEqual([ios.get(u[0]!.id)]);
    expect(sends[0]!.payload).toMatchObject({ type: "tribute", tribute_id: t.id, group_id: g.id });
  });

  it("push.recap_ready: members who did not mute the group", async () => {
    const [r] = await sql(`insert into public.weekly_recaps (group_id, week_start, status) values ($1, date '2026-01-05', 'pending') returning id`, [g.id]);
    await rpc(w.svc.db, "enqueue_job", { p_kind: "push.recap_ready", p_payload: { recap_id: r.id, group_id: g.id } });
    await w.runner.runUntilIdle({ kinds: ["push.recap_ready"] });
    expect(apnsDeviceSends(w.apns)).toHaveLength(0); // not ready yet
    const [p] = await sql(`select id from public.posts where group_id = $1 limit 1`, [g.id]);
    await sql(`update public.weekly_recaps set status = 'ready', items = array[$2::uuid] where id = $1`, [r.id, p.id]);
    await rpc(w.svc.db, "enqueue_job", { p_kind: "push.recap_ready", p_payload: { recap_id: r.id, group_id: g.id } });
    await w.runner.runUntilIdle({ kinds: ["push.recap_ready"] });
    expect(apnsDeviceSends(w.apns)).toHaveLength(3);
    expect(w.fcm.messages()).toHaveLength(2);
    expect(w.fcm.messages()[0]!.data).toMatchObject({ type: "recap_ready", recap_id: r.id });
    expect(await jobs("push.recap_ready", { recap_id: r.id })).toHaveLength(2);
  });
});
