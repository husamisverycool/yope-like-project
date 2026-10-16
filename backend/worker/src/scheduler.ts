// Scheduler loop (every minute, docs/API.md §10):
//   schedule_daily_invitations for today and tomorrow (UTC; each date is read as every group's
//   local date, which covers every time zone's "today"); arms precise wake-ups so the runner
//   dispatches invitation.fire at fires_at and closes windows (collage.compose, invitation.end)
//   at closes_at; then the due_* helpers: weekly recaps, birthday requests, tributes, year stories,
//   and overnight photos that have developed.
// The SQL helpers are idempotent, so overlapping or repeated ticks are harmless.

import { DbError, must, rpc } from "./db.js";
import type { Runner } from "./runner.js";
import type { Services } from "./services.js";
import { addDays, utcDate } from "./time.js";

export type TickStep = "invitations" | "arm" | "recaps" | "birthdays" | "tributes" | "years" | "developed";
export const ALL_STEPS: TickStep[] = ["invitations", "arm", "recaps", "birthdays", "tributes", "years", "developed"];

export interface TickOptions {
  /** steps to run (default all) */
  steps?: TickStep[];
  /** UTC dates passed to schedule_daily_invitations (default today and tomorrow) */
  dates?: string[];
}

export interface TickReport {
  at: string;
  invitations: { created: number; existing: number; skipped: Record<string, number> };
  armed: number;
  recaps: number | "config_missing";
  birthdayRequests: number;
  tributes: number;
  yearStories: number;
  developed: number;
  errors: string[];
}

const STEP_OF: Record<string, TickStep> = {
  schedule_daily_invitations: "invitations",
  arm: "arm",
  due_weekly_recaps: "recaps",
  due_birthday_requests: "birthdays",
  due_tributes: "tributes",
  due_year_stories: "years",
  due_developed_posts: "developed",
};

interface ScheduleRow {
  group_id: string;
  invitation_id: string | null;
  fires_at: string | null;
  closes_at: string | null;
  created: boolean;
  skipped_reason: string | null;
}

export class Scheduler {
  private timer: NodeJS.Timeout | null = null;
  private ticking: Promise<TickReport> | null = null;
  lastTick: TickReport | null = null;
  lastTickAt: number | null = null;

  constructor(
    private readonly svc: Services,
    private readonly runner: Runner | null,
    private readonly intervalMs = 60_000,
  ) {}

  start(): void {
    if (this.timer) return;
    const run = () => {
      void this.tick().catch((e) => this.svc.log.error("scheduler tick failed", { error: e }));
    };
    run();
    this.timer = setInterval(run, this.intervalMs);
  }

  async stop(): Promise<void> {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    await this.ticking?.catch(() => undefined);
  }

  async tick(now: Date = this.svc.now(), opts: TickOptions = {}): Promise<TickReport> {
    if (this.ticking) return this.ticking;
    this.ticking = this.doTick(now, opts).finally(() => {
      this.ticking = null;
    });
    return this.ticking;
  }

  private async doTick(now: Date, opts: TickOptions): Promise<TickReport> {
    const steps = new Set(opts.steps ?? ALL_STEPS);
    const report: TickReport = {
      at: now.toISOString(),
      invitations: { created: 0, existing: 0, skipped: {} },
      armed: 0,
      recaps: 0,
      birthdayRequests: 0,
      tributes: 0,
      yearStories: 0,
      developed: 0,
      errors: [],
    };
    const step = async (name: string, fn: () => Promise<void>) => {
      const key = STEP_OF[name];
      if (key && !steps.has(key)) return;
      try {
        await fn();
      } catch (e) {
        report.errors.push(`${name}: ${(e as Error).message}`);
        this.svc.log.error("scheduler step failed", { step: name, error: e });
      }
    };

    await step("schedule_daily_invitations", async () => {
      for (const d of opts.dates ?? [utcDate(now), addDays(utcDate(now), 1)]) {
        const rows = await rpc<ScheduleRow[]>(this.svc.db, "schedule_daily_invitations", { p_for_utc_date: d });
        for (const r of rows) {
          if (r.created) report.invitations.created++;
          else if (r.invitation_id) report.invitations.existing++;
          else if (r.skipped_reason) report.invitations.skipped[r.skipped_reason] = (report.invitations.skipped[r.skipped_reason] ?? 0) + 1;
        }
      }
    });

    await step("arm", async () => {
      // invitations firing or closing before the next tick: wake the runner exactly then
      const horizon = new Date(now.getTime() + this.intervalMs + 5_000).toISOString();
      const firing = must(
        await this.svc.db.from("daily_invitations").select("id, fires_at").eq("status", "scheduled").gte("fires_at", now.toISOString()).lte("fires_at", horizon),
        "upcoming invitations",
      ) as Array<{ id: string; fires_at: string }>;
      for (const r of firing) {
        this.runner?.wakeAt(new Date(r.fires_at), "invitation.fire");
        report.armed++;
      }
      const closing = must(
        await this.svc.db.from("daily_invitations").select("id, closes_at").in("status", ["scheduled", "fired"]).gte("closes_at", now.toISOString()).lte("closes_at", horizon),
        "closing invitations",
      ) as Array<{ id: string; closes_at: string }>;
      for (const r of closing) {
        this.runner?.wakeAt(new Date(r.closes_at), "invitation.end");
        this.runner?.wakeAt(new Date(r.closes_at), "collage.compose");
        report.armed++;
      }
    });

    await step("due_weekly_recaps", async () => {
      try {
        report.recaps = (await rpc<unknown[]>(this.svc.db, "due_weekly_recaps", { p_now: now.toISOString() })).length;
      } catch (e) {
        // weekly_recap_local_time is NULL until sourced: recaps stay off (docs/API.md §11)
        if (e instanceof DbError && /config_missing/.test(e.message)) report.recaps = "config_missing";
        else throw e;
      }
    });
    await step("due_birthday_requests", async () => {
      report.birthdayRequests = (await rpc<unknown[]>(this.svc.db, "due_birthday_requests", { p_now: now.toISOString() })).length;
    });
    await step("due_tributes", async () => {
      report.tributes = (await rpc<unknown[]>(this.svc.db, "due_tributes", { p_now: now.toISOString() })).length;
    });
    await step("due_year_stories", async () => {
      report.yearStories = (await rpc<unknown[]>(this.svc.db, "due_year_stories", { p_now: now.toISOString() })).length;
    });

    await step("due_developed_posts", async () => {
      report.developed = (await rpc<unknown[]>(this.svc.db, "due_developed_posts", { p_now: now.toISOString() })).length;
    });

    if (report.invitations.created || report.recaps || report.birthdayRequests || report.tributes || report.yearStories || report.developed) this.runner?.wake();
    this.lastTick = report;
    this.lastTickAt = Date.now();
    this.svc.log.info("scheduler tick", { ...report, at: undefined });
    return report;
  }
}
