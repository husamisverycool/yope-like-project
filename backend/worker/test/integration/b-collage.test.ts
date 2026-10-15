// (b) On-time answers compose a collage stored at the right path; a late answer posts normally
// and is excluded; collages compose for 1 and 30 answers.
import sharp from "sharp";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { closeDb, createGroup, createUsers, jobs, objectsUnder, postPhoto, sleep, sql, type TestGroup, type TestUser } from "../helpers/db.js";
import { startWorld, type World } from "../helpers/world.js";

let w: World;

beforeAll(async () => {
  w = await startWorld();
});
afterAll(async () => {
  await w.close();
  await closeDb();
});

/** An invitation that is open now and closes in `seconds`. */
async function openInvitation(groupId: string, seconds: number) {
  const [inv] = await sql(
    `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
     values ($1, current_date + (random() * 1000)::int, now() - interval '5 seconds', now() + make_interval(secs => $2), 'fired')
     returning id, closes_at`,
    [groupId, seconds],
  );
  await sql(`select private.enqueue('collage.compose', jsonb_build_object('invitation_id', $1::uuid, 'group_id', $2::uuid), 'collage.compose:' || $1, $3::timestamptz)`, [inv.id, groupId, inv.closes_at]);
  return { id: inv.id as string, closesAt: new Date(inv.closes_at) };
}

async function untilClosed(closesAt: Date) {
  const wait = closesAt.getTime() - Date.now() + 2500;
  if (wait > 0) await sleep(wait);
  await w.runner.runUntilIdle({ kinds: ["collage.compose", "media.renditions"] });
}

describe("same-moment collage", () => {
  let u: TestUser[];
  let g: TestGroup;

  beforeAll(async () => {
    u = await createUsers(5, "Col");
    g = await createGroup(u[0]!, u.slice(1), { name: "Collage group" });
  });

  it("composes only the on-time answers (first per member), stored under g/<group>/collages/<collage>/", async () => {
    const inv = await openInvitation(g.id, 8);
    const a = await postPhoto(u[0]!, [g.id], { p_invitation_id: inv.id }, { dual: true, seed: 11 });
    const b = await postPhoto(u[1]!, [g.id], { p_invitation_id: inv.id }, { seed: 12 });
    const c = await postPhoto(u[2]!, [g.id], { p_invitation_id: inv.id }, { dual: true, seed: 13 });
    const cAgain = await postPhoto(u[2]!, [g.id], { p_invitation_id: inv.id }, { seed: 14 }); // second on-time post of the same member
    expect([a.post.in_window, b.post.in_window, c.post.in_window, cAgain.post.in_window]).toEqual([true, true, true, true]);
    await untilClosed(inv.closesAt);
    const late = await postPhoto(u[3]!, [g.id], { p_invitation_id: inv.id }, { seed: 15 });
    expect(late.post.in_window).toBe(false); // an ordinary post, no "late" state
    expect(late.post.invitation_id).toBeNull();
    await w.runner.runUntilIdle({ kinds: ["collage.compose"] });

    const [col] = await sql(`select * from public.collages where invitation_id = $1`, [inv.id]);
    expect(col.status).toBe("ready");
    expect(col.option).toBe("B");
    expect(col.post_ids).toEqual([a.post.id, b.post.id, c.post.id]);
    const dir = `g/${g.id}/collages/${col.id}/`;
    expect(col.image_path).toMatch(new RegExp(`^${dir}[0-9a-f]{16}/display-1\\.jpg$`));
    expect(col.widget_path).toMatch(/\/widget\.jpg$/);
    expect(col.share_path).toMatch(/\/share-1\.jpg$/);
    const files = await objectsUnder(dir);
    expect(files.map((f) => f.split("/").pop()).sort()).toEqual(["display-1.jpg", "master-1.png", "share-1.jpg", "widget.jpg"]);
    const share = await sharp(await w.svc.storage.download(col.share_path)).metadata();
    expect([share.width, share.height, share.format]).toEqual([1080, 1920, "jpeg"]); // 9:16 Stories, ≥ 720×1280
    const master = await sharp(await w.svc.storage.download(files.find((f) => f.endsWith("master-1.png"))!)).metadata();
    expect([master.format, master.hasAlpha]).toEqual(["png", true]);
    const widget = await sharp(await w.svc.storage.download(col.widget_path)).metadata();
    expect(widget.width).toBe(1080);
    const [invRow] = await sql(`select status from public.daily_invitations where id = $1`, [inv.id]);
    expect(invRow.status).toBe("closed");
    expect((await jobs("widget.refresh", { group_id: g.id })).some((j) => j.status === "queued")).toBe(true);
    // composing again (a job may run twice) keeps the same collage
    await sql(`select private.enqueue('collage.compose', jsonb_build_object('invitation_id', $1::uuid, 'group_id', $2::uuid), null, now())`, [inv.id, g.id]);
    await w.runner.runUntilIdle({ kinds: ["collage.compose"] });
    const [same] = await sql(`select image_path from public.collages where invitation_id = $1`, [inv.id]);
    expect(same.image_path).toBe(col.image_path);
  });

  it("composes a collage for a single answer", async () => {
    const inv = await openInvitation(g.id, 4);
    const one = await postPhoto(u[4]!, [g.id], { p_invitation_id: inv.id }, { seed: 21 });
    await untilClosed(inv.closesAt);
    const [col] = await sql(`select * from public.collages where invitation_id = $1`, [inv.id]);
    expect(col.post_ids).toEqual([one.post.id]);
    expect((await objectsUnder(`g/${g.id}/collages/${col.id}/`)).length).toBe(4);
  });
});

describe("30 answers", () => {
  it("composes all 30 members' answers (option B: 3 pages of 12, 12 and 6)", async () => {
    const users = await createUsers(30, "Thirty");
    const g = await createGroup(users[0]!, users.slice(1), { name: "Thirty" });
    const inv = await openInvitation(g.id, 40);
    const posts: string[] = [];
    for (const [i, m] of users.entries()) posts.push((await postPhoto(m, [g.id], { p_invitation_id: inv.id }, { seed: 100 + i, dual: i % 9 !== 8 })).post.id);
    await untilClosed(inv.closesAt);
    const [col] = await sql(`select * from public.collages where invitation_id = $1`, [inv.id]);
    expect(col.status).toBe("ready");
    expect([...col.post_ids].sort()).toEqual([...posts].sort());
    const names = (await objectsUnder(`g/${g.id}/collages/${col.id}/`)).map((f) => f.split("/").pop()).sort();
    expect(names).toEqual(["display-1.jpg", "display-2.jpg", "display-3.jpg", "master-1.png", "master-2.png", "master-3.png", "share-1.jpg", "share-2.jpg", "share-3.jpg", "widget.jpg"]);
  }, 300_000);
});
