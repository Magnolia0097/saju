-- =====================================================================
-- Saju Service v2 — Supabase(PostgreSQL 15+) 스키마
-- 실행: Supabase SQL Editor (postgres 권한)에서 위에서부터 순서대로
-- 원칙
--   1) public 스키마의 모든 테이블 RLS ON
--   2) 클라이언트(anon/authenticated)는 '본인 데이터 읽기'만 가능
--   3) 모든 쓰기는 서버(service_role) 또는 security definer RPC로만
--   4) 해석 원문(content_blocks)은 정책 없음 + 권한 회수로 2중 차단
-- =====================================================================

create schema if not exists private;                 -- 내부 함수 전용 (API 비노출)
revoke all on schema private from public;

-- ---------------------------------------------------------------------
-- 1. 사용자: auth.users 1:1 확장 (익명 로그인 사용자 포함)
-- ---------------------------------------------------------------------
create table public.app_users (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  referral_code     text not null unique,
  pending_ref_code  text,                 -- 초대 링크로 유입 시 서버가 1회 기록
  ref_captured_at   timestamptz,
  is_blocked        boolean not null default false,
  created_at        timestamptz not null default now()
);

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  loop
    v_code := upper(substr(md5(gen_random_uuid()::text), 1, 8));
    exit when not exists (select 1 from public.app_users where referral_code = v_code);
  end loop;
  insert into public.app_users (user_id, referral_code) values (new.id, v_code);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------
-- 2. 사주 프로필 (본인 / 지인)
-- ---------------------------------------------------------------------
create table public.saju_profiles (
  profile_id        uuid primary key default gen_random_uuid(),
  owner_user_id     uuid not null references public.app_users(user_id) on delete cascade,
  label             text not null check (char_length(label) between 1 and 20),  -- 닉네임
  is_self           boolean not null default true,
  gender            text not null check (gender in ('M','F')),
  calendar_input    text not null check (calendar_input in ('SOLAR','LUNAR','LUNAR_LEAP')),
  birth_input       jsonb not null,       -- 사용자가 입력한 원본 값
  birth_date_solar  date not null,        -- 양력 정규화 결과
  birth_time        time,                 -- NULL = 시간 모름
  chart_json        jsonb not null,       -- 4주 8자·오행/십성 분포·신강약·신살·대운 (서버 계산)
  feature_keys      jsonb not null,       -- 축별 조건 키 (문서 4.4절)
  engine_version    text not null,        -- 만세력·피처 로직 버전
  created_at        timestamptz not null default now()
);
create index saju_profiles_owner_idx on public.saju_profiles (owner_user_id);

-- ---------------------------------------------------------------------
-- 3. 상품 (가격은 서버 기준값. 클라이언트가 보낸 금액은 절대 사용하지 않음)
-- ---------------------------------------------------------------------
create table public.products (
  theme_code     text primary key,
  title          text not null,
  price_krw      int  not null check (price_krw > 0),
  period_type    text not null check (period_type in ('LIFETIME','YEARLY')),
  requires_pair  boolean not null default false,
  ticket_cost    int check (ticket_cost is null or ticket_cost > 0),  -- NULL = 티켓 사용 불가
  is_active      boolean not null default true,
  sort_order     int not null default 0
);

insert into public.products (theme_code, title, price_krw, period_type, requires_pair, ticket_cost, sort_order) values
  ('LIFE',   '평생 종합 사주',       990, 'LIFETIME', false, 1, 1),
  ('YEAR',   '신년 운세',            990, 'YEARLY',   false, 1, 2),
  ('WEALTH', '재물운 · 돈그릇',      990, 'LIFETIME', false, 1, 3),
  ('LOVE',   '연애 · 결혼운',        990, 'LIFETIME', false, 1, 4),
  ('CAREER', '직업 · 이직운',        990, 'LIFETIME', false, 1, 5),
  ('PAIR',   '1:1 궁합 · 사주 배틀', 990, 'LIFETIME', true,  1, 6);

