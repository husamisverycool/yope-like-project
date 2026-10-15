// (c) Deleting a photo recomposes the collage without it, deletes its storage objects, re-renders
// an affected tribute, recomputes the year story and sends widget refreshes.
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { setTokenOverrides } from "../../src/tokens.js";
import { closeDb, createGroup, createUsers, objectsUnder, postPhoto, registerDevice, rpc, sleep, sql, type TestGroup, type TestUser } from "../helpers/db.js";
import { TEST_TRIBUTE_TOKENS } from "../helpers/tokens.js";
import { apnsDeviceSends, startWorld, type World } from "../helpers/world.js";

let w: World;
let u: TestUser[];
let g: TestGroup;
let A: Awaited<ReturnType<typeof postPhoto>>;
let B: Awaited<ReturnType<typeof postPhoto>>;
let C: Awaited<ReturnType<typeof postPhoto>>;
let collageBefore: any;
let tributeBefore: any;
let storyId: string;
const year = new Date().getUTCFullYear();

beforeAll(async () => {
  setTokenOverrides(TEST_TRIBUTE_TOKENS);
  w = await startWorld();
  u = await createUsers(4, "Del");
  g = await createGroup(u[0]!, u.slice(1), { name: "Deletion group", tz: "UTC" });

  // same-moment collage of A, B, C
  const [inv] = await sql(
    `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
     values ($1, current_date, now() - interval '5 seconds', now() + interval '6 seconds', 'fired') returning id, closes_at`,
    [g.id],
  );
  A = await postPhoto(u[0]!, [g.id], { p_invitation_id: inv.id }, { seed: 31, dual: true });
  B = await postPhoto(u[1]!, [g.id], { p_invitation_id: inv.id }, { seed: 32 });
  C = await postPhoto(u[2]!, [g.id], { p_invitation_id: inv.id }, { seed: 33, dual: true });
  await sleep(Math.max(0, new Date(inv.closes_at).getTime() - Date.now() + 2500));
  await sql(`select private.enqueue('collage.compose', jsonb_build_object('invitation_id', $1::uuid, 'group_id', $2::uuid), 'collage.compose:' || $1, now())`, [inv.id, g.id]);

  // u3's birthday tribute with contributions on A (u0) and B (u1)
  const [req] = await sql(
    `insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at) values ($1, $2, current_date + 1, now() + interval '1 day') returning id`,
    [g.id, u[3]!.id],
  );
  await rpc(u[0]!.client, "contribute_tribute", { p_request_id: req.id, p_post_id: A.post.id, p_line: "you make every sunday better" });
  await rpc(u[1]!.client, "contribute_tribute", { p_request_id: req.id, p_post_id: B.post.id, p_line: "happy birthday!" });
  // what due_tributes does for this request (the helper itself is global; the stack is shared)
  await sql(`update public.tribute_requests set due_at = now() - interval '1 second', closed_at = now() where id = $1`, [req.id]);
  const [tr] = await sql(`insert into public.tributes (request_id, group_id, honoree_id) values ($1, $2, $3) returning id`, [req.id, g.id, u[3]!.id]);
  await sql(`select private.enqueue('tribute.render', jsonb_build_object('tribute_id', $1::uuid, 'request_id', $2::uuid, 'group_id', $3::uuid), 'tribute.render:' || $1, now())`, [tr.id, req.id, g.id]);

  // the year story, with A the most-reacted photo
  await rpc(u[1]!.client, "react", { p_post_id: A.post.id, p_emoji: "🔥" });
  await rpc(u[2]!.client, "react", { p_post_id: A.post.id, p_emoji: "😍" });
  const [story] = await sql(`insert into public.year_stories (group_id, year) values ($1, $2) returning id`, [g.id, year]);
  storyId = story.id;
  await sql(`select private.enqueue('year.compute', jsonb_build_object('year_story_id', $1::uuid, 'group_id', $2::uuid, 'year', $3::int), null, now())`, [storyId, g.id, year]);

  await w.runner.runUntilIdle();
  collageBefore = (await sql(`select * from public.collages where invitation_id = $1`, [inv.id]))[0];
  tributeBefore = (await sql(`select * from public.tributes where request_id = $1`, [req.id]))[0];
});

afterAll(async () => {
  setTokenOverrides(null);
  await w.close();
  await closeDb();
});

describe("before the deletion", () => {
  it("has a collage of A, B, C, a delivered tribute with A and B, and a year story using A", async () => {
    expect(collageBefore.status).toBe("ready");
    expect(collageBefore.post_ids).toEqual([A.post.id, B.post.id, C.post.id]);
    expect(tributeBefore.status).toBe("ready");
    expect(tributeBefore.video_path).toMatch(new RegExp(`^g/${g.id}/tributes/${tributeBefore.id}/[0-9a-f]{16}/tribute\\.mp4$`));
    expect(tributeBefore.delivered_at).not.toBeNull();
    const [story] = await sql(`select * from public.year_stories where id = $1`, [storyId]);
    expect(story.status).toBe("ready");
    expect(story.post_ids).toContain(A.post.id);
    expect(story.data.most_reacted[0]).toBe(A.post.id);
    expect(story.data.moments_shared).toBe(3);
    // the honoree was told once, after rendering
    expect(apnsDeviceSends(w.apns)).toHaveLength(0); // no devices registered yet
    expect((await sql(`select status from public.jobs where dedupe_key = $1`, [`push.tribute:${tributeBefore.id}`]))[0].status).toBe("done");
  });
});

