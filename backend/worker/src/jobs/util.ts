// Small queries shared by handlers.

import { selectIn, type Db } from "../db.js";

/** Block relations among/with `userIds`, as "a|b" keys in both directions. */
export async function blockedPairs(db: Db, userIds: string[]): Promise<Set<string>> {
  const out = new Set<string>();
  if (!userIds.length) return out;
  const rows = [
    ...(await selectIn<{ blocker_id: string; blocked_id: string }>(db, "blocks", "blocker_id, blocked_id", "blocker_id", userIds)),
    ...(await selectIn<{ blocker_id: string; blocked_id: string }>(db, "blocks", "blocker_id, blocked_id", "blocked_id", userIds)),
  ];
  for (const r of rows) {
    out.add(`${r.blocker_id}|${r.blocked_id}`);
    out.add(`${r.blocked_id}|${r.blocker_id}`);
  }
  return out;
}