-- ---------------------------------------------------------------------
-- 4. 주문 / 결제 (탈퇴해도 전자상거래법상 결제 기록 보존 → set null)
-- ---------------------------------------------------------------------
create table public.orders (
  order_id            uuid primary key default gen_random_uuid(),  -- 포트원 paymentId로 사용
  user_id             uuid references public.app_users(user_id) on delete set null,
  theme_code          text not null references public.products(theme_code),
  profile_id          uuid references public.saju_profiles(profile_id) on delete set null,
  partner_profile_id  uuid references public.saju_profiles(profile_id) on delete set null,
  period_key          text not null,                               -- 'LIFETIME' | 세운 연도 'YYYY'
  amount_krw          int  not null check (amount_krw > 0),        -- products에서 서버가 복사
  status              text not null default 'PENDING'
                      check (status in ('PENDING','PAID','FAILED','CANCELLED','REFUNDED')),
  pg_tx_id            text unique,
  paid_at             timestamptz,
  refunded_at         timestamptz,
  pg_raw              jsonb,
  created_at          timestamptz not null default now()
);
create index orders_user_idx on public.orders (user_id, created_at desc);

-- ---------------------------------------------------------------------
-- 5. 리포트(언락) — 스냅샷이 곧 상품. READY 이후 content_json 불변
-- ---------------------------------------------------------------------
create table public.reports (
  report_id           uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.app_users(user_id) on delete cascade,
  profile_id          uuid not null references public.saju_profiles(profile_id) on delete cascade,
  partner_profile_id  uuid references public.saju_profiles(profile_id) on delete cascade,
  theme_code          text not null references public.products(theme_code),
  period_key          text not null,
  unlock_method       text not null check (unlock_method in ('PAYMENT','TICKET','ADMIN')),
  order_id            uuid references public.orders(order_id) on delete set null,
  status              text not null default 'GENERATING'
                      check (status in ('GENERATING','READY','FAILED','REFUNDED')),
  attempts            int  not null default 0,
  lock_until          timestamptz,
  content_json        jsonb,            -- 최종 리포트 스냅샷
  generation_meta     jsonb,            -- model, prompt_ver, block_vers, tokens, cost_krw, latency_ms, fallback
  created_at          timestamptz not null default now(),
  ready_at            timestamptz,
  check (partner_profile_id is null or partner_profile_id <> profile_id)
);
-- 같은 대상(1인 또는 2인 조합, 순서 무관) × 테마 × 기간은 한 번만 언락
-- LEAST/GREATEST는 NULL을 무시 → 1인 리포트는 (p, p), 궁합은 정렬된 (a, b)
create unique index reports_unlock_uniq on public.reports (
  least(profile_id, partner_profile_id),
  greatest(profile_id, partner_profile_id),
  theme_code,
  period_key
) where status <> 'REFUNDED';
create index reports_user_idx on public.reports (user_id, created_at desc);

-- ---------------------------------------------------------------------
-- 6. 무료 티켓 원장 (잔액 = SUM(delta), 카운터 컬럼 없음)
-- ---------------------------------------------------------------------
create table public.ticket_ledger (
  entry_id    bigint generated always as identity primary key,
  user_id     uuid not null references public.app_users(user_id) on delete cascade,
  delta       int  not null check (delta <> 0),
  reason      text not null check (reason in ('REFERRAL_REWARD','UNLOCK','REFUND','ADMIN')),
  ref_id      uuid,                     -- referral_id 또는 report_id
  created_at  timestamptz not null default now(),
  unique (reason, ref_id)               -- 같은 근거로 중복 적립·차감 불가
);
create index ticket_ledger_user_idx on public.ticket_ledger (user_id);

create view public.my_ticket_balance
with (security_invoker = true) as
select user_id, coalesce(sum(delta), 0)::int as balance
from public.ticket_ledger
group by user_id;

