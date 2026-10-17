// Worker-side SQL (service role only): job queue and scheduler helpers.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  admin,
  closeDb,
  createGroup,
  createUsers,
  expectRpcError,
  postPhoto,
  rpc,
  inRolledBackTransaction,
  sql,
  type TestUser,
} from './helpers';

let u: TestUser[];
const kind = (k: string) => `test.${k}_${Math.random().toString(36).slice(2, 8)}`;

beforeAll(async () => {
  u = await createUsers(4, 'Wrk');
});

afterAll(closeDb);

describe('job queue', () => {
  it('enqueue -> claim -> complete', async () => {
    const k = kind('a');
    const id = await rpc<number>(admin, 'enqueue_job', { p_kind: k, p_payload: { x: 1 } });
    const claimed = await rpc<any[]>(admin, 'claim_jobs', { p_worker_id: 'w1', p_kinds: [k], p_limit: 5 });
    expect(claimed).toHaveLength(1);
    expect(claimed[0]).toMatchObject({ id, kind: k, status: 'running', attempts: 1, locked_by: 'w1', payload: { x: 1 } });
    expect(await rpc(admin, 'claim_jobs', { p_worker_id: 'w2', p_kinds: [k] })).toEqual([]);
    expect(await rpc(admin, 'complete_job', { p_job_id: id, p_worker_id: 'w2' })).toBe(false);
    expect(await rpc(admin, 'complete_job', { p_job_id: id, p_worker_id: 'w1' })).toBe(true);
    const [row] = await sql(`select status, finished_at from public.jobs where id = $1`, [id]);
    expect(row.status).toBe('done');
    expect(row.finished_at).not.toBeNull();
  });

  it('respects run_at and kinds', async () => {
    const k = kind('b');
    await rpc(admin, 'enqueue_job', { p_kind: k, p_run_at: new Date(Date.now() + 3600_000).toISOString() });
    expect(await rpc(admin, 'claim_jobs', { p_worker_id: 'w', p_kinds: [k] })).toEqual([]);
    const other = kind('c');
    await rpc(admin, 'enqueue_job', { p_kind: other });
    expect(await rpc(admin, 'claim_jobs', { p_worker_id: 'w', p_kinds: [k] })).toEqual([]);
    expect(await rpc(admin, 'claim_jobs', { p_worker_id: 'w', p_kinds: [other] })).toHaveLength(1);
  });

  it('concurrent claimers never get the same job (FOR UPDATE SKIP LOCKED)', async () => {
    const k = kind('d');
    for (let i = 0; i < 40; i++) await rpc(admin, 'enqueue_job', { p_kind: k, p_payload: { i } });
    const batches = await Promise.all(
      Array.from({ length: 8 }, (_, i) => rpc<any[]>(admin, 'claim_jobs', { p_worker_id: `w${i}`, p_kinds: [k], p_limit: 7 })),
    );
    const ids = batches.flat().map((j) => j.id);
    expect(new Set(ids).size).toBe(ids.length);
    expect(ids.length).toBe(40);
  });

  it('fail_job retries with exponential backoff, then fails for good', async () => {
    const k = kind('e');
    const id = await rpc<number>(admin, 'enqueue_job', { p_kind: k, p_max_attempts: 3 });
    const delays: number[] = [];
    for (let attempt = 1; attempt <= 3; attempt++) {
      await sql(`update public.jobs set run_at = now() where id = $1 and status = 'queued'`, [id]);
      const [j] = await rpc<any[]>(admin, 'claim_jobs', { p_worker_id: 'w', p_kinds: [k] });
      expect(j.attempts).toBe(attempt);
      const before = Date.now();
      const f = await rpc(admin, 'fail_job', { p_job_id: id, p_worker_id: 'w', p_error: `boom ${attempt}` });
      if (attempt < 3) {
        expect(f.status).toBe('queued');
        delays.push(Math.round((new Date(f.run_at).getTime() - before) / 1000));
      } else {
        expect(f.status).toBe('failed');
        expect(f.last_error).toBe('boom 3');
      }
    }
    expect(delays[0]).toBeGreaterThanOrEqual(29);
    expect(delays[0]).toBeLessThanOrEqual(31);
    expect(delays[1]).toBeGreaterThanOrEqual(59);
    expect(delays[1]).toBeLessThanOrEqual(61);
    await expectRpcError(rpc(admin, 'fail_job', { p_job_id: id, p_worker_id: 'w', p_error: 'x' }), 'job_not_found', 404);
  });

  it('fail_job with p_retry = false fails immediately', async () => {
    const k = kind('f');
    const id = await rpc<number>(admin, 'enqueue_job', { p_kind: k });
    await rpc(admin, 'claim_jobs', { p_worker_id: 'w', p_kinds: [k] });
    const f = await rpc(admin, 'fail_job', { p_job_id: id, p_worker_id: 'w', p_error: 'bad payload', p_retry: false });
    expect(f.status).toBe('failed');
  });

  it('re-claims jobs whose lock expired', async () => {
    const k = kind('g');
    const id = await rpc<number>(admin, 'enqueue_job', { p_kind: k });
    await rpc(admin, 'claim_jobs', { p_worker_id: 'dead-worker', p_kinds: [k] });
    await sql(`update public.jobs set locked_at = now() - interval '11 minutes' where id = $1`, [id]);
    const [j] = await rpc<any[]>(admin, 'claim_jobs', { p_worker_id: 'alive', p_kinds: [k] });
    expect(j).toMatchObject({ id, locked_by: 'alive', attempts: 2 });
    expect(await rpc(admin, 'complete_job', { p_job_id: id, p_worker_id: 'dead-worker' })).toBe(false);
  });

  it('dedupe keys collapse queued duplicates only', async () => {
    const k = kind('h');
    const key = `${k}:1`;
    const id1 = await rpc<number>(admin, 'enqueue_job', { p_kind: k, p_dedupe_key: key });
    const id2 = await rpc<number>(admin, 'enqueue_job', { p_kind: k, p_dedupe_key: key });
    expect(id2).toBe(id1);
    await rpc(admin, 'claim_jobs', { p_worker_id: 'w', p_kinds: [k] });
    const id3 = await rpc<number>(admin, 'enqueue_job', { p_kind: k, p_dedupe_key: key });
    expect(id3).not.toBe(id1);
    // the running one fails while a newer duplicate is queued -> cancelled, not requeued
    const f = await rpc(admin, 'fail_job', { p_job_id: id1, p_worker_id: 'w', p_error: 'x' });
    expect(f.status).toBe('cancelled');
  });

  it('jobs and ai_cost_log are invisible to clients', async () => {
    for (const t of ['jobs', 'ai_cost_log']) {
      const { error } = await u[0].client.from(t).select('*');
      expect(error?.code, t).toBe('42501');
    }
    for (const fn of ['enqueue_job', 'claim_jobs', 'complete_job', 'fail_job']) {
      const { error } = await u[0].client.rpc(fn, { p_kind: 'x.y', p_worker_id: 'w', p_job_id: 1, p_error: 'x' });
      expect(error, fn).not.toBeNull();
    }
  });
});

