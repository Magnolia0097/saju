-- 로컬·CI 전용: Supabase 기본 권한 구조를 흉내 낸다 (실서비스에는 절대 실행하지 않음)
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;

grant usage on schema public to anon, authenticated, service_role;
-- Supabase 기본값과 동일하게 public 객체에 넓은 기본 권한 부여 → RLS/REVOKE가 실제로 막는지 검증
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

create schema auth;
create table auth.users (
  id           uuid primary key default gen_random_uuid(),
  is_anonymous boolean not null default false,
  created_at   timestamptz not null default now()
);
create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(nullif(current_setting('request.jwt.claims', true), '')::json->>'sub', '')::uuid
$$;
grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
