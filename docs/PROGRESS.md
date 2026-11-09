# PROGRESS — 진행 상황

> Claude Code가 Step을 시작·완료·차단할 때마다 갱신한다.
> 상태: ⬜ 대기 · 🔄 진행 중 · ✅ 완료 · 🔒 사람 작업 대기 · ⛔ 막힘

MVP 모드: 꺼짐 (켜려면 이 줄을 `MVP 모드: LIFE+YEAR`로 바꾼다 — PLAN 참고)

## Step 현황

| Step | 이름 | 상태 | PR | 메모 |
|---|---|---|---|---|
| S00 | 저장소 골격 · CI | ✅ | [#1](https://github.com/Magnolia0097/saju/pull/1) | pnpm 10 · Node 22 · TS 6.0 · ESLint 10 · Vitest 5 · Next.js 16.4 · Tailwind 4 · Supabase CLI 2.122. CI `db` · `app` |
| S01 | 만세력 코어 | ⬜ | | 계산 방식 사전 검증: `docs/research/calendar-crosscheck.md` |
| S02 | 피처 추출 · 키 카탈로그 | ⬜ | | |
| S03a | 콘텐츠 가이드 · 검증기 · 일주 60 | ⬜ | | |
| S03b | 공통 근거 블록 65 | ⬜ | | |
| S03c | 테마 렌즈 블록 67 | ⬜ | | |
| S04 | Supabase 통합 테스트 | ⬜ | | |
| S05 | 웹: 온보딩 · 티저 · 페이월 | ⬜ | | |
| S06 | 리포트 생성 (LLM) | ⬜ | | 실제 제공자는 H5 후 |
| S07 | 결제 (포트원 V2) | ⬜ | | |
| S08 | 카카오 · 병합 · 초대 · 공유 | ⬜ | | |
| S09 | 배포 파이프라인 | ⬜ | | 🔒 H1 · H2 필요 |
| S10 | 운영 기능 · 백업 | ⬜ | | 🔒 H7 필요 |
| S11 | 법무 페이지 · 출시 점검 | ⬜ | | |
| S12 | 운영 출시 (사람) | ⬜ | | H4 · H8 · H9 · H10 · H11 |

## 사람 작업 현황 (상세: HUMAN_TASKS.md)

| ID | 내용 | 필요 시점 | 상태 |
|---|---|---|---|
| H0 | GitHub 저장소 + Claude Code 연결 | 지금 | 🔄 키트 main 반영·Actions 동작 확인. **저장소가 public → private 전환 필요 (S03a 전 필수)**, main 보호 규칙(권장) |
| H4 | 겸업 확인 · 사업자 · 통신판매업 · PG 신청 | 지금 시작 | ⬜ |
| H1 | Supabase 프로젝트 2개 + 설정 + 시크릿 | S09 전 | ⬜ |
| H2 | Cloudflare 계정 · 토큰 · Turnstile · 도메인 | S09 전 | ⬜ |
| H3 | 카카오 디벨로퍼스 앱 | S09 스테이징 확인 전 | ⬜ |
| H5 | LLM 제공자 · API 키 | S06 실호출 / S09 전 | ⬜ |
| H6 | 포트원 상점 · 테스트 채널 · 웹훅 | S09 스테이징 결제 전 | ⬜ |
| H7 | R2 버킷 · 키 | S10 전 | ⬜ |
| H8 | 콘텐츠 표본 검수 | 출시 전 | ⬜ |
| H9 | PG 운영 채널 키 | 출시 전 | ⬜ |
| H10 | 법률 검토 + 사업자 정보 | 출시 전 | ⬜ |
| H11 | 운영 배포 실행 | 출시 | ⬜ |

## 다음 세션 메모

(Step 중간에 멈출 때 남은 일을 여기에 적는다. 이어받은 세션은 이 메모부터 처리하고 지운다.)

- 저장소 공개 범위: 2026-11-09 확인 시 **public**. S03a부터 유료 근거 블록(`grounding`·`fallback`)이 커밋되므로 그 전에 private으로 바꿔야 한다 (SPEC 0.2-2). 다음 Step 시작 전 공개 범위를 다시 확인한다.

## 작업 로그

- 2026-11-09 — S00 완료 ([#1](https://github.com/Magnolia0097/saju/pull/1)): pnpm 워크스페이스(TS 6.0 strict · ESLint 10 · Prettier · Vitest 5), 패키지 골격 3개, Next.js 16 웹 골격, `supabase init`, `scripts/secret-scan.sh`(+테스트 19개), CI `app` 잡
- 2026-11-09 — 스타터 키트를 main 초기 커밋으로 반영 (H0 2단계를 Claude Code가 대행). CI `db` 잡 main에서 green
- 2026-11-09 — 스타터 키트 생성: SPEC v2.1, `supabase/migrations/20261109000000_init.sql`, DB 테스트(RLS · RPC · 결제 · 초대 · 동시성 — 행 잠금 제거 변이에서 이중 차감 검출 확인), CI `db` 잡, 만세력 계산 방식 사전 검증(`docs/research/`)
