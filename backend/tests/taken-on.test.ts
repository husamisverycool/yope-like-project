// Library photos land on the day they were taken, date only (owner decision 34, research #5; migration 0050).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, createGroup, createMedia, createUsers, rpc, sql, type TestGroup, type TestUser } from './helpers';

let a: TestUser, b: TestUser;
let g: TestGroup;

beforeAll(async () => {
  [a, b] = await createUsers(2, 'Taken');
  g = await createGroup(a, [b], { tz: 'Europe/Paris' });
});

afterAll(closeDb);

const isoDay = (offsetDays: number, from = new Date()) => {
  const d = new Date(from.getTime() + offsetDays * 86_400_000);
  return d.toISOString().slice(0, 10);
};

async function post(user: TestUser, takenOn?: string) {
  const media = await createMedia(user, takenOn ? { takenOn } : {});
  const [p] = await rpc<any[]>(user.client, 'create_post', { p_media_id: media.id, p_group_ids: [g.id] });
  return p;
}

describe('taken_on (migration 0050)', () => {
  it('a library photo belongs to the day it was taken: visible_at is noon that day in the group zone', async () => {
    const day = isoDay(-40);
    const p = await post(a, day);
    expect(p.taken_on).toBe(day);
    const [row] = await sql(`select to_char(visible_at at time zone 'Europe/Paris', 'YYYY-MM-DD HH24:MI') as local from public.posts where id = $1`, [p.id]);
    expect(row.local).toBe(`${day} 12:00`);
    // its week is that week in the history, not this one
    const weeks = await rpc<any[]>(b.client, 'group_history_weeks', { p_group_id: g.id, p_limit: 52 });
    const holding = weeks.find((w) => w.post_ids.includes(p.id));
    expect(holding).toBeTruthy();
    expect(new Date(holding.week_start).getTime()).toBeLessThan(Date.now() - 30 * 86_400_000);
    // the chat still has it now
    const [msg] = await sql(`select created_at from public.messages where post_id = $1`, [p.id]);
    expect(Date.now() - new Date(msg.created_at).getTime()).toBeLessThan(60_000);
  });

  it('a camera photo (no taken_on) and a future date stay at the time they were posted', async () => {
    const camera = await post(a);
    expect(camera.taken_on).toBeNull();
    expect(new Date(camera.visible_at).getTime()).toBe(new Date(camera.created_at).getTime());
    const future = await post(a, isoDay(1));
    expect(new Date(future.visible_at).getTime()).toBe(new Date(future.created_at).getTime());
    await expect(createMedia(a, { takenOn: '1800-01-01' })).rejects.toThrow();
  });

  it('On This Day matches the day the photo was taken', async () => {
    const lastYearToday = `${new Date().getUTCFullYear() - 1}${isoDay(0).slice(4)}`;
    const p = await post(b, lastYearToday);
    const rows = await rpc<any[]>(a.client, 'on_this_day', { p_group_id: g.id, p_local_date: isoDay(0) });
    expect(rows.map((r) => r.post_id)).toContain(p.id);
    const mine = await rpc<any[]>(b.client, 'my_memories', { p_from: isoDay(0), p_days: 1, p_time_zone: 'Europe/Paris' });
    expect(mine.map((r) => r.post_id)).toContain(p.id);
  });
});