describe('due_weekly_recaps', () => {
  // Every call runs in a transaction that is rolled back: the config each case needs is set
  // only there, and the recaps it creates never become visible to other suites.
  type Recap = { group_id: string; week_start: string };
  const due = (q: (t: string, p?: unknown[]) => Promise<any[]>, at: string) =>
    q(`select group_id, week_start::text as week_start from public.due_weekly_recaps($1::timestamptz)`, [at]) as Promise<Recap[]>;
  const setIn = (q: (t: string, p?: unknown[]) => Promise<any[]>, key: string, value: string | null) =>
    q(`update public.app_config set value = $2::jsonb where key = $1`, [key, value === null ? null : JSON.stringify(value)]);
  /** default window 09:48-21:12 and no override, whatever the shared config holds */
  const sourcedDefaults = async (q: (t: string, p?: unknown[]) => Promise<any[]>) => {
    await setIn(q, 'default_waking_start', '09:48');
    await setIn(q, 'default_waking_end', '21:12');
    await setIn(q, 'weekly_recap_local_time', null);
  };
  async function groupWithPostAt(iso: string, opts: Parameters<typeof createGroup>[2]) {
    const g = await createGroup(u[0], [u[1]], opts);
    const p = await postPhoto(u[1], [g.id]);
    await sql(`update public.posts set created_at = $2 where id = $1`, [p.posts[0].id, iso]);
    return g;
  }

  it('without a recap time: at the end of the default waking window on Sunday, group time zone', async () => {
    const g = await groupWithPostAt('2026-11-04T10:00:00Z', { tz: 'Europe/Paris' }); // Wed
    const quiet = await createGroup(u[2], [], { tz: 'Europe/Paris' });
    await inRolledBackTransaction(async (q) => {
      await sourcedDefaults(q);
      // Sunday 2026-11-08, Paris = UTC+1: 21:11 not yet, 21:13 yes
      expect((await due(q, '2026-11-08T20:11:00Z')).filter((r) => r.group_id === g.id)).toEqual([]);
      const rows = await due(q, '2026-11-08T20:13:00Z');
      expect(rows.filter((r) => r.group_id === g.id)).toEqual([{ group_id: g.id, week_start: '2026-11-02' }]);
      expect(rows.filter((r) => r.group_id === quiet.id)).toEqual([]); // no posts that week
      const [recap] = await q(`select id, status, items from public.weekly_recaps where group_id = $1`, [g.id]);
      expect(recap).toMatchObject({ status: 'pending', items: [] });
      expect(await q(`select 1 from public.jobs where kind = 'recap.generate' and payload ->> 'recap_id' = $1`, [recap.id])).toHaveLength(1);
      // idempotent, also on the following days (catch-up)
      expect((await due(q, '2026-11-10T09:00:00Z')).filter((r) => r.group_id === g.id)).toEqual([]);
    });
  });

  it('a week whose only photo developed after it (overnight, migration 0027) gets no recap; the next week does', async () => {
    const g = await groupWithPostAt('2026-11-08T22:30:00Z', { tz: 'Europe/Paris' }); // taken Sun 23:30 local
    await sql(`update public.posts set revealed_at = '2026-11-09T08:00:00Z' where group_id = $1`, [g.id]); // Mon 09:00 local
    await inRolledBackTransaction(async (q) => {
      await sourcedDefaults(q);
      expect((await due(q, '2026-11-08T20:13:00Z')).filter((r) => r.group_id === g.id)).toEqual([]);
      expect((await due(q, '2026-11-15T20:13:00Z')).filter((r) => r.group_id === g.id)).toEqual([{ group_id: g.id, week_start: '2026-11-09' }]);
    });
  });

  it("uses the group's own waking-window end", async () => {
    const g = await groupWithPostAt('2026-11-04T15:00:00Z', { tz: 'America/New_York', start: '08:00', end: '20:00' });
    await inRolledBackTransaction(async (q) => {
      await sourcedDefaults(q);
      // Sunday 2026-11-08 20:00 EST = Monday 01:00Z
      expect((await due(q, '2026-11-09T00:59:00Z')).filter((r) => r.group_id === g.id)).toEqual([]);
      expect((await due(q, '2026-11-09T01:01:00Z')).filter((r) => r.group_id === g.id)).toEqual([{ group_id: g.id, week_start: '2026-11-02' }]);
    });
  });

  it('is DST-safe: the same local time on the Sundays clocks change (both directions)', async () => {
    // Europe/Paris falls back on Sunday 2026-10-25 (21:00 CET = 20:00Z) …
    const fall = await groupWithPostAt('2026-10-21T12:00:00Z', { tz: 'Europe/Paris', start: '09:00', end: '21:00' });
    // … and springs forward on Sunday 2027-03-28 (21:00 CEST = 19:00Z)
    const spring = await groupWithPostAt('2027-03-24T12:00:00Z', { tz: 'Europe/Paris', start: '09:00', end: '21:00' });
    // New York falls back on Sunday 2026-11-01 (23:30 EST = Monday 04:30Z)
    const ny = await groupWithPostAt('2026-10-28T12:00:00Z', { tz: 'America/New_York', start: '07:00', end: '23:30' });
    await inRolledBackTransaction(async (q) => {
      await sourcedDefaults(q);
      const mine = (rows: Recap[], g: { id: string }) => rows.filter((r) => r.group_id === g.id);
      expect(mine(await due(q, '2026-10-25T19:59:00Z'), fall)).toEqual([]);
      expect(mine(await due(q, '2026-10-25T20:01:00Z'), fall)).toEqual([{ group_id: fall.id, week_start: '2026-10-19' }]);
      expect(mine(await due(q, '2027-03-28T18:59:00Z'), spring)).toEqual([]);
      expect(mine(await due(q, '2027-03-28T19:01:00Z'), spring)).toEqual([{ group_id: spring.id, week_start: '2027-03-22' }]);
      expect(mine(await due(q, '2026-11-02T04:29:00Z'), ny)).toEqual([]);
      expect(mine(await due(q, '2026-11-02T04:31:00Z'), ny)).toEqual([{ group_id: ny.id, week_start: '2026-10-26' }]);
    });
  });

  it("a window that wraps past midnight ends early on Monday: still that week's recap", async () => {
    const g = await groupWithPostAt('2026-11-04T12:00:00Z', { tz: 'Europe/Berlin', start: '22:00', end: '02:00' });
    await inRolledBackTransaction(async (q) => {
      await sourcedDefaults(q);
      // Sunday 2026-11-08 22:00 → Monday 02:00 CET = 01:00Z
      expect((await due(q, '2026-11-08T21:30:00Z')).filter((r) => r.group_id === g.id)).toEqual([]);
      expect((await due(q, '2026-11-09T00:59:00Z')).filter((r) => r.group_id === g.id)).toEqual([]);
      expect((await due(q, '2026-11-09T01:01:00Z')).filter((r) => r.group_id === g.id)).toEqual([{ group_id: g.id, week_start: '2026-11-02' }]);
    });
  });

  it('weekly_recap_local_time overrides the waking-window end', async () => {
    const g = await groupWithPostAt('2026-11-04T10:00:00Z', { tz: 'Europe/Paris', start: '08:00', end: '23:00' });
    await inRolledBackTransaction(async (q) => {
      await sourcedDefaults(q);
      await setIn(q, 'weekly_recap_local_time', '18:00');
      expect((await due(q, '2026-11-08T16:59:00Z')).filter((r) => r.group_id === g.id)).toEqual([]);
      expect((await due(q, '2026-11-08T17:01:00Z')).filter((r) => r.group_id === g.id)).toEqual([{ group_id: g.id, week_start: '2026-11-02' }]);
    });
  });

  it('a group with no known waking window (no own hours, no default, no override) gets no recap', async () => {
    const g = await groupWithPostAt('2026-11-04T10:00:00Z', { tz: 'Asia/Tokyo' });
    await inRolledBackTransaction(async (q) => {
      await setIn(q, 'default_waking_start', null);
      await setIn(q, 'default_waking_end', null);
      await setIn(q, 'weekly_recap_local_time', null);
      expect((await due(q, '2026-11-15T12:00:00Z')).filter((r) => r.group_id === g.id)).toEqual([]);
    });
  });
});

