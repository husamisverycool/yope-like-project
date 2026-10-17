// User-facing text for the worker (push titles/bodies, recap template, tribute cards), read from
// the generated copy table (backend/worker/src/generated/copy.ts ← design/copy.json, via
// `node tools/designgen.mjs`). docs/CONVENTIONS.md §5: no literal user-facing string in code.
//
// Keys may not exist yet: copyText throws MissingCopyError, the job fails and is retried later.
// Every key below is listed for the copy author in backend/worker/COPY_KEYS.md.

import { copy as generatedCopy } from "./generated/copy.js";
import { MissingCopyError, PermanentError } from "./errors.js";

export interface CopyKeySpec {
  /** placeholders the worker fills ({name}) */
  params: readonly string[];
  /** docs/SURFACES.md surface id */
  surface: string;
  meaning: string;
}

export const WORKER_COPY_KEYS = {
  "notifications.push.dailyInvitation.title": {
    params: ["group"],
    surface: "daily.notification",
    meaning: "Title of the daily same-moment invitation (iOS Live Activity start alert, iOS alert fallback, Android ongoing countdown notification).",
  },
  "notifications.push.dailyInvitation.body": {
    params: ["group"],
    surface: "daily.notification",
    meaning: "Body of the daily invitation. No urgency, guilt or 'late' wording (docs/SPEC_FLAGS.md T4).",
  },
  "notifications.push.newPost.title": {
    params: ["name", "group"],
    surface: "notifications.push",
    meaning: "Title when a member posts a photo in a group ({name} = poster's first name).",
  },
  "notifications.push.newPost.body": {
    params: ["name", "group"],
    surface: "notifications.push",
    meaning: "Body of the new-photo notification. No counts.",
  },
  "notifications.push.reaction.title": {
    params: ["name", "emoji", "group"],
    surface: "notifications.push",
    meaning: "Title when someone reacts to your photo ({emoji} = the emoji they chose).",
  },
  "notifications.push.reaction.body": {
    params: ["name", "emoji", "group"],
    surface: "notifications.push",
    meaning: "Body of the reaction notification. Never a number of reactions.",
  },
  "notifications.push.reply.title": {
    params: ["name", "group"],
    surface: "notifications.push",
    meaning: "Title when someone replies to your photo or message.",
  },
  "notifications.push.reply.body.text": {
    params: ["name", "group", "message"],
    surface: "notifications.push",
    meaning: "Body of a text reply ({message} = the reply text, shortened by the worker only if over the push size limit).",
  },
  "notifications.push.reply.body.voice": {
    params: ["name", "group"],
    surface: "notifications.push",
    meaning: "Body of a voice-message reply.",
  },
  "notifications.push.reply.body.photo": {
    params: ["name", "group"],
    surface: "notifications.push",
    meaning: "Body when someone replies to your photo with a photo.",
  },
  "notifications.push.recapReady.title": {
    params: ["group"],
    surface: "notifications.push",
    meaning: "Title when the group's weekly recap is ready.",
  },
  "notifications.push.recapReady.body": {
    params: ["group"],
    surface: "notifications.push",
    meaning: "Body of the recap-ready notification.",
  },
  "notifications.push.yearStory.title": {
    params: ["group", "year"],
    surface: "notifications.push",
    meaning: "Title when the group's year story is first ready (sent once; the 31 December refresh never notifies).",
  },
  "notifications.push.yearStory.body": {
    params: ["group", "year"],
    surface: "notifications.push",
    meaning: "Body of the year-story-ready notification ({year} = the story's year). No counts.",
  },
  "notifications.push.birthdayRequest.title": {
    params: ["name", "group"],
    surface: "notifications.push",
    meaning: "Title of the private request to contribute to {name}'s birthday tribute (never sent to {name}).",
  },
  "notifications.push.birthdayRequest.body": {
    params: ["name", "group"],
    surface: "notifications.push",
    meaning: "Body of the birthday contribution request. One request, no reminders (docs/SPEC_FLAGS.md T5).",
  },
  "notifications.push.tribute.title": {
    params: ["group"],
    surface: "notifications.push",
    meaning: "Title of the notification to the birthday person that their tribute is ready.",
  },
  "notifications.push.tribute.body": {
    params: ["group"],
    surface: "notifications.push",
    meaning: "Body of the tribute-for-you notification. No count of contributors.",
  },
  "notifications.push.selfieReaction.title": {
    params: ["name", "group"],
    surface: "notifications.push",
    meaning: "Title when a member reacts to your photo with a selfie (selfie.reaction).",
  },
  "notifications.push.selfieReaction.body": {
    params: ["name", "group"],
    surface: "notifications.push",
    meaning: "Body of the selfie-reaction notification. Never a number of reactions.",
  },
  "notifications.push.planNew.title": {
    params: ["name", "group", "title"],
    surface: "notifications.push",
    meaning: "Title when a member makes a plan in the group ({title} = the plan's title).",
  },
  "notifications.push.planNew.body": {
    params: ["name", "group", "title"],
    surface: "notifications.push",
    meaning: "Body of the new-plan notification: an invitation, never an obligation (tenet 5).",
  },
  "notifications.push.planTomorrow.title": {
    params: ["group", "title"],
    surface: "notifications.push",
    meaning: "Title of the one reminder 24 hours before a plan, to members who answered Going or Maybe.",
  },
  "notifications.push.planTomorrow.body.timed": {
    params: ["group", "title", "time"],
    surface: "notifications.push",
    meaning: "Body of the day-before reminder of a plan with a start time ({time} in the group's time zone). No count of who is going.",
  },
  "notifications.push.planTomorrow.body.allDay": {
    params: ["group", "title"],
    surface: "notifications.push",
    meaning: "Body of the day-before reminder of an all-day plan.",
  },
  "notifications.push.planChanged.title": {
    params: ["name", "group", "title"],
    surface: "notifications.push",
    meaning: "Title when a plan's day, time or place changes, to Going and Maybe.",
  },
  "notifications.push.planChanged.body.time": {
    params: ["name", "group", "title", "when"],
    surface: "notifications.push",
    meaning: "Body when the day or time changed ({when} = the new day and time, or day for an all-day plan).",
  },
  "notifications.push.planChanged.body.place": {
    params: ["name", "group", "title", "place"],
    surface: "notifications.push",
    meaning: "Body when only the place changed ({place} = the new place).",
  },
  "notifications.push.planCanceled.title": {
    params: ["name", "group", "title"],
    surface: "notifications.push",
    meaning: "Title when a plan is cancelled, to Going and Maybe.",
  },
  "notifications.push.planCanceled.body": {
    params: ["name", "group", "title"],
    surface: "notifications.push",
    meaning: "Body of the plan-cancelled notification ({name} = who cancelled it).",
  },
  "camera.overnight.push.title": {
    params: ["group"],
    surface: "camera.overnight",
    meaning: "Title when the group's overnight photos have developed (one per group and reveal time).",
  },
  "camera.overnight.push.body": {
    params: ["group"],
    surface: "camera.overnight",
    meaning: "Body of the photos-developed notification. No count of photos, no names.",
  },
  "week.recap.template": {
    params: ["group"],
    surface: "week.recap",
    meaning: "Deterministic recap text used when no AI text is available or the AI text fails the copy rules.",
  },
  "birthday.tribute.titleCard": {
    params: ["name"],
    surface: "birthday.tribute",
    meaning: "Title card at the start of the tribute video ({name} = birthday person's first name).",
  },
  "birthday.tribute.endCard": {
    params: [],
    surface: "birthday.tribute",
    meaning: "End card of the tribute video.",
  },
} as const satisfies Record<string, CopyKeySpec>;

