// media.renditions, widget.refresh, storage.delete, auth.delete_user, moderation.report.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import sharp from "sharp";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { WIDGETKIT_MIN_INTERVAL_MS } from "../../src/push/throttle.js";
import { admin, closeDb, createGroup, createUsers, jobs, objectExists, objectsUnder, parkQueuedJobs, postPhoto, registerDevice, rpc, sql, testJpeg, uploadAs, type TestGroup, type TestUser } from "../helpers/db.js";
import { apnsDeviceSends, startWorld, type World } from "../helpers/world.js";

let w: World;
let u: TestUser[];
let g: TestGroup;

beforeAll(async () => {
  await parkQueuedJobs();
  w = await startWorld();
  u = await createUsers(4, "Media");
  g = await createGroup(u[0]!, u.slice(1), { name: "Roommates" });
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

describe("media.renditions", () => {
  it("writes r/thumb, r/widget, r/display (+ front) without metadata and marks the media ready", async () => {
    const { media } = await postPhoto(u[0]!, [g.id], {}, { dual: true, seed: 7 });
    await w.runner.runUntilIdle({ kinds: ["media.renditions"] });
    const [m] = await sql(`select * from public.media where id = $1`, [media.id]);
    const base = `u/${u[0]!.id}/${media.id}/r/`;
    expect(m.thumb_path).toBe(`${base}thumb.jpg`);
    expect(m.widget_path).toBe(`${base}widget.jpg`);
    expect(m.display_path).toBe(`${base}display.jpg`);
    expect(m.front_thumb_path).toBe(`${base}front_thumb.jpg`);
    expect(m.front_display_path).toBe(`${base}front_display.jpg`);
    expect(m.renditions_ready_at).not.toBeNull();
    const widget = await w.svc.storage.download(m.widget_path);
    const meta = await sharp(widget).metadata();
    expect([meta.width, meta.height]).toEqual([600, 800]); // never enlarged
    expect(meta.exif).toBeUndefined();
    // running it again (a job may run twice) changes nothing
    await rpc(admin, "enqueue_job", { p_kind: "media.renditions", p_payload: { media_id: media.id } });
    await w.runner.runUntilIdle({ kinds: ["media.renditions"] });
    const [again] = await sql(`select renditions_ready_at from public.media where id = $1`, [media.id]);
    expect(again.renditions_ready_at).toEqual(m.renditions_ready_at);
  });

  it("replaces an original that carries GPS by a scrubbed copy (no location ever)", async () => {
    const { media } = await postPhoto(u[1]!, [g.id], {}, { gps: true });
    await w.runner.runUntilIdle({ kinds: ["media.renditions"] });
    const [m] = await sql(`select original_path from public.media where id = $1`, [media.id]);
    expect(m.original_path).toBe(`u/${u[1]!.id}/${media.id}/r/original.jpg`);
    expect(await objectExists(media.originalPath)).toBe(false);
    const meta = await sharp(await w.svc.storage.download(m.original_path)).metadata();
    expect(meta.exif).toBeUndefined();
  });

  it("premium video: H.264/AAC MP4 replaces the upload; renditions come from the poster frame", async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "worker-vid-"));
    const file = path.join(dir, "v.mp4");
    execFileSync("ffmpeg", ["-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc=size=320x240:rate=30:duration=1", "-f", "lavfi", "-i", "sine=duration=1", "-c:v", "mpeg4", "-c:a", "aac", "-shortest", file]);
    await sql(`insert into public.entitlements (user_id, entitlement, expires_at, source) values ($1, 'premium', null, 'test') on conflict do nothing`, [u[2]!.id]);
    const { media } = await postPhoto(u[2]!, [g.id], {}, { kind: "video", body: fs.readFileSync(file) });
    await w.runner.runUntilIdle({ kinds: ["media.renditions"] });
    const [m] = await sql(`select * from public.media where id = $1`, [media.id]);
    expect(m.original_path).toBe(`u/${u[2]!.id}/${media.id}/r/video.mp4`);
    expect(m.display_path).toMatch(/r\/display\.jpg$/);
    expect(m.renditions_ready_at).not.toBeNull();
    expect(await objectExists(media.originalPath)).toBe(false);
  });
});

