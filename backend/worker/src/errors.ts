// Error classes that decide what the job runner does with a failed job.
//
//   RetryableError / any unknown error -> fail_job(retry = true): backoff 30 s, 60 s, ... (docs/API.md §10)
//   PermanentError                     -> fail_job(retry = false): retrying cannot help
//   MissingCopyError / MissingTokenError -> retry: the copy author or design pass may add the value
//                                         (the job runs again after the backoff)

export class PermanentError extends Error {
  override name = "PermanentError";
}

export class RetryableError extends Error {
  override name = "RetryableError";
}

/** A user-facing string the worker needs is not in the generated copy table yet. */
export class MissingCopyError extends Error {
  override name = "MissingCopyError";
  constructor(public readonly key: string) {
    super(`missing copy key ${key} (see backend/worker/COPY_KEYS.md)`);
  }
}

/** A design value the worker needs is not in the generated tokens (or is BLOCKED). */
export class MissingTokenError extends Error {
  override name = "MissingTokenError";
  constructor(public readonly token: string, detail?: string) {
    super(`missing design token ${token}${detail ? ` (${detail})` : ""}`);
  }
}

export function errorMessage(e: unknown): string {
  if (e instanceof Error) return `${e.name}: ${e.message}`;
  return String(e);
}

export function isRetryable(e: unknown): boolean {
  return !(e instanceof PermanentError);
}
