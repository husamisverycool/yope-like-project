// schedule_daily_invitations: one deterministic instant per (group, local date),
// shared by every member, inside the group's waking window, across DST changes.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  admin,
  closeDb,
  createGroup,
  createUsers,
  rpc,
  select,
  setConfig,
  sql,
  type TestGroup,
  type TestUser,
} from './helpers';

let users: TestUser[];
let ny: TestGroup; // America/New_York 09:00-21:00
let london: TestGroup; // Europe/London 07:30-23:00
let lordHowe: TestGroup; // Australia/Lord_Howe (30-minute DST shift) 08:00-20:00
let night: TestGroup; // wraps past midnight 22:00-02:00
let noWindow: TestGroup;
let paused: TestGroup;

const schedule = (date: string) => rpc<any[]>(admin, 'schedule_daily_invitations', { p_for_utc_date: date });
const mine = (rows: any[], g: TestGroup) => rows.find((r) => r.group_id === g.id);

beforeAll(async () => {
  users = await createUsers(6, 'Inv');
  ny = await createGroup(users[0], [users[1], users[2]], { tz: 'America/New_York', start: '09:00', end: '21:00' });
  london = await createGroup(users[3], [], { tz: 'Europe/London', start: '07:30', end: '23:00' });
  lordHowe = await createGroup(users[4], [], { tz: 'Australia/Lord_Howe', start: '08:00', end: '20:00' });
  night = await createGroup(users[5], [], { tz: 'Europe/Berlin', start: '22:00', end: '02:00' });
  noWindow = await createGroup(users[0], [], { tz: 'Asia/Tokyo' });
  paused = await createGroup(users[1], [], { tz: 'UTC', start: '09:00', end: '21:00' });
  await rpc(users[1].client, 'set_group_invitation_paused', { p_group_id: paused.id, p_paused: true });
});

afterAll(closeDb);

describe('fires_at computation (all days, many zones)', () => {
  it('stays inside the waking window on every day of a year, including DST changes', async () => {
    const zones = [
      'America/New_York',
      'Europe/London',
      'Europe/Paris',
      'Australia/Lord_Howe',
      'America/Santiago',
      'Pacific/Chatham',
      'Asia/Kolkata',
    ];
    const windows = [
      ['09:00', '21:00'],
      ['01:00', '04:00'], // spans the DST switch hour itself
      ['07:30', '23:00'],
    ];
    const rows = await sql<{ violations: number; checked: number }>(
      `with params as (
         select z.tz, w.s::time as s, w.e::time as e, d::date as d, gen_random_uuid() as g
         from unnest($1::text[]) as z(tz)
         cross join (select * from unnest($2::text[], $3::text[]) as t(s, e)) w
         cross join generate_series(date '2026-10-16', date '2027-10-15', interval '1 day') as d
       ), computed as (
         select p.*, private.invitation_fires_at(p.g, p.d, p.tz, p.s, p.e, 120) as f from params p
       )
       select count(*) filter (where
                (f at time zone tz)::date <> d
             or (f at time zone tz)::time < s
             or ((f + interval '120 seconds') at time zone tz)::time > e
             or f <> private.invitation_fires_at(g, d, tz, s, e, 120)  -- deterministic
           )::int as violations,
           count(*)::int as checked
       from computed`,
      [zones, windows.map((w) => w[0]), windows.map((w) => w[1])],
    );
    expect(rows[0].checked).toBe(7 * 3 * 365);
    expect(rows[0].violations).toBe(0);
  });

  it('handles window edges that fall on a DST transition (ambiguous or skipped wall times)', async () => {
    // [zone, local date, start, end] — each edge sits on a transition of that day
    const cases: [string, string, string, string][] = [
      ['America/Santiago', '2027-04-03', '07:30', '23:00'], // end repeated (24:00 -> 23:00 fall-back)
      ['America/New_York', '2027-03-14', '01:00', '02:30'], // end skipped (02:00 -> 03:00)
      ['America/New_York', '2027-03-14', '02:30', '06:00'], // start skipped
      ['America/New_York', '2026-11-01', '01:30', '05:00'], // start repeated
      ['America/New_York', '2026-11-01', '00:00', '01:30'], // end repeated
      ['Europe/London', '2026-10-24', '22:00', '01:30'], // wraps; end repeated on 10-25
      ['Australia/Lord_Howe', '2027-04-04', '00:00', '01:45'], // 30-minute repeat
      ['Australia/Lord_Howe', '2027-10-03', '01:00', '02:15'], // 30-minute gap
    ];
    for (const [tz, d, s, e] of cases) {
      const [r] = await sql<{ violations: number; n: number }>(
        `with x as (
           select private.invitation_fires_at(gen_random_uuid(), $2::date, $1, $3::time, $4::time, 120) as f
             from generate_series(1, 3000))
         select count(*) filter (where
                  (f at time zone $1) < ($2::date + $3::time)
               or ((f + interval '120 seconds') at time zone $1)
                    > ($2::date + $4::time + case when $4::time <= $3::time then interval '1 day' else interval '0' end)
               or (f at time zone $1)::time not between least($3::time, $4::time) and greatest($3::time, $4::time)
                  and $4::time > $3::time
               or (((f + interval '120 seconds') at time zone $1)::time > $4::time and $4::time > $3::time)
             )::int as violations,
                count(*)::int as n
           from x`,
        [tz, d, s, e],
      );
      expect(r.n).toBe(3000);
      expect(r.violations, `${tz} ${d} ${s}-${e}`).toBe(0);
    }
  });

  it('spreads instants across the window (not a constant)', async () => {
    const rows = await sql<{ distinct_minutes: number }>(
      `select count(distinct date_trunc('minute', (private.invitation_fires_at(gen_random_uuid(), date '2027-01-10',
                'Europe/Paris', '09:00', '21:00', 120) at time zone 'Europe/Paris')::time))::int as distinct_minutes
         from generate_series(1, 200)`,
    );
    expect(rows[0].distinct_minutes).toBeGreaterThan(150);
  });
});