describe('due_birthday_requests', () => {
  it('creates requests lead_days before, per group, for opted-in members only', async () => {
    const [h, m, optOut] = await createUsers(3, 'Bd');
    const g = await createGroup(m, [h, optOut], { tz: 'UTC' });
    const solo = await createGroup(h, [], { tz: 'UTC' }); // nobody to ask
    await rpc(h.client, 'set_birthday', { p_birthday: '1990-03-20', p_opt_in: true });
    await rpc(optOut.client, 'set_birthday', { p_birthday: '1990-03-20', p_opt_in: false });
    const run = (iso: string) => rpc<any[]>(admin, 'due_birthday_requests', { p_now: iso });
    expect((await run('2027-03-12T12:00:00Z')).filter((r) => r.group_id === g.id)).toEqual([]); // 8 days before
    const rows = (await run('2027-03-13T12:00:00Z')).filter((r) => [g.id, solo.id].includes(r.group_id));
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ group_id: g.id, honoree_id: h.id, birthday_date: '2027-03-20' });
    expect(new Date(rows[0].due_at).toISOString()).toBe('2027-03-20T00:00:00.000Z');
    expect((await run('2027-03-14T12:00:00Z')).filter((r) => r.group_id === g.id)).toEqual([]); // idempotent
  });

  it('Feb 29 birthdays are celebrated on Feb 28 in common years', async () => {
    const [h, m] = await createUsers(2, 'Leap');
    const g = await createGroup(m, [h], { tz: 'UTC' });
    await rpc(h.client, 'set_birthday', { p_birthday: '2000-02-29', p_opt_in: true });
    const rows = (await rpc<any[]>(admin, 'due_birthday_requests', { p_now: '2027-02-25T00:00:00Z' })).filter(
      (r) => r.group_id === g.id,
    );
    expect(rows.map((r) => r.birthday_date)).toEqual(['2027-02-28']);
  });
});

