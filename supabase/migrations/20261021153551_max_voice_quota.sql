-- Apply after backend/sql/001_usage.sql. Only the Edge Function may spend
-- OpenAI credits; this RPC reserves a caller's own bounded voice allowance.
create schema if not exists max_private;
revoke all on schema max_private from public, anon;
grant usage on schema max_private to authenticated;

create or replace function max_private.consume_voice(characters integer) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  day_bucket text := 'voice-day:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD');
  minute_bucket text := 'voice-minute:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI');
begin
  if uid is null or characters is null or characters < 1 or characters > 1000 then return false; end if;
  insert into public.max_usage(user_id, bucket, request_count) values(uid, day_bucket, 0) on conflict do nothing;
  insert into public.max_usage(user_id, bucket, request_count) values(uid, minute_bucket, 0) on conflict do nothing;
  perform 1 from public.max_usage where user_id = uid and bucket = day_bucket for update;
  perform 1 from public.max_usage where user_id = uid and bucket = minute_bucket for update;
  if (select request_count from public.max_usage where user_id = uid and bucket = day_bucket) + characters > 3000 or
     (select request_count from public.max_usage where user_id = uid and bucket = minute_bucket) >= 2 then return false; end if;
  update public.max_usage set request_count = request_count + characters where user_id = uid and bucket = day_bucket;
  update public.max_usage set request_count = request_count + 1 where user_id = uid and bucket = minute_bucket;
  return true;
end;
$$;
revoke all on function max_private.consume_voice(integer) from public, anon;
grant execute on function max_private.consume_voice(integer) to authenticated;

create or replace function public.consume_max_voice(characters integer) returns boolean
language sql security invoker set search_path = '' as $$
  select max_private.consume_voice(characters);
$$;
revoke all on function public.consume_max_voice(integer) from public, anon;
grant execute on function public.consume_max_voice(integer) to authenticated;