export type WorkerCopyKey = keyof typeof WORKER_COPY_KEYS;
export type CopyParams = Record<string, string | number>;

let table: Readonly<Record<string, string>> = generatedCopy as Readonly<Record<string, string>>;

/** Tests inject a copy table; pass null to restore the generated one. */
export function setCopyTable(t: Readonly<Record<string, string>> | null): void {
  table = t ?? (generatedCopy as Readonly<Record<string, string>>);
}

export function hasCopy(key: WorkerCopyKey): boolean {
  return Object.prototype.hasOwnProperty.call(table, key);
}

/**
 * The text of `key` with its {placeholders} filled from `params`.
 * Throws MissingCopyError when the key is not in the copy table, and PermanentError when the
 * text uses a placeholder the worker does not provide for that key (a contract error between
 * COPY_KEYS.md and design/copy.json that retrying cannot fix).
 */
export function copyText(key: WorkerCopyKey, params: CopyParams = {}): string {
  if (!hasCopy(key)) throw new MissingCopyError(key);
  const text = table[key] as string;
  const allowed: readonly string[] = WORKER_COPY_KEYS[key].params;
  return text.replace(/\{([a-zA-Z_][a-zA-Z0-9_]*)\}/g, (_m, p: string) => {
    if (!allowed.includes(p) || params[p] === undefined) {
      throw new PermanentError(`copy ${key} uses {${p}}, which the worker does not provide (allowed: ${allowed.join(", ")})`);
    }
    return String(params[p]);
  });
}