describe('due_tributes', () => {
  it('closes due requests; a tribute (and render job) only when someone contributed', async () => {
    const [h, m1, m2] = await createUsers(3, 'Tri');
    const g = await createGroup(m1, [h, m2]);
    const post = (await postPhoto(m1, [g.id])).posts[0].id;
    const mk = async () =>
      (await sql<{ id: string }>(
        `insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at)
         values ($1, $2, current_date + (random() * 1000)::int + 10, now() + interval '1 hour') returning id`,
        [g.id, h.id],
      ))[0].id;
    const withC = await mk();
    const without = await mk();
    await rpc(m1.client, 'contribute_tribute', { p_request_id: withC, p_post_id: post, p_line: 'yay' });
    await sql(`update public.tribute_requests set due_at = now() - interval '1 minute' where id in ($1, $2)`, [withC, without]);
    const tributes = await rpc<any[]>(admin, 'due_tributes', {});
    const mine = tributes.filter((t) => [withC, without].includes(t.request_id));
    expect(mine).toEqual([expect.objectContaining({ request_id: withC, honoree_id: h.id, status: 'pending', delivered_at: null })]);
    const closed = await sql(`select id from public.tribute_requests where id in ($1, $2) and closed_at is not null`, [withC, without]);
    expect(closed).toHaveLength(2);
    expect(await sql(`select 1 from public.jobs where kind = 'tribute.render' and payload ->> 'request_id' = $1`, [withC])).toHaveLength(1);
    expect((await rpc<any[]>(admin, 'due_tributes', {})).filter((t) => t.request_id === withC)).toEqual([]);
  });
});