-- ---------------------------------------------------------------------
-- 7. 친구 초대
-- ---------------------------------------------------------------------
create table public.referrals (
  referral_id       uuid primary key default gen_random_uuid(),
  referrer_user_id  uuid not null references public.app_users(user_id) on delete cascade,
  referee_user_id   uuid not null unique references public.app_users(user_id) on delete cascade,
  status            text not null default 'PENDING'
                    check (status in ('PENDING','REWARDED','HELD','REJECTED')),
  reject_reason     text,
  risk_signals      jsonb not null default '{}'::jsonb,   -- 차단 근거가 아니라 보류 판단용
  created_at        timestamptz not null default now(),
  rewarded_at       timestamptz,
  check (referrer_user_id <> referee_user_id)
);
create index referrals_referrer_idx on public.referrals (referrer_user_id, created_at);

-- ---------------------------------------------------------------------
-- 8. 해석 콘텐츠 (근거 블록) — 서버(service_role)만 접근
-- ---------------------------------------------------------------------
create table public.content_blocks (
  block_id       bigint generated always as identity primary key,
  theme_code     text not null,          -- 'COMMON' 또는 테마 코드
  axis           text not null,          -- 문서 4.4절 축 코드
  condition_key  text not null,
  version        int  not null default 1,
  title          text not null,
  teaser_text    text not null,          -- 무료 공개 1~2문장
  grounding_md   text not null,          -- LLM 근거용 해석 포인트 (300~600자)
  fallback_md    text,                   -- LLM 실패 시 대체 본문
  status         text not null default 'DRAFT'
                 check (status in ('DRAFT','REVIEWED','PUBLISHED')),
  updated_at     timestamptz not null default now(),
  unique (theme_code, axis, condition_key, version)
);

-- =====================================================================
-- RLS & 권한
-- =====================================================================
alter table public.app_users      enable row level security;
alter table public.saju_profiles  enable row level security;
alter table public.products       enable row level security;
alter table public.orders         enable row level security;
alter table public.reports        enable row level security;
alter table public.ticket_ledger  enable row level security;
alter table public.referrals      enable row level security;
alter table public.content_blocks enable row level security;

-- 해석 원문: 정책 없음(전면 거부) + 권한 회수 → RLS가 실수로 꺼져도 차단
revoke all on public.content_blocks from anon, authenticated;

-- 클라이언트 쓰기 권한 회수 (TRUNCATE는 RLS 대상이 아니므로 함께 회수)
revoke insert, update, delete, truncate on
  public.app_users, public.saju_profiles, public.products, public.orders,
  public.reports, public.ticket_ledger, public.referrals
from anon, authenticated;

create policy app_users_select_own on public.app_users
  for select to authenticated using (user_id = (select auth.uid()));
create policy profiles_select_own on public.saju_profiles
  for select to authenticated using (owner_user_id = (select auth.uid()));
create policy products_select_active on public.products
  for select to anon, authenticated using (is_active);
create policy orders_select_own on public.orders
  for select to authenticated using (user_id = (select auth.uid()));
create policy reports_select_own on public.reports
  for select to authenticated using (user_id = (select auth.uid()));
create policy ledger_select_own on public.ticket_ledger
  for select to authenticated using (user_id = (select auth.uid()));
create policy referrals_select_as_referrer on public.referrals
  for select to authenticated using (referrer_user_id = (select auth.uid()));