describe("widget.refresh", () => {
  it("iOS 26 widget token: one WidgetKit push per device per 5 minutes, with a follow-up refresh queued", async () => {
    const dev = await registerDevice(u[1]!, "ios", { widget: `wid${Date.now()}` });
    await postPhoto(u[0]!, [g.id]);
    await w.runner.runUntilIdle({ kinds: ["widget.refresh"] });
    const first = apnsDeviceSends(w.apns).filter((s) => s.token === dev.widget_push_token);
    expect(first).toHaveLength(1);
    expect(first[0]!.pushType).toBe("widgets");
    expect(first[0]!.topic).toBe("com.example.groupphotos.push-type.widgets");
    expect(first[0]!.payload).toEqual({ aps: { "content-changed": true } });

    w.apns.reset();
    await postPhoto(u[2]!, [g.id]);
    await w.runner.runUntilIdle({ kinds: ["widget.refresh"] });
    expect(apnsDeviceSends(w.apns).filter((s) => s.token === dev.widget_push_token)).toHaveLength(0); // throttled
    const queued = (await jobs("widget.refresh", { group_id: g.id })).filter((j) => j.status === "queued");
    expect(queued).toHaveLength(1);
    const delay = new Date(queued[0].run_at).getTime() - Date.now();
    expect(delay).toBeGreaterThan(WIDGETKIT_MIN_INTERVAL_MS - 60_000);
    expect(delay).toBeLessThanOrEqual(WIDGETKIT_MIN_INTERVAL_MS);
    await sql(`update public.jobs set status = 'cancelled' where id = $1`, [queued[0].id]);
    await sql(`delete from public.devices where id = $1`, [dev.id]);
  });

  it("muted members: background push (iOS < 26) and normal-priority data message (Android) with the newest photo; no alert", async () => {
    await rpc(u[3]!.client, "set_group_muted", { p_group_id: g.id, p_muted: true });
    const iosDev = await registerDevice(u[3]!, "ios");
    const andDev = await registerDevice(u[3]!, "android");
    try {
      const { post } = await postPhoto(u[0]!, [g.id]);
      await w.runner.runUntilIdle({ kinds: ["push.new_post", "widget.refresh"] });
      const toIos = apnsDeviceSends(w.apns).filter((s) => s.token === iosDev.push_token);
      expect(toIos.map((s) => s.pushType)).toEqual(["background"]);
      expect(toIos[0]!.priority).toBe("5");
      expect(toIos[0]!.payload).toMatchObject({ aps: { "content-available": 1 }, type: "widget", group_id: g.id, post_id: post.id, kind: "photo" });
      const toAndroid = w.fcm.messages().filter((m) => m.token === andDev.push_token);
      expect(toAndroid).toHaveLength(1);
      expect(toAndroid[0]!.android.priority).toBe("NORMAL");
      expect(toAndroid[0]!.data).toMatchObject({ type: "widget", post_id: post.id });
    } finally {
      await rpc(u[3]!.client, "set_group_muted", { p_group_id: g.id, p_muted: false });
      await sql(`delete from public.devices where user_id = $1`, [u[3]!.id]);
    }
  });

  it("each member gets the newest photo they may see (blocks hide the other's photo)", async () => {
    const a = await registerDevice(u[1]!, "android");
    const b = await registerDevice(u[2]!, "android");
    const { post: older } = await postPhoto(u[3]!, [g.id]);
    const { post: newer } = await postPhoto(u[0]!, [g.id]);
    await rpc(u[2]!.client, "block_user", { p_user_id: u[0]!.id });
    try {
      await w.runner.runUntilIdle({ kinds: ["widget.refresh"] });
      expect(w.fcm.messages().find((m) => m.token === a.push_token)!.data.post_id).toBe(newer.id);
      expect(w.fcm.messages().find((m) => m.token === b.push_token)!.data.post_id).toBe(older.id);
    } finally {
      await rpc(u[2]!.client, "unblock_user", { p_user_id: u[0]!.id });
      await sql(`delete from public.devices where id = any($1)`, [[a.id, b.id]]);
    }
  });
});

describe("storage.delete / auth.delete_user / moderation.report", () => {
  it("deletes exact paths and everything under a prefix, and refuses a bucket-root prefix", async () => {
    const [x] = await createUsers(1, "Del");
    const p1 = await uploadAs(x!, `u/${x!.id}/a/1.jpg`, await testJpeg(1));
    await uploadAs(x!, `u/${x!.id}/b/c/2.jpg`, await testJpeg(2));
    await uploadAs(x!, `u/${x!.id}/b/3.jpg`, await testJpeg(3));
    await rpc(admin, "enqueue_job", { p_kind: "storage.delete", p_payload: { bucket: "media", paths: [p1, `u/${x!.id}/missing.jpg`], prefixes: [`u/${x!.id}/b/`] } });
    await w.runner.runUntilIdle({ kinds: ["storage.delete"] });
    expect(await objectsUnder(`u/${x!.id}/`)).toEqual([]);
    const id = await rpc(admin, "enqueue_job", { p_kind: "storage.delete", p_payload: { bucket: "media", paths: [], prefixes: ["u/"] } });
    await w.runner.runUntilIdle({ kinds: ["storage.delete"] });
    const [j] = await sql(`select status, last_error from public.jobs where id = $1`, [id]);
    expect(j.status).toBe("failed");
    expect(j.last_error).toMatch(/refusing/);
  });

  it("delete_account → the worker deletes the auth user and the user's files", async () => {
    const [x] = await createUsers(1, "Leaving");
    await uploadAs(x!, `avatars/${x!.id}/a.jpg`, await testJpeg(9));
    await rpc(x!.client, "delete_account");
    await w.runner.runUntilIdle({ kinds: ["auth.delete_user", "storage.delete"] });
    expect(await sql(`select 1 from auth.users where id = $1`, [x!.id])).toHaveLength(0);
    expect(await objectsUnder(`avatars/${x!.id}/`)).toEqual([]);
    // a second run is a no-op
    await rpc(admin, "enqueue_job", { p_kind: "auth.delete_user", p_payload: { user_id: x!.id } });
    expect(await w.runner.runUntilIdle({ kinds: ["auth.delete_user"] })).toBe(1);
    const [last] = (await jobs("auth.delete_user", { user_id: x!.id })).slice(-1);
    expect(last.status).toBe("done");
  });

  it("moderation.report completes and leaves the report open for review when no destination is configured", async () => {
    const { post } = await postPhoto(u[0]!, [g.id]);
    const id = await rpc(u[1]!.client, "report", { p_target_kind: "post", p_target_id: post.id, p_reason: "test" });
    await w.runner.runUntilIdle({ kinds: ["moderation.report"] });
    const [r] = await sql(`select status from public.reports where id = $1`, [id]);
    expect(r.status).toBe("open");
    expect(w.logs.some((l) => l.msg === "report awaiting review (no moderation destination configured)" && l.report_id === id)).toBe(true);
  });
});
