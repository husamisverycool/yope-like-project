-- =============================================================================
-- 0030 devices: whether the iPhone shows Live Activities, and no WidgetKit push token.
--
-- Live Activities. The daily invitation reaches an iPhone with a push-to-start token as a Live Activity whose start
-- alert is the invitation (docs/PLATFORM_CONSTRAINTS.md §2). When the person has turned Live Activities off in
-- Settings (ActivityKit `ActivityAuthorizationInfo().areActivitiesEnabled` false) the token still exists but the
-- system starts nothing, so they got no invitation at all. register_device now carries that state
-- (p_live_activities_enabled; NULL = not reported: Android, older builds) and the worker sends the standard invitation
-- alert to an iPhone that reports false (backend/worker/src/jobs/invitation.ts).
--
-- WidgetKit push token. The app never had a widget push handler (iOS 26 `WidgetPushHandler`), so the column was never
-- filled, and a token would have made the worker send only a content-less WidgetKit push in place of the background
-- push that carries the photo. Widgets get content from the app, the notification extension and background pushes
-- (docs/WIDGET_REFRESH.md); the column and its register_device parameter go.
-- =============================================================================

alter table public.devices
  add column live_activities_enabled boolean;

comment on column public.devices.live_activities_enabled is
  'iOS: whether the iPhone shows Live Activities (ActivityAuthorizationInfo.areActivitiesEnabled and the in-app switch). '
  'false: the daily invitation goes as a standard alert, not a push-to-start. NULL: not reported (Android, older builds).';

alter table public.devices
  drop column widget_push_token;

drop function public.register_device(public.device_platform, text, text, text);

create function public.register_device(
  p_platform public.device_platform,
  p_push_token text,
  p_push_to_start_token text default null,
  p_live_activities_enabled boolean default null
)
returns public.devices
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_row public.devices;
begin
  if p_platform is null then
    raise exception 'invalid_platform' using errcode = 'PT400';
  end if;
  if p_push_token is null or char_length(p_push_token) not between 1 and 4096 then
    raise exception 'invalid_token' using errcode = 'PT400';
  end if;
  if p_platform = 'android' and (p_push_to_start_token is not null or p_live_activities_enabled is not null) then
    raise exception 'invalid_token' using errcode = 'PT400', detail = 'push_to_start / Live Activities are iOS only';
  end if;
  insert into public.devices (user_id, platform, push_token, push_to_start_token, live_activities_enabled)
  values (v_uid, p_platform, p_push_token, p_push_to_start_token, p_live_activities_enabled)
  on conflict (push_token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        push_to_start_token = excluded.push_to_start_token,
        live_activities_enabled = excluded.live_activities_enabled
  returning * into v_row;
  return v_row;
end;
$$;

grant execute on function public.register_device(public.device_platform, text, text, boolean) to authenticated;
