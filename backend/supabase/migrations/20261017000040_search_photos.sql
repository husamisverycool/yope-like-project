-- =============================================================================
-- 0040 search the group's photos: by caption, by what was said about a photo in the chat, by member (who posted it
-- or who tagged themselves "I'm in this") and by date. No face search, no AI image search (directive: no face
-- recognition; AI only for recaps). Owner decision 34 "search"; docs/RESEARCH_FEATURES_2026-10-17.md #6.
--
-- Mechanics references (accessed 2026-10-17): Retro's albums search (App Store story
-- https://apps.apple.com/us/story/id1854931006); Yope's search on the group list
-- (https://www.tiktok.com/@savannahclooney/video/7683341732695592206); Apple Shared Albums filters
-- (https://support.apple.com/en-us/108314).
--
-- Text matching: Postgres full-text search with the 'simple' configuration (lower-cased words, no stemming and no
-- stop words — captions and chat are in any language, so no one language's stemmer applies), each word of the query
-- as a prefix ("birth" finds "birthday"), all words required. Indexed by expression on posts.caption and
-- messages.body, so no column is added to rows the apps and Realtime already carry.
-- "Chat" = the messages that reply to the photo (its comments in the viewer and replies in the chat), by authors with
-- no block with the caller. Results are photos the caller can see (posts RLS: member, no block with the author).
-- =============================================================================

create index posts_caption_fts_idx on public.posts
  using gin (to_tsvector('simple', coalesce(caption, '')));
create index messages_body_fts_idx on public.messages
  using gin (to_tsvector('simple', coalesce(body, '')))
  where reply_to_post_id is not null;
create index messages_reply_to_post_idx on public.messages (reply_to_post_id) where reply_to_post_id is not null;

-- The query's words, each as a prefix, all required; null when the text has no word.
create function private.search_tsquery(p_text text)
returns tsquery
language sql
immutable
set search_path = ''
as $$
  select case when count(*) = 0 then null
              else to_tsquery('simple', string_agg('''' || replace(replace(t.lexeme, '\', ''), '''', '''''') || ''':*', ' & '))
         end
  from unnest(to_tsvector('simple', left(coalesce(p_text, ''), 200))) as t
  where replace(t.lexeme, '\', '') <> ''
$$;
revoke all on function private.search_tsquery(text) from public;

create function public.search_photos(
  p_text text default null,
  p_group_id uuid default null,
  p_member_id uuid default null,
  p_from date default null,
  p_to date default null,
  p_before timestamptz default null,
  p_limit integer default 60
)
returns table (
  post_id uuid,
  media_id uuid,
  group_id uuid,
  author_id uuid,
  created_at timestamptz,
  matched text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_q tsquery := private.search_tsquery(p_text);
  v_limit integer := least(greatest(coalesce(p_limit, 60), 1), 200);
begin
  if v_q is null and p_member_id is null and p_from is null and p_to is null then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_text, p_member_id, p_from or p_to';
  end if;
  if p_from is not null and p_to is not null and p_to < p_from then
    raise exception 'invalid_argument' using errcode = 'PT400', detail = 'p_to before p_from';
  end if;
  if p_group_id is not null and not private.is_member(p_group_id) then
    raise exception 'not_group_member' using errcode = 'PT403';
  end if;
  -- a member you have a block with matches nothing
  if p_member_id is not null and p_member_id <> v_uid and private.is_blocked_with(p_member_id) then
    return;
  end if;

  return query
  with scope as (
    select p.id, p.media_id, p.group_id, p.author_id, p.created_at, p.caption,
           (p.created_at at time zone g.time_zone)::date as local_day
    from public.posts p
    join public.groups g on g.id = p.group_id
    where p.group_id in (select private.my_group_ids())
      and (p_group_id is null or p.group_id = p_group_id)
      and p.author_id not in (select private.blocked_ids())
      and (p_before is null or p.created_at < p_before)
  ),
  hits as (
    select s.*,
           (v_q is not null and to_tsvector('simple', coalesce(s.caption, '')) @@ v_q) as by_caption,
           (v_q is not null and exists (
              select 1 from public.messages m
              where m.reply_to_post_id = s.id and m.group_id = s.group_id
                and m.author_id not in (select private.blocked_ids())
                and to_tsvector('simple', coalesce(m.body, '')) @@ v_q)) as by_chat,
           (p_member_id is not null and s.author_id = p_member_id) as by_author,
           (p_member_id is not null and exists (
              select 1 from public.post_tags t where t.post_id = s.id and t.user_id = p_member_id)) as by_tag
    from scope s
    where (p_from is null or s.local_day >= p_from)
      and (p_to is null or s.local_day <= p_to)
  ),
  matches as (
    select h.*,
           row_number() over (partition by h.media_id order by (h.group_id = p_group_id) desc nulls last, h.created_at, h.id) as rn
    from hits h
    where (v_q is null or h.by_caption or h.by_chat)
      and (p_member_id is null or h.by_author or h.by_tag)
  )
  select x.id, x.media_id, x.group_id, x.author_id, x.created_at,
         array_remove(array[
           case when x.by_caption then 'caption' end,
           case when x.by_chat then 'chat' end,
           case when x.by_author then 'author' end,
           case when x.by_tag then 'tag' end,
           case when p_from is not null or p_to is not null then 'date' end], null)
  from matches x
  where x.rn = 1
  order by x.created_at desc, x.id
  limit v_limit;
end;
$$;

revoke all on function public.search_photos(text, uuid, uuid, date, date, timestamptz, integer) from public, anon;
grant execute on function public.search_photos(text, uuid, uuid, date, date, timestamptz, integer) to authenticated;
