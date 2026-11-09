#!/usr/bin/env bash
# DB 검증 러너
#   빈 DB 생성 → Supabase 권한 모의 → supabase/migrations 전부 적용 → (있으면) 시드 적용
#   → RLS·RPC 테스트 → 동시성 테스트 → DB 삭제
# 접속: libpq 환경변수(PGHOST, PGPORT, PGUSER, PGPASSWORD). 슈퍼유저 권한 필요(역할 생성).
#   로컬 예) PGHOST=/var/run/postgresql PGUSER=postgres bash scripts/db-test.sh
#   CI     ) postgres:16 서비스 컨테이너 + PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="saju_test_$(date +%s)_$$"
export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"
PSQL=(psql -X -q -v ON_ERROR_STOP=1)

command -v psql >/dev/null || { echo "psql이 없다. PostgreSQL 클라이언트(16+)를 설치하거나 CI 결과로 확인할 것."; exit 2; }

cleanup() { "${PSQL[@]}" -d postgres -c "drop database if exists \"$DB\";" >/dev/null 2>&1 || true; }
trap cleanup EXIT

"${PSQL[@]}" -d postgres -c "create database \"$DB\";"
export PGDATABASE="$DB"

echo "→ Supabase 권한 모의 환경"
"${PSQL[@]}" -f "$ROOT/tests/db/00_supabase_mock.sql"

shopt -s nullglob
migrations=("$ROOT"/supabase/migrations/*.sql)
[ ${#migrations[@]} -gt 0 ] || { echo "마이그레이션 파일이 없다"; exit 1; }
for f in "${migrations[@]}"; do
  echo "→ migration: $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done

if [ -f "$ROOT/supabase/seed.sql" ]; then
  echo "→ seed: supabase/seed.sql"
  "${PSQL[@]}" -f "$ROOT/supabase/seed.sql"
fi

echo "→ RLS·RPC 테스트"
"${PSQL[@]}" -f "$ROOT/tests/db/10_rls_rpc.test.sql" >/tmp/"$DB".log 2>&1 || { cat /tmp/"$DB".log; exit 1; }
grep -q "ALL TESTS PASSED" /tmp/"$DB".log || { cat /tmp/"$DB".log; exit 1; }
echo "   ALL TESTS PASSED"

echo "→ 동시성 테스트"
bash "$ROOT/tests/db/20_race.test.sh"

echo "DB TESTS OK"
