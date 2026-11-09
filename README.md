# saju-service

990원 스낵형 사주 웹 서비스. 이 저장소는 **Claude Code가 설계서대로 개발·배포**하도록 구성돼 있다.

## 시작하기

1. 이 파일들을 GitHub private 저장소 main에 올린다 (`docs/HUMAN_TASKS.md` H0)
2. 사업자·PG 준비(H4)는 리드타임이 길어서 지금 같이 시작한다
3. Claude Code에 첫 지시를 보낸다:

   > CLAUDE.md를 읽고 docs/PROGRESS.md 기준으로 다음 Step을 진행해 줘. 완료 기준을 전부 통과시키고 PR까지 만든 뒤 결과를 보고해. 사람 게이트에 걸리면 할 수 있는 데까지 하고 멈춰서 내가 할 일을 알려 줘.

4. PR을 머지하고 `계속`이라고 보내는 것을 반복한다. 사람 작업이 필요하면 Claude Code가 `docs/HUMAN_TASKS.md`의 항목 번호로 알려 준다

## 문서

| 문서 | 내용 |
|---|---|
| `CLAUDE.md` | Claude Code 작업 지침 (매 세션 자동으로 읽힘) |
| `docs/SPEC.md` | 설계서 v2.1 — 무엇을 만드는가 |
| `docs/PLAN.md` | Step별 작업 · 완료 기준 · 게이트 |
| `docs/PROGRESS.md` | 진행 상황 |
| `docs/HUMAN_TASKS.md` | 사람만 할 수 있는 일 · 시크릿 목록 |
| `docs/research/` | 만세력 계산 방식 사전 검증 |

## 이미 들어 있는 것 (검증 완료)

- `supabase/migrations/20261109000000_init.sql` — 스키마 · RLS · RPC
- `tests/db/` + `scripts/db-test.sh` — 권한 · RPC · 결제 · 초대 · 동시성 테스트 (Postgres 16)
- `.github/workflows/ci.yml` — 위 DB 테스트를 PR마다 실행

```bash
# 로컬 실행 예시 (Postgres 16+ 슈퍼유저 접속)
PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres bash scripts/db-test.sh
```
