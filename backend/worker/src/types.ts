// Row shapes of the tables the worker reads (docs/API.md §5; migrations are the source of truth).

export interface JobRow {
  id: number;
  kind: string;
  payload: Record<string, unknown>;
  status: string;
  run_at: string;
  attempts: number;
  max_attempts: number;
  dedupe_key: string | null;
  last_error: string | null;
}

export interface GroupRow {
  id: string;
  name: string;
  kind: string;
  time_zone: string;
}

export interface MemberRow {
  group_id: string;
  user_id: string;
  role: string;
  muted: boolean;
  joined_at: string;
}

export interface ProfileRow {
  id: string;
  display_name: string;
  avatar_path: string | null;
}

export type MediaKind = "photo" | "live_photo" | "video";

export interface MediaRow {
  id: string;
  owner_id: string;
  kind: MediaKind;
  original_path: string;
  front_original_path: string | null;
  motion_path: string | null;
  display_path: string | null;
  thumb_path: string | null;
  widget_path: string | null;
  front_display_path: string | null;
  front_thumb_path: string | null;
  width: number | null;
  height: number | null;
  duration_ms: number | null;
  renditions_ready_at: string | null;
  created_at: string;
}

export interface PostRow {
  id: string;
  media_id: string;
  group_id: string;
  author_id: string;
  caption: string | null;
  invitation_id: string | null;
  in_window: boolean;
  reply_to_post_id: string | null;
  created_at: string;
  /** when the group could first see it: revealed_at for an overnight photo, else created_at (migration 0027) */
  visible_at: string;
}

export interface MessageRow {
  id: string;
  group_id: string;
  author_id: string;
  kind: "text" | "photo" | "voice";
  body: string | null;
  post_id: string | null;
  reply_to_post_id: string | null;
  reply_to_message_id: string | null;
  created_at: string;
}

export interface InvitationRow {
  id: string;
  group_id: string;
  local_date: string;
  fires_at: string;
  closes_at: string;
  status: "scheduled" | "fired" | "closed" | "cancelled";
}

export interface CollageRow {
  id: string;
  group_id: string;
  invitation_id: string | null;
  option: string;
  post_ids: string[];
  page_count?: number;
  image_path: string | null;
  widget_path: string | null;
  share_path: string | null;
  status: "pending" | "ready" | "failed";
  composed_at: string | null;
  created_at: string;
}

export interface DeviceRow {
  id: string;
  user_id: string;
  platform: "ios" | "android";
  push_token: string;
  push_to_start_token: string | null;
  /** iOS: false when Live Activities are off on the iPhone (the invitation then goes as an alert); null: not reported */
  live_activities_enabled: boolean | null;
}

export interface NotificationSettingsRow {
  user_id: string;
  quiet_start: string | null;
  quiet_end: string | null;
  time_zone: string | null;
}

export interface RecapRow {
  id: string;
  group_id: string;
  week_start: string;
  items: string[];
  text: string | null;
  status: "pending" | "ready" | "failed";
}

export interface TributeRow {
  id: string;
  request_id: string;
  group_id: string;
  honoree_id: string;
  video_path: string | null;
  poster_path: string | null;
  status: "pending" | "ready" | "failed";
  rendered_at: string | null;
  delivered_at: string | null;
}

export interface TributeRequestRow {
  id: string;
  group_id: string;
  honoree_id: string;
  birthday_date: string;
  due_at: string;
  closed_at: string | null;
}

export interface ContributionRow {
  id: string;
  request_id: string;
  contributor_id: string;
  post_id: string;
  line: string;
  created_at: string;
  updated_at: string;
}

export interface YearStoryRow {
  id: string;
  group_id: string;
  year: number;
  status: "pending" | "ready" | "failed";
  data: unknown;
  post_ids: string[];
  asset_paths: string[];
}

export const MEDIA_COLUMNS =
  "id, owner_id, kind, original_path, front_original_path, motion_path, display_path, thumb_path, widget_path, front_display_path, front_thumb_path, width, height, duration_ms, renditions_ready_at, created_at";
export interface PlanRow {
  id: string;
  group_id: string;
  created_by: string | null;
  title: string;
  starts_at: string;
  ends_at: string | null;
  all_day: boolean;
  local_date: string;
  place: string | null;
  canceled_at: string | null;
  updated_at: string;
}

export const PLAN_COLUMNS = "id, group_id, created_by, title, starts_at, ends_at, all_day, local_date, place, canceled_at, updated_at";

export const POST_COLUMNS = "id, media_id, group_id, author_id, caption, invitation_id, in_window, reply_to_post_id, created_at, visible_at";

/** First word of a display name (same rule as private.first_name in SQL); null when empty. */
export function firstName(displayName: string | null | undefined): string | null {
  const w = (displayName ?? "").trim().split(/\s+/)[0] ?? "";
  return w === "" ? null : w;
}
