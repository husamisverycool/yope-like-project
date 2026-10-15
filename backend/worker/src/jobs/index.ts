// Job kind → handler, and which lane runs it. Every kind the migrations enqueue has a handler
// (test/unit/registry.test.ts greps the SQL), plus the kinds the worker enqueues itself.

import type { WorkerConfig } from "../config.js";
import type { LaneSpec } from "../runner.js";
import type { Handler } from "../services.js";
import { collageCompose, collageRecompose } from "./collage.js";
import { invitationEnd, invitationFire } from "./invitation.js";
import { authDeleteUser, moderationReport, storageDelete } from "./maintenance.js";
import { mediaRenditions } from "./media.js";
import { pushBirthdayRequest, pushNewMessage, pushNewPost, pushReaction, pushRecapReady, pushTribute } from "./push.js";
import { recapGenerate } from "./recap.js";
import { tributeRender } from "./tribute.js";
import { widgetRefresh } from "./widget.js";
import { yearCompute } from "./year.js";

export const REALTIME_KINDS: Record<string, Handler> = {
  "invitation.fire": invitationFire,
  "invitation.end": invitationEnd, // worker-enqueued at closes_at
  "push.new_post": pushNewPost,
  "push.new_message": pushNewMessage,
  "push.reaction": pushReaction,
  "push.birthday_request": pushBirthdayRequest,
  "push.recap_ready": pushRecapReady, // worker-enqueued by recap.generate
  "push.tribute": pushTribute, // worker-enqueued by tribute.render after delivery
  "widget.refresh": widgetRefresh,
};

export const HEAVY_KINDS: Record<string, Handler> = {
  "media.renditions": mediaRenditions,
  "collage.compose": collageCompose,
  "collage.recompose": collageRecompose,
  "recap.generate": recapGenerate,
  // the brief's name for recap.generate; nothing enqueues it today
  "recap.assemble": recapGenerate,
  "tribute.render": tributeRender,
  "tribute.rerender": tributeRender,
  "year.compute": yearCompute,
  "year.recompute": yearCompute,
  "storage.delete": storageDelete,
  "auth.delete_user": authDeleteUser,
  "moderation.report": moderationReport,
};

export const HANDLERS: Record<string, Handler> = { ...REALTIME_KINDS, ...HEAVY_KINDS };

/** Kinds the worker itself enqueues (not in the SQL). */
export const WORKER_ENQUEUED_KINDS = ["invitation.end", "push.recap_ready", "push.tribute"];

export function lanes(config: Pick<WorkerConfig, "lanes">): LaneSpec[] {
  return [
    { name: "realtime", kinds: Object.keys(REALTIME_KINDS), concurrency: config.lanes.realtime.concurrency, pollMs: config.lanes.realtime.pollMs },
    { name: "heavy", kinds: Object.keys(HEAVY_KINDS), concurrency: config.lanes.heavy.concurrency, pollMs: config.lanes.heavy.pollMs },
  ];
}
