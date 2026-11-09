-- v2 스키마 검증 테스트 (로컬 전용)
\set ON_ERROR_STOP 1
\set A '''aaaaaaaa-0000-0000-0000-000000000001'''
\set B '''bbbbbbbb-0000-0000-0000-000000000002'''
\set C '''cccccccc-0000-0000-0000-000000000003'''

create schema test;
grant usage on schema test to anon, authenticated, service_role;
create or replace function test.expect_error(p_sql text, p_expected text) returns text
language plpgsql as $$
begin
  execute p_sql;
  raise exception 'EXPECTED_ERROR_NOT_RAISED: % (wanted %)', p_sql, p_expected;
exception when others then
  if sqlerrm like 'EXPECTED_ERROR_NOT_RAISED%' then raise; end if;
  if position(p_expected in sqlerrm) = 0 then
    raise exception 'WRONG_ERROR: got [%] wanted [%] for %', sqlerrm, p_expected, p_sql;
  end if;
  return 'ok: ' || p_expected;
end $$;
grant execute on function test.expect_error(text, text) to anon, authenticated, service_role;

-- ---------------- 데이터 준비 (postgres) ----------------
insert into auth.users (id, is_anonymous) values
  (:A::uuid, false),   -- A: 카카오 회원(초대자)
  (:B::uuid, true),    -- B: 익명 세션
  (:C::uuid, false);   -- C: 카카오 연동 완료한 피초대자

do $$ begin
  assert (select count(*) from public.app_users) = 3, 'trigger: app_users 자동 생성 실패';
end $$;

