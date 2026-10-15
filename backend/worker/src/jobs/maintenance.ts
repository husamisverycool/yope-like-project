// storage.delete, auth.delete_user, moderation.report.

import { maybe } from "../db.js";
import { PermanentError, RetryableError } from "../errors.js";
import { Storage } from "../storage.js";
import { str, type JobContext } from "../services.js";

/** storage.delete {bucket, paths[], prefixes[]}: exact objects plus everything under each prefix. */
export async function storageDelete(ctx: JobContext): Promise<void> {
  const p = ctx.job.payload as { bucket?: string; paths?: unknown; prefixes?: unknown };
  const bucket = typeof p.bucket === "string" && p.bucket ? p.bucket : "media";
  const paths = Array.isArray(p.paths) ? p.paths.filter((x): x is string => typeof x === "string" && x !== "") : [];
  const prefixes = Array.isArray(p.prefixes) ? p.prefixes.filter((x): x is string => typeof x === "string" && x !== "") : [];
  for (const prefix of prefixes) {
    // a prefix must name a folder of a user or group, never the bucket root
    if (!/^(u|g|avatars)\/[0-9a-fA-F-]{36}\//.test(prefix)) throw new PermanentError(`refusing to delete prefix ${prefix}`);
  }
  const storage = bucket === "media" ? ctx.storage : new Storage(ctx.db, bucket);
  let removed = await storage.remove(paths);
  for (const prefix of prefixes) removed += await storage.removePrefix(prefix);
  ctx.log.info("storage objects deleted", { bucket, paths: paths.length, prefixes: prefixes.length, removed });
}

/** auth.delete_user {user_id}: the account's rows are already gone (delete_account); now the auth user. */
export async function authDeleteUser(ctx: JobContext): Promise<void> {
  const userId = str(ctx.job.payload, "user_id");
  const { error } = await ctx.db.auth.admin.deleteUser(userId);
  if (error) {
    const status = (error as { status?: number }).status;
    if (status === 404 || /not.?found/i.test(error.message)) {
      ctx.log.info("auth user already deleted", { user_id: userId });
      return;
    }
    throw new RetryableError(`auth.admin.deleteUser: ${error.message}`);
  }
  ctx.log.info("auth user deleted", { user_id: userId });
}

/**
 * moderation.report {report_id}: hands the report to the moderation destination. There is no
 * moderation tooling yet (docs/API.md §12.19); with MODERATION_WEBHOOK_URL set, the report is
 * POSTed there as JSON; otherwise it is logged and stays `open` in `reports` for review.
 */
export async function moderationReport(ctx: JobContext): Promise<void> {
  const id = str(ctx.job.payload, "report_id");
  const report = maybe(
    await ctx.db.from("reports").select("id, reporter_id, target_kind, target_id, reason, status, created_at").eq("id", id).maybeSingle(),
    "report",
  ) as Record<string, unknown> | null;
  if (!report) return;
  const url = ctx.config.moderationWebhookUrl;
  if (!url) {
    ctx.log.warn("report awaiting review (no moderation destination configured)", { report_id: id, target_kind: report.target_kind });
    return;
  }
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ type: "report", report }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) throw new RetryableError(`moderation webhook returned ${res.status}`);
  ctx.log.info("report sent to moderation", { report_id: id });
}
