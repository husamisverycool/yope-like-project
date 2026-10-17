// Server-side throttles for silent widget refreshes (docs/PLATFORM_CONSTRAINTS.md §1.3, §1.4, §1.6;
// docs/WIDGET_REFRESH.md). In memory: the worker runs as one instance (docs/OWNER_SETUP.md §7);
// a restart forgets the history, which can at most let one extra push per device through.

/** Background push: "don't try to send more than two or three per hour" [BG] → 2 per rolling hour. */
export const BACKGROUND_MAX_PER_HOUR = 2;
const HOUR_MS = 60 * 60_000;

export class WidgetThrottle {
  private background = new Map<string, number[]>();
  /** what each device last received per group (device|group → state key), to skip repeats */
  private delivered = new Map<string, string>();

  /** null = may send now; otherwise the earliest time it may. */
  backgroundNextAt(token: string, now: number): number | null {
    const recent = (this.background.get(token) ?? []).filter((t) => now - t < HOUR_MS);
    this.background.set(token, recent);
    if (recent.length < BACKGROUND_MAX_PER_HOUR) return null;
    return (recent[0] as number) + HOUR_MS;
  }

  recordBackground(token: string, now: number): void {
    const recent = (this.background.get(token) ?? []).filter((t) => now - t < HOUR_MS);
    recent.push(now);
    this.background.set(token, recent);
  }

  alreadyDelivered(token: string, groupId: string, stateKey: string): boolean {
    return this.delivered.get(`${token}|${groupId}`) === stateKey;
  }

  recordDelivered(token: string, groupId: string, stateKey: string): void {
    this.delivered.set(`${token}|${groupId}`, stateKey);
  }

  reset(): void {
    this.background.clear();
    this.delivered.clear();
  }
}