update public.app_users
   set pending_ref_code = (select referral_code from public.app_users where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
       ref_captured_at = now()
 where user_id = :C::uuid;

insert into public.saju_profiles (profile_id, owner_user_id, label, is_self, gender, calendar_input,
                                  birth_input, birth_date_solar, birth_time, chart_json, feature_keys, engine_version)
values
  ('11111111-0000-0000-0000-00000000000a', :A::uuid, 'A본인', true,  'M', 'SOLAR', '{}', '1995-03-15', '10:30', '{}', '{}', 'calc-1.0.0'),
  ('11111111-0000-0000-0000-00000000000b', :A::uuid, 'A친구', false, 'F', 'SOLAR', '{}', '1996-08-01', null,    '{}', '{}', 'calc-1.0.0'),
  ('22222222-0000-0000-0000-00000000000a', :B::uuid, 'B본인', true,  'F', 'LUNAR', '{}', '1999-01-20', '23:40', '{}', '{}', 'calc-1.0.0'),
  ('33333333-0000-0000-0000-00000000000a', :C::uuid, 'C본인', true,  'M', 'SOLAR', '{}', '1994-11-11', '07:00', '{}', '{}', 'calc-1.0.0');

insert into public.content_blocks (theme_code, axis, condition_key, title, teaser_text, grounding_md, status)
values ('COMMON', 'ILJU', 'GAP_JA', '갑자일주', '티저 문장', '유료 근거 원문', 'PUBLISHED');

-- ---------------- T1: 비로그인(anon) ----------------
set role anon;
do $$ begin
  assert (select count(*) from public.products) = 6, 'anon: 상품 조회 실패';
  assert (select count(*) from public.saju_profiles) = 0, 'anon: 프로필이 보이면 안 됨';
end $$;
select test.expect_error('select * from public.content_blocks', 'permission denied');
select test.expect_error('select public.rpc_unlock_with_ticket(''11111111-0000-0000-0000-00000000000a''::uuid, ''LIFE'')', 'permission denied');
reset role;

-- ---------------- T2: 로그인 사용자 A (클라이언트 권한) ----------------
set role authenticated;
set request.jwt.claims = '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}';
do $$ begin
  assert (select count(*) from public.saju_profiles) = 2, 'A: 본인 프로필 2개만 보여야 함';
  assert (select count(*) from public.app_users) = 1, 'A: app_users 본인 행만';
end $$;
select test.expect_error('select * from public.content_blocks', 'permission denied');
select test.expect_error('insert into public.ticket_ledger (user_id, delta, reason) values (''aaaaaaaa-0000-0000-0000-000000000001'', 99, ''ADMIN'')', 'permission denied');
select test.expect_error('update public.app_users set is_blocked = false', 'permission denied');
select test.expect_error('update public.reports set status = ''READY''', 'permission denied');
select test.expect_error('truncate public.orders', 'permission denied');
select test.expect_error('select public.rpc_unlock_with_ticket(''11111111-0000-0000-0000-00000000000a''::uuid, ''LIFE'')', 'NO_TICKET');
select test.expect_error('select public.rpc_unlock_with_ticket(''33333333-0000-0000-0000-00000000000a''::uuid, ''LIFE'')', 'PROFILE_NOT_OWNED');
select test.expect_error('select public.rpc_unlock_with_ticket(''11111111-0000-0000-0000-00000000000a''::uuid, ''YEAR'', ''LIFETIME'')', 'INVALID_PERIOD');
select test.expect_error('select public.rpc_unlock_with_ticket(''11111111-0000-0000-0000-00000000000a''::uuid, ''YEAR'', ''2099'')', 'INVALID_PERIOD');
select test.expect_error('select public.rpc_unlock_with_ticket(''11111111-0000-0000-0000-00000000000a''::uuid, ''PAIR'')', 'PAIR_MISMATCH');
select test.expect_error('select public.svc_confirm_referral(''cccccccc-0000-0000-0000-000000000003''::uuid)', 'permission denied');
select test.expect_error('select public.svc_mark_order_paid(gen_random_uuid(), ''x'', 990)', 'permission denied');
reset role;
reset request.jwt.claims;

-- ---------------- T3: 익명 사용자 B ----------------
set role authenticated;
set request.jwt.claims = '{"sub":"bbbbbbbb-0000-0000-0000-000000000002"}';
select test.expect_error('select public.rpc_unlock_with_ticket(''22222222-0000-0000-0000-00000000000a''::uuid, ''LIFE'')', 'KAKAO_LOGIN_REQUIRED');
reset role;
reset request.jwt.claims;

-- ---------------- T4: 초대 확정 (service_role) ----------------
set role service_role;
do $$
declare r jsonb;
begin
  r := public.svc_confirm_referral('cccccccc-0000-0000-0000-000000000003');
  assert r->>'result' = 'REWARDED', 'referral: 1차 확정 실패 ' || r::text;
  r := public.svc_confirm_referral('cccccccc-0000-0000-0000-000000000003');
  assert r->>'result' = 'ALREADY_PROCESSED', 'referral: 중복 확정 차단 실패 ' || r::text;
end $$;
reset role;

-- ---------------- T5: 티켓 언락 / 중복 언락 / 궁합 순서 무관 ----------------
set role authenticated;
set request.jwt.claims = '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}';
do $$ begin
  assert (select balance from public.my_ticket_balance) = 1, '잔액 1이어야 함';
  assert (select count(*) from public.my_ticket_balance) = 1, '잔액 뷰는 본인 행만';
end $$;
select public.rpc_unlock_with_ticket('11111111-0000-0000-0000-00000000000a', 'LIFE') is not null as life_unlocked;
do $$ begin
  assert (select balance from public.my_ticket_balance) = 0, '차감 후 잔액 0';
end $$;
reset role;
reset request.jwt.claims;

insert into public.ticket_ledger (user_id, delta, reason) values (:A::uuid, 1, 'ADMIN');

set role authenticated;
set request.jwt.claims = '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}';
select test.expect_error('select public.rpc_unlock_with_ticket(''11111111-0000-0000-0000-00000000000a''::uuid, ''LIFE'')', 'ALREADY_UNLOCKED');
do $$ begin
  assert (select balance from public.my_ticket_balance) = 1, '중복 언락 시 차감 롤백돼야 함';
end $$;
select public.rpc_unlock_with_ticket('11111111-0000-0000-0000-00000000000a', 'PAIR', 'LIFETIME', '11111111-0000-0000-0000-00000000000b') is not null as pair_unlocked;
reset role;
reset request.jwt.claims;

insert into public.ticket_ledger (user_id, delta, reason) values (:A::uuid, 1, 'ADMIN');

set role authenticated;
set request.jwt.claims = '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}';
select test.expect_error('select public.rpc_unlock_with_ticket(''11111111-0000-0000-0000-00000000000b''::uuid, ''PAIR'', ''LIFETIME'', ''11111111-0000-0000-0000-00000000000a''::uuid)', 'ALREADY_UNLOCKED');
select public.rpc_unlock_with_ticket('11111111-0000-0000-0000-00000000000a', 'YEAR', extract(year from now())::int::text) is not null as year_unlocked;
do $$ begin
  assert (select balance from public.my_ticket_balance) = 0, 'YEAR 언락 후 잔액 0';
  assert (select count(*) from public.reports) = 3, 'A 리포트 3건(LIFE, PAIR, YEAR)';
end $$;
reset role;
reset request.jwt.claims;

-- ---------------- T6: 결제 확정 (금액 위변조 / 정상 / 멱등 / 이미 언락) ----------------
insert into public.orders (order_id, user_id, theme_code, profile_id, period_key, amount_krw) values
  ('44444444-0000-0000-0000-000000000001', :A::uuid, 'WEALTH', '11111111-0000-0000-0000-00000000000a', 'LIFETIME', 990),
  ('44444444-0000-0000-0000-000000000002', :A::uuid, 'WEALTH', '11111111-0000-0000-0000-00000000000a', 'LIFETIME', 990),
  ('44444444-0000-0000-0000-000000000003', :A::uuid, 'LIFE',   '11111111-0000-0000-0000-00000000000a', 'LIFETIME', 990);

set role service_role;
do $$
declare r jsonb; r2 jsonb;
begin
  r := public.svc_mark_order_paid('44444444-0000-0000-0000-000000000001', 'tx-1', 100, '{}');
  assert r->>'result' = 'AMOUNT_MISMATCH_CANCEL_REQUIRED', 'amount: ' || r::text;

  r := public.svc_mark_order_paid('44444444-0000-0000-0000-000000000002', 'tx-2', 990, '{}');
  assert r->>'result' = 'OK' and r->>'report_id' is not null, 'paid: ' || r::text;
  r2 := public.svc_mark_order_paid('44444444-0000-0000-0000-000000000002', 'tx-2', 990, '{}');
  assert r2->>'report_id' = r->>'report_id' and (r2->>'idempotent')::boolean, 'idempotent: ' || r2::text;

  r := public.svc_mark_order_paid('44444444-0000-0000-0000-000000000003', 'tx-3', 990, '{}');
  assert r->>'result' = 'ALREADY_UNLOCKED_CANCEL_REQUIRED', 'already: ' || r::text;
end $$;
reset role;
do $$ begin
  assert (select status from public.orders where order_id = '44444444-0000-0000-0000-000000000001') = 'FAILED', '위변조 주문 FAILED 기록 유지';
  assert (select status from public.orders where order_id = '44444444-0000-0000-0000-000000000003') = 'PAID', '이미 언락 주문은 PAID로 남아 취소 대상';
end $$;

-- ---------------- T7: 생성 점유 / 시도 횟수 상한 ----------------
set role service_role;
do $$
declare v_id uuid;
begin
  select report_id into v_id from public.reports where theme_code = 'WEALTH';
  assert public.svc_claim_generation(v_id) is true, 'claim 1차 성공해야 함';
  assert public.svc_claim_generation(v_id) is null, '잠금 중 재점유 불가';
  update public.reports set lock_until = now() - interval '1 second', attempts = 3 where report_id = v_id;
  assert public.svc_claim_generation(v_id) is null, '3회 초과 점유 불가';
end $$;
reset role;

-- ---------------- T8: 환불 → 티켓 복구 → 재언락 가능 ----------------
set role service_role;
do $$
declare v_id uuid; r jsonb;
begin
  select report_id into v_id from public.reports where theme_code = 'YEAR';
  r := public.svc_refund_report(v_id);
  assert r->>'result' = 'TICKET_RESTORED', 'refund: ' || r::text;
  r := public.svc_refund_report(v_id);
  assert r->>'result' = 'ALREADY_REFUNDED', 'refund twice: ' || r::text;
end $$;
reset role;
set role authenticated;
set request.jwt.claims = '{"sub":"aaaaaaaa-0000-0000-0000-000000000001"}';
select public.rpc_unlock_with_ticket('11111111-0000-0000-0000-00000000000a', 'YEAR', extract(year from now())::int::text) is not null as year_relock_after_refund;
reset role;
reset request.jwt.claims;

-- ---------------- T9: 초대 상한·조건 ----------------
insert into auth.users (id, is_anonymous) values
  ('dddddddd-0000-0000-0000-000000000004', false),
  ('eeeeeeee-0000-0000-0000-000000000005', false),
  ('ffffffff-0000-0000-0000-000000000006', false),   -- 일일 상한 초과 대상
  ('99999999-0000-0000-0000-000000000007', true),    -- 익명(미연동)
  ('99999999-0000-0000-0000-000000000008', false),   -- 기간 만료
  ('99999999-0000-0000-0000-000000000009', false),   -- 자기 자신 초대
  ('99999999-0000-0000-0000-00000000000a', false),   -- 본인 프로필 없음
  ('88888888-0000-0000-0000-000000000001', false),   -- 다른 초대자 H
  ('88888888-0000-0000-0000-000000000002', false);   -- H의 피초대자(보류 신호)

update public.app_users set pending_ref_code = (select referral_code from public.app_users where user_id = :A::uuid), ref_captured_at = now()
 where user_id in ('dddddddd-0000-0000-0000-000000000004','eeeeeeee-0000-0000-0000-000000000005',
                   'ffffffff-0000-0000-0000-000000000006','99999999-0000-0000-0000-000000000007',
                   '99999999-0000-0000-0000-00000000000a');
update public.app_users set pending_ref_code = (select referral_code from public.app_users where user_id = :A::uuid), ref_captured_at = now() - interval '8 days'
 where user_id = '99999999-0000-0000-0000-000000000008';
update public.app_users u set pending_ref_code = u.referral_code, ref_captured_at = now()
 where user_id = '99999999-0000-0000-0000-000000000009';
update public.app_users set pending_ref_code = (select referral_code from public.app_users where user_id = '88888888-0000-0000-0000-000000000001'), ref_captured_at = now()
 where user_id = '88888888-0000-0000-0000-000000000002';

insert into public.saju_profiles (owner_user_id, label, is_self, gender, calendar_input, birth_input, birth_date_solar, chart_json, feature_keys, engine_version)
select id, 'self', true, 'F', 'SOLAR', '{}', '2000-01-01', '{}', '{}', 'calc-1.0.0'
  from auth.users
 where id in ('dddddddd-0000-0000-0000-000000000004','eeeeeeee-0000-0000-0000-000000000005',
              'ffffffff-0000-0000-0000-000000000006','99999999-0000-0000-0000-000000000007',
              '99999999-0000-0000-0000-000000000008','99999999-0000-0000-0000-000000000009',
              '88888888-0000-0000-0000-000000000002');

set role service_role;
do $$
declare r jsonb;
begin
  r := public.svc_confirm_referral('dddddddd-0000-0000-0000-000000000004');
  assert r->>'result' = 'REWARDED', 'D ' || r::text;
  r := public.svc_confirm_referral('eeeeeeee-0000-0000-0000-000000000005');
  assert r->>'result' = 'REWARDED', 'E ' || r::text;      -- C, D, E = 오늘 3장
  r := public.svc_confirm_referral('ffffffff-0000-0000-0000-000000000006');
  assert r->>'result' = 'REJECTED' and r->>'reason' = 'DAILY_CAP', 'F ' || r::text;
  r := public.svc_confirm_referral('99999999-0000-0000-0000-000000000007');
  assert r->>'result' = 'REFEREE_NOT_LINKED', 'anon ' || r::text;
  r := public.svc_confirm_referral('99999999-0000-0000-0000-000000000008');
  assert r->>'result' = 'EXPIRED', 'expired ' || r::text;
  r := public.svc_confirm_referral('99999999-0000-0000-0000-000000000009');
  assert r->>'result' = 'INVALID_REFERRER', 'self ' || r::text;
  r := public.svc_confirm_referral('99999999-0000-0000-0000-00000000000a');
  assert r->>'result' = 'NO_SELF_PROFILE', 'noprofile ' || r::text;
  r := public.svc_confirm_referral('88888888-0000-0000-0000-000000000002', '{"hold": true, "fp_dup": 4}');
  assert r->>'result' = 'HELD', 'held ' || r::text;
end $$;
reset role;

-- ---------------- T10: 익명 → 기존 계정 병합 ----------------
set role service_role;
do $$
declare n int;
begin
  n := public.svc_merge_anonymous('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001');
  assert n = 1, 'merge count';
end $$;
reset role;
do $$ begin
  assert (select is_self from public.saju_profiles where profile_id = '22222222-0000-0000-0000-00000000000a') = false,
         '대상에 본인 프로필이 있으면 병합분은 is_self=false';
  assert (select owner_user_id from public.saju_profiles where profile_id = '22222222-0000-0000-0000-00000000000a') = 'aaaaaaaa-0000-0000-0000-000000000001';
end $$;

-- ---------------- T11: 가입 트리거는 비슈퍼유저 인증 역할로도 동작 ----------------
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    create role supabase_auth_admin nologin;
  end if;
end $$;
grant usage on schema auth to supabase_auth_admin;
grant insert, select on auth.users to supabase_auth_admin;
set role supabase_auth_admin;
insert into auth.users (id, is_anonymous) values ('77777777-0000-0000-0000-000000000001', true);
reset role;
do $$ begin
  assert exists (select 1 from public.app_users where user_id = '77777777-0000-0000-0000-000000000001'),
         'trigger: 비슈퍼유저 INSERT 시 app_users 미생성';
end $$;

select 'ALL TESTS PASSED' as result;