-- =====================================================================
-- RPC (클라이언트용): 무료 티켓으로 언락 — 원자적 차감
-- =====================================================================
create or replace function public.rpc_unlock_with_ticket(
  p_profile_id         uuid,
  p_theme_code         text,
  p_period_key         text default 'LIFETIME',
  p_partner_profile_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid        uuid := auth.uid();
  v_product    public.products%rowtype;
  v_balance    int;
  v_report_id  uuid;
  v_this_year  int := extract(year from now())::int;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if coalesce((select u.is_anonymous from auth.users u where u.id = v_uid), true) then
    raise exception 'KAKAO_LOGIN_REQUIRED';
  end if;

  select * into v_product from public.products
   where theme_code = p_theme_code and is_active;
  if not found or v_product.ticket_cost is null then
    raise exception 'INVALID_PRODUCT';
  end if;

  -- 기간: 평생 상품은 LIFETIME, 연간 상품은 세운 연도(작년~내년, 입춘 경계 고려)
  if v_product.period_type = 'LIFETIME' then
    if p_period_key <> 'LIFETIME' then raise exception 'INVALID_PERIOD'; end if;
  else
    if p_period_key !~ '^\d{4}$' then raise exception 'INVALID_PERIOD'; end if;
    if p_period_key::int not between v_this_year - 1 and v_this_year + 1 then
      raise exception 'INVALID_PERIOD';
    end if;
  end if;

  if v_product.requires_pair <> (p_partner_profile_id is not null) then
    raise exception 'PAIR_MISMATCH';
  end if;

  -- 소유권: MVP에서는 궁합 상대도 본인이 등록한 프로필이어야 함
  if not exists (select 1 from public.saju_profiles
                  where profile_id = p_profile_id and owner_user_id = v_uid) then
    raise exception 'PROFILE_NOT_OWNED';
  end if;
  if p_partner_profile_id is not null and not exists (
       select 1 from public.saju_profiles
        where profile_id = p_partner_profile_id and owner_user_id = v_uid) then
    raise exception 'PARTNER_NOT_OWNED';
  end if;

  -- 사용자 단위 직렬화: 동시 요청으로 잔액이 음수가 되는 것 방지
  perform 1 from public.app_users where user_id = v_uid for update;

  select coalesce(sum(delta), 0) into v_balance
    from public.ticket_ledger where user_id = v_uid;
  if v_balance < v_product.ticket_cost then
    raise exception 'NO_TICKET';
  end if;

  insert into public.reports (user_id, profile_id, partner_profile_id, theme_code, period_key, unlock_method)
  values (v_uid, p_profile_id, p_partner_profile_id, p_theme_code, p_period_key, 'TICKET')
  returning report_id into v_report_id;

  insert into public.ticket_ledger (user_id, delta, reason, ref_id)
  values (v_uid, -v_product.ticket_cost, 'UNLOCK', v_report_id);

  return v_report_id;
exception
  when unique_violation then
    raise exception 'ALREADY_UNLOCKED';   -- 차감 포함 전체 롤백
end;
$$;

revoke all on function public.rpc_unlock_with_ticket(uuid, text, text, uuid) from public, anon;
grant execute on function public.rpc_unlock_with_ticket(uuid, text, text, uuid) to authenticated;

-- =====================================================================
-- RPC (서버 전용, service_role): 결제 확정 — 멱등 + 금액 검증
-- 서버가 포트원 결제 단건 조회로 상태·금액을 확인한 뒤 호출
-- =====================================================================
create or replace function public.svc_mark_order_paid(
  p_order_id     uuid,
  p_pg_tx_id     text,
  p_paid_amount  int,
  p_pg_raw       jsonb default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order     public.orders%rowtype;
  v_report_id uuid;
begin
  select * into v_order from public.orders where order_id = p_order_id for update;
  if not found then
    return jsonb_build_object('result', 'ORDER_NOT_FOUND');
  end if;

  -- 멱등: 웹훅과 클라이언트 콜백이 둘 다 와도 한 번만 처리
  if v_order.status = 'PAID' then
    select report_id into v_report_id from public.reports where order_id = p_order_id;
    return jsonb_build_object('result', 'OK', 'report_id', v_report_id, 'idempotent', true);
  end if;
  if v_order.status <> 'PENDING' then
    return jsonb_build_object('result', 'ORDER_NOT_PENDING', 'status', v_order.status);
  end if;

  -- 금액 위변조 차단: PG가 확인해 준 실결제액 = 서버가 정한 금액
  if p_paid_amount is distinct from v_order.amount_krw then
    update public.orders
       set status = 'FAILED', pg_tx_id = p_pg_tx_id, pg_raw = p_pg_raw
     where order_id = p_order_id;
    return jsonb_build_object('result', 'AMOUNT_MISMATCH_CANCEL_REQUIRED');
  end if;

  update public.orders
     set status = 'PAID', pg_tx_id = p_pg_tx_id, paid_at = now(), pg_raw = p_pg_raw
   where order_id = p_order_id;

  begin
    insert into public.reports (user_id, profile_id, partner_profile_id, theme_code, period_key,
                                unlock_method, order_id)
    values (v_order.user_id, v_order.profile_id, v_order.partner_profile_id, v_order.theme_code,
            v_order.period_key, 'PAYMENT', p_order_id)
    returning report_id into v_report_id;
  exception
    when unique_violation then
      -- 결제 직전에 티켓 등으로 이미 언락됨 → 주문은 PAID로 남기고 서버가 즉시 PG 취소
      return jsonb_build_object('result', 'ALREADY_UNLOCKED_CANCEL_REQUIRED');
  end;

  return jsonb_build_object('result', 'OK', 'report_id', v_report_id);
end;
$$;

revoke all on function public.svc_mark_order_paid(uuid, text, int, jsonb) from public, anon, authenticated;
grant execute on function public.svc_mark_order_paid(uuid, text, int, jsonb) to service_role;

-- =====================================================================
-- RPC (서버 전용): 친구 초대 확정 — 신규 가입 + 본인 티저 생성 완료 기준
-- =====================================================================
create or replace function public.svc_confirm_referral(
  p_referee_user_id uuid,
  p_risk_signals    jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_daily_cap    constant int := 3;
  c_lifetime_cap constant int := 10;
  c_window       constant interval := interval '7 days';
  v_referee      public.app_users%rowtype;
  v_referrer     public.app_users%rowtype;
  v_today_cnt    int;
  v_total_cnt    int;
  v_status       text;
  v_reason       text;
  v_referral_id  uuid;
begin
  select * into v_referee from public.app_users where user_id = p_referee_user_id;
  if not found or v_referee.pending_ref_code is null then
    return jsonb_build_object('result', 'NO_REFERRAL');
  end if;
  if coalesce((select u.is_anonymous from auth.users u where u.id = p_referee_user_id), true) then
    return jsonb_build_object('result', 'REFEREE_NOT_LINKED');      -- 카카오 연동 전
  end if;
  if v_referee.ref_captured_at < now() - c_window then
    return jsonb_build_object('result', 'EXPIRED');
  end if;
  if not exists (select 1 from public.saju_profiles
                  where owner_user_id = p_referee_user_id and is_self) then
    return jsonb_build_object('result', 'NO_SELF_PROFILE');
  end if;
  if exists (select 1 from public.referrals where referee_user_id = p_referee_user_id) then
    return jsonb_build_object('result', 'ALREADY_PROCESSED');
  end if;

  select * into v_referrer from public.app_users
   where referral_code = v_referee.pending_ref_code
   for update;                                       -- 초대자 단위 직렬화 (상한 경쟁 방지)
  if not found
     or v_referrer.user_id = p_referee_user_id
     or v_referrer.is_blocked
     or coalesce((select u.is_anonymous from auth.users u where u.id = v_referrer.user_id), true) then
    return jsonb_build_object('result', 'INVALID_REFERRER');
  end if;

  select count(*) filter (where (r.rewarded_at at time zone 'Asia/Seoul')::date
                                = (now() at time zone 'Asia/Seoul')::date),
         count(*)
    into v_today_cnt, v_total_cnt
    from public.referrals r
   where r.referrer_user_id = v_referrer.user_id
     and r.status = 'REWARDED';

  if v_total_cnt >= c_lifetime_cap then
    v_status := 'REJECTED';  v_reason := 'LIFETIME_CAP';
  elsif v_today_cnt >= c_daily_cap then
    v_status := 'REJECTED';  v_reason := 'DAILY_CAP';
  elsif coalesce((p_risk_signals->>'hold')::boolean, false) then
    v_status := 'HELD';      v_reason := 'RISK_REVIEW';
  else
    v_status := 'REWARDED';
  end if;

  insert into public.referrals (referrer_user_id, referee_user_id, status, reject_reason,
                                risk_signals, rewarded_at)
  values (v_referrer.user_id, p_referee_user_id, v_status, v_reason, p_risk_signals,
          case when v_status = 'REWARDED' then now() end)
  returning referral_id into v_referral_id;

  if v_status = 'REWARDED' then
    insert into public.ticket_ledger (user_id, delta, reason, ref_id)
    values (v_referrer.user_id, 1, 'REFERRAL_REWARD', v_referral_id);
  end if;

  return jsonb_build_object('result', v_status, 'reason', v_reason, 'referral_id', v_referral_id);
end;
$$;

revoke all on function public.svc_confirm_referral(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.svc_confirm_referral(uuid, jsonb) to service_role;

-- =====================================================================
-- RPC (서버 전용): 생성 작업 점유 — 중복 생성 방지 (최대 3회 시도)
-- =====================================================================
create or replace function public.svc_claim_generation(
  p_report_id    uuid,
  p_lock_seconds int default 120
) returns boolean
language sql
security definer
set search_path = ''
as $$
  update public.reports
     set lock_until = now() + make_interval(secs => p_lock_seconds),
         attempts   = attempts + 1
   where report_id = p_report_id
     and status = 'GENERATING'
     and attempts < 3
     and (lock_until is null or lock_until < now())
  returning true;
$$;

revoke all on function public.svc_claim_generation(uuid, int) from public, anon, authenticated;
grant execute on function public.svc_claim_generation(uuid, int) to service_role;

-- =====================================================================
-- RPC (서버 전용): 리포트 환불 — 티켓 복구 또는 주문 환불 처리
-- (결제 건은 서버가 PG 취소 API 성공 후 호출)
-- =====================================================================
create or replace function public.svc_refund_report(p_report_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_r     public.reports%rowtype;
  v_cost  int;
begin
  select * into v_r from public.reports where report_id = p_report_id for update;
  if not found then
    return jsonb_build_object('result', 'NOT_FOUND');
  end if;
  if v_r.status = 'REFUNDED' then
    return jsonb_build_object('result', 'ALREADY_REFUNDED');
  end if;

  update public.reports set status = 'REFUNDED' where report_id = p_report_id;

  if v_r.unlock_method = 'TICKET' then
    select ticket_cost into v_cost from public.products where theme_code = v_r.theme_code;
    insert into public.ticket_ledger (user_id, delta, reason, ref_id)
    values (v_r.user_id, coalesce(v_cost, 1), 'REFUND', p_report_id);
    return jsonb_build_object('result', 'TICKET_RESTORED');
  elsif v_r.unlock_method = 'PAYMENT' then
    update public.orders set status = 'REFUNDED', refunded_at = now()
     where order_id = v_r.order_id;
    return jsonb_build_object('result', 'ORDER_REFUNDED');
  end if;
  return jsonb_build_object('result', 'OK');
end;
$$;

revoke all on function public.svc_refund_report(uuid) from public, anon, authenticated;
grant execute on function public.svc_refund_report(uuid) to service_role;

-- =====================================================================
-- RPC (서버 전용): 익명 세션 → 기존 카카오 계정 병합 (프로필 소유권 이전)
-- =====================================================================
create or replace function public.svc_merge_anonymous(
  p_anon_user_id   uuid,
  p_target_user_id uuid
) returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_moved int;
begin
  if not coalesce((select u.is_anonymous from auth.users u where u.id = p_anon_user_id), false) then
    raise exception 'SOURCE_NOT_ANONYMOUS';
  end if;
  if coalesce((select u.is_anonymous from auth.users u where u.id = p_target_user_id), true) then
    raise exception 'TARGET_NOT_PERMANENT';
  end if;
  update public.saju_profiles
     set owner_user_id = p_target_user_id,
         is_self = is_self and not exists (
           select 1 from public.saju_profiles t
            where t.owner_user_id = p_target_user_id and t.is_self)
   where owner_user_id = p_anon_user_id;
  get diagnostics v_moved = row_count;
  return v_moved;   -- 이후 서버가 Admin API로 익명 auth user 삭제 (app_users는 cascade)
end;
$$;

revoke all on function public.svc_merge_anonymous(uuid, uuid) from public, anon, authenticated;
grant execute on function public.svc_merge_anonymous(uuid, uuid) to service_role;