describe('schedule_daily_invitations', () => {
  it('schedules every active group once, idempotently, with the configured window length', async () => {
    const date = '2026-11-01'; // US DST ends that night
    const first = await schedule(date);
    const a = mine(first, ny);
    expect(a.created).toBe(true);
    expect(new Date(a.closes_at).getTime() - new Date(a.fires_at).getTime()).toBe(120_000);
    const again = await schedule(date);
    const b = mine(again, ny);
    expect(b.created).toBe(false);
    expect(b.invitation_id).toBe(a.invitation_id);
    expect(b.fires_at).toBe(a.fires_at);

    // jobs: fire at fires_at, compose the collage at closes_at
    const jobs = await sql(
      `select kind, run_at from public.jobs where payload ->> 'invitation_id' = $1 order by kind`,
      [a.invitation_id],
    );
    expect(jobs.map((j: any) => j.kind)).toEqual(['collage.compose', 'invitation.fire']);
    expect(new Date(jobs[0].run_at).getTime()).toBe(new Date(a.closes_at).getTime());
    expect(new Date(jobs[1].run_at).getTime()).toBe(new Date(a.fires_at).getTime());
  });

  it('is deterministic: a re-run after deletion gives the same instant', async () => {
    const date = '2026-11-02';
    const a = mine(await schedule(date), ny);
    await sql(`delete from public.daily_invitations where id = $1`, [a.invitation_id]);
    const b = mine(await schedule(date), ny);
    expect(b.created).toBe(true);
    expect(b.invitation_id).not.toBe(a.invitation_id);
    expect(b.fires_at).toBe(a.fires_at);
  });

  it('stays inside each group window across DST changes', async () => {
    const cases: [TestGroup, string, string, string, string][] = [
      [ny, '2026-11-01', 'America/New_York', '09:00', '21:00'],
      [ny, '2027-03-14', 'America/New_York', '09:00', '21:00'],
      [london, '2026-10-25', 'Europe/London', '07:30', '23:00'],
      [london, '2027-03-28', 'Europe/London', '07:30', '23:00'],
      [lordHowe, '2027-04-04', 'Australia/Lord_Howe', '08:00', '20:00'],
    ];
    for (const [g, date, tz, s, e] of cases) {
      const r = mine(await schedule(date), g);
      expect(r.created !== null && r.skipped_reason === null, `${tz} ${date}`).toBe(true);
      const [local] = await sql<{ d: string; f: string; c: string }>(
        `select to_char(($1::timestamptz at time zone $3)::date, 'YYYY-MM-DD') as d,
                to_char($1::timestamptz at time zone $3, 'HH24:MI:SS') as f,
                to_char($2::timestamptz at time zone $3, 'HH24:MI:SS') as c`,
        [r.fires_at, r.closes_at, tz],
      );
      expect(local.d).toBe(date);
      expect(local.f >= `${s}:00`, `${tz} ${date} ${local.f}`).toBe(true);
      expect(local.c <= `${e}:00`, `${tz} ${date} ${local.c}`).toBe(true);
    }
  });

  it('handles a window that wraps past midnight', async () => {
    const r = mine(await schedule('2027-01-20'), night);
    const [local] = await sql<{ t: string; d: string }>(
      `select to_char($1::timestamptz at time zone 'Europe/Berlin', 'HH24:MI') as t,
              to_char(($1::timestamptz at time zone 'Europe/Berlin')::date, 'YYYY-MM-DD') as d`,
      [r.fires_at],
    );
    expect(local.t >= '22:00' || local.t < '02:00').toBe(true);
    expect(['2027-01-20', '2027-01-21']).toContain(local.d);
  });

  it('skips paused groups and groups without a known waking window; uses the default window once sourced', async () => {
    const rows = await schedule('2026-12-01');
    expect(mine(rows, paused)).toBeUndefined();
    expect(mine(rows, noWindow).skipped_reason).toBe('waking_window_not_set');
    expect(mine(rows, noWindow).invitation_id).toBeNull();
    try {
      await setConfig('default_waking_start', '10:00');
      await setConfig('default_waking_end', '18:00');
      const r = mine(await schedule('2026-12-01'), noWindow);
      expect(r.created).toBe(true);
      const [t] = await sql<{ t: string }>(`select to_char($1::timestamptz at time zone 'Asia/Tokyo', 'HH24:MI') as t`, [
        r.fires_at,
      ]);
      expect(t.t >= '10:00' && t.t < '18:00').toBe(true);
    } finally {
      await setConfig('default_waking_start', null);
      await setConfig('default_waking_end', null);
    }
  });

  it('never schedules an instant in the past', async () => {
    const r = mine(await schedule('2026-10-01'), ny);
    expect(r.skipped_reason).toBe('window_passed');
    expect(r.invitation_id).toBeNull();
  });

  it('every member sees the same invitation, and only once it has fired', async () => {
    const r = mine(await schedule('2026-11-05'), ny);
    for (const u of ny.members) {
      const rows = await select(u.client, 'daily_invitations', (q) => q.eq('id', r.invitation_id));
      expect(rows).toEqual([]); // the moment is still a surprise
    }
    await sql(
      `update public.daily_invitations set fires_at = now() - interval '5 seconds', closes_at = now() + interval '115 seconds' where id = $1`,
      [r.invitation_id],
    );
    const seen = new Set<string>();
    for (const u of ny.members) {
      const rows = await select(u.client, 'daily_invitations', (q) => q.eq('id', r.invitation_id));
      expect(rows).toHaveLength(1);
      seen.add(rows[0].fires_at);
    }
    expect(seen.size).toBe(1);
    // a non-member never sees it
    const outsider = users[3];
    expect(await select(outsider.client, 'daily_invitations', (q) => q.eq('id', r.invitation_id))).toEqual([]);
  });

  it('pausing or changing the hours cancels unfired invitations and their jobs', async () => {
    const r = mine(await schedule('2026-11-10'), ny);
    await rpc(ny.admin.client, 'set_group_invitation_hours', { p_group_id: ny.id, p_start: '12:00', p_end: '13:00' });
    expect(await sql(`select 1 from public.daily_invitations where id = $1`, [r.invitation_id])).toEqual([]);
    const jobs = await sql(`select status from public.jobs where payload ->> 'invitation_id' = $1`, [r.invitation_id]);
    expect(jobs.map((j: any) => j.status)).toEqual(['cancelled', 'cancelled']);
    const r2 = mine(await schedule('2026-11-10'), ny);
    const [t] = await sql<{ t: string }>(`select to_char($1::timestamptz at time zone 'America/New_York', 'HH24:MI') as t`, [
      r2.fires_at,
    ]);
    expect(t.t >= '12:00' && t.t < '13:00').toBe(true);

    await rpc(ny.admin.client, 'set_group_invitation_paused', { p_group_id: ny.id, p_paused: true });
    expect(await sql(`select 1 from public.daily_invitations where id = $1`, [r2.invitation_id])).toEqual([]);
    expect(mine(await schedule('2026-11-11'), ny)).toBeUndefined();
    await rpc(ny.admin.client, 'set_group_invitation_paused', { p_group_id: ny.id, p_paused: false });
    await rpc(ny.admin.client, 'set_group_invitation_hours', { p_group_id: ny.id, p_start: '09:00', p_end: '21:00' });
  });

  it('is service-role only', async () => {
    const { error } = await users[0].client.rpc('schedule_daily_invitations', { p_for_utc_date: '2026-11-01' });
    expect(error).not.toBeNull();
  });
});