describe("deleting photo A", () => {
  let iosWidget: any;
  let androidDev: any;

  beforeAll(async () => {
    iosWidget = await registerDevice(u[1]!, "ios", { widget: `widdel${Date.now()}` });
    androidDev = await registerDevice(u[2]!, "android");
    w.apns.reset();
    w.fcm.reset();
    w.svc.throttle.reset();
    await rpc(u[0]!.client, "delete_media", { p_media_id: A.media.id });
    await w.runner.runUntilIdle();
  });

  it("recomposes the collage without A, under a new version, and deletes the old files", async () => {
    const [after] = await sql(`select * from public.collages where id = $1`, [collageBefore.id]);
    expect(after.status).toBe("ready");
    expect(after.post_ids).toEqual([B.post.id, C.post.id]);
    expect(after.image_path).not.toBe(collageBefore.image_path);
    const files = await objectsUnder(`g/${g.id}/collages/${collageBefore.id}/`);
    const oldVersion = collageBefore.image_path.split("/")[4];
    expect(files.length).toBe(4);
    expect(files.some((f) => f.includes(`/${oldVersion}/`))).toBe(false);
  });

  it("deletes A's storage objects (original, front, renditions)", async () => {
    expect(await objectsUnder(`u/${u[0]!.id}/${A.media.id}/`)).toEqual([]);
    expect(await sql(`select 1 from public.media where id = $1`, [A.media.id])).toHaveLength(0);
  });

  it("re-renders the tribute with B only, without notifying again", async () => {
    const [t] = await sql(`select * from public.tributes where id = $1`, [tributeBefore.id]);
    expect(t.status).toBe("ready");
    expect(t.video_path).not.toBe(tributeBefore.video_path);
    expect(new Date(t.delivered_at).getTime()).toBe(new Date(tributeBefore.delivered_at).getTime());
    const files = await objectsUnder(`g/${g.id}/tributes/${t.id}/`);
    expect(files.sort()).toEqual([t.poster_path, t.video_path].sort());
    expect(await sql(`select 1 from public.jobs where dedupe_key = $1 and status = 'queued'`, [`push.tribute:${t.id}`])).toHaveLength(0);
  });

  it("recomputes the year story without A", async () => {
    const [story] = await sql(`select * from public.year_stories where id = $1`, [storyId]);
    expect(story.status).toBe("ready");
    expect(story.post_ids).not.toContain(A.post.id);
    expect(story.data.most_reacted).not.toContain(A.post.id);
    expect(story.data.moments_shared).toBe(2);
    expect(JSON.stringify(story.data)).not.toContain(A.post.id);
  });

  it("sends widget refreshes: a WidgetKit push to iOS 26 and the new newest photo to Android", async () => {
    const widgetPushes = apnsDeviceSends(w.apns).filter((s) => s.token === iosWidget.widget_push_token);
    expect(widgetPushes.length).toBeGreaterThanOrEqual(1);
    expect(widgetPushes[0]!.pushType).toBe("widgets");
    const android = w.fcm.messages().filter((m) => m.token === androidDev.push_token && m.data.type === "widget");
    expect(android.length).toBeGreaterThanOrEqual(1);
    const last = android[android.length - 1]!;
    expect([B.post.id, C.post.id, undefined]).toContain(last.data.post_id);
    expect(JSON.stringify(w.fcm.messages())).not.toContain(A.post.id);
  });
});

describe("zero answers left", () => {
  it("deletes the collage and all of its objects", async () => {
    const [inv] = await sql(
      `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
       values ($1, current_date + 400, now() - interval '5 seconds', now() + interval '4 seconds', 'fired') returning id, closes_at`,
      [g.id],
    );
    const D = await postPhoto(u[1]!, [g.id], { p_invitation_id: inv.id }, { seed: 41 });
    await sleep(Math.max(0, new Date(inv.closes_at).getTime() - Date.now() + 2500));
    await sql(`select private.enqueue('collage.compose', jsonb_build_object('invitation_id', $1::uuid, 'group_id', $2::uuid), 'collage.compose:' || $1, now())`, [inv.id, g.id]);
    await w.runner.runUntilIdle();
    const [col] = await sql(`select * from public.collages where invitation_id = $1`, [inv.id]);
    expect((await objectsUnder(`g/${g.id}/collages/${col.id}/`)).length).toBe(4);
    await rpc(u[1]!.client, "delete_post", { p_post_id: D.post.id });
    await w.runner.runUntilIdle();
    expect(await sql(`select 1 from public.collages where id = $1`, [col.id])).toHaveLength(0);
    expect(await objectsUnder(`g/${g.id}/collages/${col.id}/`)).toEqual([]);
  });
});
