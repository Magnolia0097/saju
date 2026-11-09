#!/usr/bin/env bash
# 동시성 테스트: 잔액 1장에서 두 세션이 동시에 언락 → 정확히 1건만 성공해야 한다.
# 10_rls_rpc.test.sql 실행 직후의 데이터(사용자 A, A의 지인 프로필)를 사용한다.
# 접속 정보는 libpq 환경변수(PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE)로 받는다.
set -euo pipefail

PSQL=(psql -X -q -At -v ON_ERROR_STOP=1)
U="aaaaaaaa-0000-0000-0000-000000000001"
PROF="11111111-0000-0000-0000-00000000000b"

balance() { "${PSQL[@]}" -c "select coalesce(sum(delta),0) from public.ticket_ledger where user_id='$U';"; }

cur=$(balance)
need=$((1 - cur))
if [ "$need" -ne 0 ]; then
  "${PSQL[@]}" -c "insert into public.ticket_ledger (user_id, delta, reason) values ('$U', $need, 'ADMIN');"
fi
[ "$(balance)" = "1" ] || { echo "race: 시작 잔액 설정 실패"; exit 1; }

session() {  # $1=테마, $2=잠금 유지 시간(초)
  "${PSQL[@]}" <<EOF 2>&1 || true
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$U"}';
select public.rpc_unlock_with_ticket('$PROF', '$1');
select pg_sleep($2);
commit;
EOF
}

out1=$(mktemp); out2=$(mktemp)
session CAREER 2 >"$out1" &
p1=$!
sleep 0.5
session LOVE 0 >"$out2" &
p2=$!
wait "$p1" "$p2"

made=$("${PSQL[@]}" -c "select count(*) from public.reports where profile_id='$PROF' and theme_code in ('CAREER','LOVE');")
final=$(balance)
no_ticket=$(cat "$out1" "$out2" | grep -c "NO_TICKET" || true)
rm -f "$out1" "$out2"

echo "race: 생성된 리포트=$made, 최종 잔액=$final, NO_TICKET=$no_ticket"
if [ "$made" = "1" ] && [ "$final" = "0" ] && [ "$no_ticket" = "1" ]; then
  echo "race: OK"
else
  echo "race: FAIL — 동시 언락 직렬화가 깨졌다"
  exit 1
fi