describe('due_year_stories', () => {
  it('from December 1st (local), once per group that posted that year', async () => {
    const g = await createGroup(u[3], [], { tz: 'Pacific/Auckland' });
    const p = await postPhoto(u[3], [g.id]);
    await sql(`update public.posts set created_at = '2027-05-01T00:00:00Z' where id = $1`, [p.posts[0].id]);
    const run = (iso: string) => rpc<any[]>(admin, 'due_year_stories', { p_now: iso });
    expect((await run('2027-11-30T10:00:00Z')).filter((r) => r.group_id === g.id)).toEqual([]); // Nov 30 23:00 Auckland
    const rows = (await run('2027-11-30T11:30:00Z')).filter((r) => r.group_id === g.id); // Dec 1 00:30 Auckland
    expect(rows).toEqual([expect.objectContaining({ year: 2027, status: 'pending' })]);
    expect(await sql(`select 1 from public.jobs where kind = 'year.compute' and payload ->> 'year_story_id' = $1`, [rows[0].id])).toHaveLength(1);
    expect((await run('2027-12-15T00:00:00Z')).filter((r) => r.group_id === g.id)).toEqual([]);
  });

  it('refreshes each story once on 31 December at the end of the waking window, without a second creation (decision 31)', async () => {
    const g = await createGroup(u[3], [], { tz: 'Europe/Paris', start: '08:00', end: '22:00' });
    const p = await postPhoto(u[3], [g.id]);
    await sql(`update public.posts set created_at = '2028-03-01T10:00:00Z' where id = $1`, [p.posts[0].id]);
    const run = (iso: string) => rpc<any[]>(admin, 'due_year_stories', { p_now: iso });
    const [story] = (await run('2028-12-01T12:00:00Z')).filter((r) => r.group_id === g.id);
    const refreshes = () => sql(`select 1 from public.jobs where kind = 'year.recompute' and payload ->> 'year_story_id' = $1`, [story.id]);
    await run('2028-12-31T20:59:00Z'); // 21:59 Paris
    expect(await refreshes()).toHaveLength(0);
    expect((await run('2028-12-31T21:01:00Z')).filter((r) => r.group_id === g.id)).toEqual([]); // 22:01: no new story…
    expect(await refreshes()).toHaveLength(1); // …one refresh
    const [row] = await sql(`select refreshed_at, announced_at from public.year_stories where id = $1`, [story.id]);
    expect(row.refreshed_at).not.toBeNull();
    expect(row.announced_at).toBeNull(); // the worker announces; a refresh never does
    await run('2029-01-02T12:00:00Z');
    expect(await refreshes()).toHaveLength(1);
  });

  it('a self-tag on a photo of a ready story recomputes it; clients cannot run the scheduler', async () => {
    const [x, y] = await createUsers(2, 'YrTag');
    const g = await createGroup(x, [y], { tz: 'UTC' });
    const { posts } = await postPhoto(x, [g.id]);
    const [story] = await sql(
      `insert into public.year_stories (group_id, year, status, data, post_ids, generated_at) values ($1, 2026, 'ready', '{}'::jsonb, $2::uuid[], now()) returning id`,
      [g.id, [posts[0].id]],
    );
    const recomputes = () => sql(`select 1 from public.jobs where kind = 'year.recompute' and payload ->> 'year_story_id' = $1 and status = 'queued'`, [story.id]);
    const tag = await y.client.from('post_tags').insert({ post_id: posts[0].id, user_id: y.id });
    expect(tag.error).toBeNull();
    expect(await recomputes()).toHaveLength(1);
    const [kept] = await sql(`select status from public.year_stories where id = $1`, [story.id]);
    expect(kept.status).toBe('ready'); // stays readable while it is recomputed
    const untag = await y.client.from('post_tags').delete().eq('post_id', posts[0].id).eq('user_id', y.id);
    expect(untag.error).toBeNull();
    expect(await recomputes()).toHaveLength(1); // merged into the queued job
    const { error } = await x.client.rpc('due_year_stories', {});
    expect(error).not.toBeNull();
  });
});
