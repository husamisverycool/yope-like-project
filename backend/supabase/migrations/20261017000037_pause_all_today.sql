-- =============================================================================
-- 0037 Pause All: every notification off until the end of the person's day (owner decision 34,
-- docs/RESEARCH_FEATURES_2026-10-17.md #17).
--
-- Retro's Notification Settings: "Pause All — Turn off all notifications for the day"
-- (references/auto/retro/apk/retro-android-2026.10.1150-strings.txt,
-- notification_setting_title_pause_all / notification_setting_description_pause_all).
--
-- notification_settings.paused_until: while it is in the future the worker sends this person no alert of
-- any kind (the daily invitation included), exactly as for a muted group (backend/worker/src/push/audience.ts);
-- widgets still update silently. "For the day" = until the next midnight in the time zone the device sends
-- (p_time_zone), so the apps can show the end time. Nothing to clean up: a past paused_until is no pause.
-- Writes through set_notifications_paused only (own row; RLS of notification_settings unchanged).
-- =============================================================================

alter table public.notification_settings add column paused_until timestamptz;

create function public.set_notifications_paused(p_paused boolean, p_time_zone text default null)
returns public.notification_settings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_until timestamptz;
  v_row public.notification_settings;
begin
  if p_paused is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_paused';
  end if;
  if p_paused then
    if not private.is_valid_time_zone(p_time_zone) then
      raise exception 'invalid_time_zone' using errcode = 'PT400';
    end if;
    -- the next local midnight: the start of tomorrow in the device's zone
    v_until := (((now() at time zone p_time_zone)::date + 1)::timestamp) at time zone p_time_zone;
  end if;
  insert into public.notification_settings (user_id, paused_until) values (v_uid, v_until)
  on conflict (user_id) do update set paused_until = excluded.paused_until
  returning * into v_row;
  return v_row;
end;
$$;

grant execute on function public.set_notifications_paused(boolean, text) to authenticated;
