-- Apply in the same Supabase project used by native Max authentication.
create table if not exists public.max_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  bucket text not null,
  request_count integer not null default 0,
  primary key(user_id, bucket)
);
alter table public.max_usage enable row level security;
revoke all on public.max_usage from anon, authenticated;

create or replace function public.consume_max_request() returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  day_bucket text := 'day:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD');
  minute_bucket text := 'minute:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI');
  accepted integer;
begin
  if uid is null then return false; end if;
  -- Both updates run in one transaction; locks prevent concurrent overspend.
  insert into public.max_usage(user_id, bucket, request_count) values(uid, day_bucket, 0) on conflict do nothing;
  insert into public.max_usage(user_id, bucket, request_count) values(uid, minute_bucket, 0) on conflict do nothing;
  perform 1 from public.max_usage where user_id = uid and bucket = day_bucket for update;
  perform 1 from public.max_usage where user_id = uid and bucket = minute_bucket for update;
  if (select request_count from public.max_usage where user_id = uid and bucket = day_bucket) >= 100 or
     (select request_count from public.max_usage where user_id = uid and bucket = minute_bucket) >= 20 then return false; end if;
  update public.max_usage set request_count = request_count + 1 where user_id = uid and bucket in (day_bucket, minute_bucket);
  return true;
end;
$$;
revoke all on function public.consume_max_request() from public, anon;
grant execute on function public.consume_max_request() to authenticated;
