// Time-zone helpers (IANA zones via Intl; no extra dependency).

export interface LocalParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
  /** ISO weekday 1 = Monday … 7 = Sunday */
  isoDow: number;
}

const formatters = new Map<string, Intl.DateTimeFormat>();
function formatter(tz: string): Intl.DateTimeFormat {
  let f = formatters.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      weekday: "short",
    });
    formatters.set(tz, f);
  }
  return f;
}

const DOW: Record<string, number> = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

export function localParts(instant: Date, tz: string): LocalParts {
  const parts = Object.fromEntries(formatter(tz).formatToParts(instant).map((p) => [p.type, p.value]));
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
    isoDow: DOW[parts.weekday as string] ?? 0,
  };
}

/** Offset of `tz` from UTC at `instant`, in milliseconds (local = utc + offset). */
export function tzOffsetMs(instant: Date, tz: string): number {
  const p = localParts(instant, tz);
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return asUtc - Math.floor(instant.getTime() / 1000) * 1000;
}

/** The instant at which the wall clock in `tz` reads `date` 00:00 (first occurrence). */
export function localMidnight(date: string, tz: string): Date {
  const [y, m, d] = date.split("-").map(Number) as [number, number, number];
  const guess = Date.UTC(y, m - 1, d);
  // two passes settle DST transitions
  let t = guess - tzOffsetMs(new Date(guess), tz);
  t = guess - tzOffsetMs(new Date(t), tz);
  return new Date(t);
}

export function addDays(date: string, days: number): string {
  const [y, m, d] = date.split("-").map(Number) as [number, number, number];
  return new Date(Date.UTC(y, m - 1, d + days)).toISOString().slice(0, 10);
}

export function utcDate(instant: Date): string {
  return instant.toISOString().slice(0, 10);
}

/** "HH:MM" or "HH:MM:SS" → minutes since midnight. */
export function minutesOf(time: string): number {
  const [h, m] = time.split(":").map(Number) as [number, number];
  return h * 60 + m;
}

/**
 * Quiet hours (notification_settings): a daily interval [start, end) in the person's zone;
 * end <= start wraps past midnight; start == end or null means none. Same rule as the apps
 * (ios QuietHours.swift, android QuietHours.kt).
 */
export function isQuietAt(start: string | null, end: string | null, tz: string | null, instant: Date): boolean {
  if (!start || !end || !tz) return false;
  const s = minutesOf(start);
  const e = minutesOf(end);
  if (s === e) return false;
  let p: LocalParts;
  try {
    p = localParts(instant, tz);
  } catch {
    return false;
  }
  const now = p.hour * 60 + p.minute;
  return s < e ? now >= s && now < e : now >= s || now < e;
}

export function unixSeconds(d: Date | string): number {
  return Math.floor((typeof d === "string" ? new Date(d) : d).getTime() / 1000);
}

/** A time of day in `tz` as the platform formats it in English ("7:30 PM"). */
export function localTime(instant: Date | string, tz: string): string {
  return new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit", timeZone: tz }).format(new Date(instant));
}

/** A plan's day and time in `tz` as the platform formats it in English ("Saturday, October 24 at 7:30 PM"; day only when all-day). */
export function localWhen(plan: { starts_at: string; all_day: boolean }, tz: string): string {
  const day = new Intl.DateTimeFormat("en-US", { weekday: "long", month: "long", day: "numeric", timeZone: tz }).format(new Date(plan.starts_at));
  return plan.all_day ? day : `${day} at ${localTime(plan.starts_at, tz)}`;
}
