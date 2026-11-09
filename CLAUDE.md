# CLAUDE.md — 사주 서비스 작업 지침

이 저장소는 990원 스낵형 사주 웹 서비스다. Claude Code는 `docs/PLAN.md`의 Step을 S00부터 순서대로 끝까지 진행한다.

## 문서 지도

| 문서 | 용도 |
|---|---|
| `docs/SPEC.md` | 무엇을 만드는가 — 설계서, 단일 기준 |
| `docs/PLAN.md` | 어떤 순서로, 무엇이 완료인가 — Step별 작업·완료 기준 |
| `docs/PROGRESS.md` | 지금 어디까지 왔는가 — **Claude Code가 갱신** |
| `docs/HUMAN_TASKS.md` | 사람만 할 수 있는 일 — 계정·키·사업자·법무 |

## 세션 시작 루틴 (매번)

1. `docs/PROGRESS.md`를 읽는다. 🔄 진행 중인 Step이 있으면 그 Step의 '다음 세션 메모'부터 이어간다. 없으면 첫 ⬜ Step을 고른다.
2. `docs/PLAN.md`에서 그 Step 절과 '공통 완료 기준'을 읽는다. SPEC은 Step에 적힌 절만 읽는다 (매번 전체를 읽지 않는다).
3. Step의 '선행 조건'을 확인한다. 이전 Step이 ✅가 아니면 진행하지 않는다.
4. PROGRESS에서 상태를 🔄로 바꾸고, 최신 main에서 브랜치 `step/SXX-짧은-이름`을 만든다.

## 진행 규칙

1. 한 번에 한 Step. 하위 작업마다 커밋한다 (Conventional Commits, 예: `feat(core): 절입 시각 표 생성`).
2. **Step 완료** = PLAN의 완료 기준 명령이 전부 통과 → PROGRESS 갱신(✅, PR 링크, 메모, 작업 로그 한 줄) → PR 생성. PR 제목 `[SXX] 이름`, 본문에 완료 기준 체크리스트와 실행 결과 요약.
3. 완료 기준을 못 맞추면 다음 Step으로 가지 않는다. 원인과 시도한 것을 PROGRESS에 ⛔로 남기고 사용자에게 보고한다.
4. **🔒 사람 게이트**: 키·계정 없이 할 수 있는 부분(mock, 테스트 키, 문서, 워크플로 파일)까지 끝낸 뒤 PROGRESS에 `🔒 H번호 대기`로 기록하고, `docs/HUMAN_TASKS.md`의 해당 항목을 사용자에게 그대로 안내한 뒤 멈춘다.
5. PR 생성 후 사용자가 머지하고 "계속"이라고 하면, 최신 main을 받아 다음 Step으로 간다.
6. 컨텍스트가 길어지면 Step 중간이라도 PROGRESS의 '다음 세션 메모'에 남은 일을 적고 커밋한다. 새 세션은 그 메모로 이어받는다.
7. SPEC과 코드가 충돌하면 SPEC을 따른다. SPEC이 틀렸다고 판단되면 임의로 고치지 말고 PR 본문과 PROGRESS에 '제안'으로 남긴다. SPEC 10장 미결정 사항은 기본값으로 진행한다.

## 불변 규칙 (SPEC 0.2 — 위반 금지)

1. 금액·상품·기간은 서버가 `products` 기준으로 결정한다. 클라이언트가 보낸 금액은 무시한다.
2. 유료 본문과 근거 블록(`grounding_md`, `fallback_md`)은 서버 밖으로 나가지 않는다. 티저는 `teaser_text`만.
3. DB 쓰기는 서버(secret 키) 또는 security definer RPC로만. 클라이언트는 본인 데이터 읽기만.
4. READY가 된 리포트는 다시 생성하지 않는다.
5. LLM에는 이름·생년월일·출생 시각·사용자 ID를 보내지 않는다.
6. 만세력·피처 로직을 바꾸면 `engine_version`을 올린다. 기존 데이터는 재계산하지 않는다.
7. 새 테이블은 RLS 활성화 + 클라이언트 쓰기 권한 회수 (SPEC 7.2 템플릿).

## 하지 말 것

- 비밀값(키·토큰·DB 비밀번호)을 커밋하거나 출력·로그에 남기기. `.env.example`에는 이름만 적는다.
- `supabase/migrations/`의 기존 파일 수정. 변경은 새 타임스탬프 마이그레이션으로.
- 운영 배포 워크플로(`deploy-production`) 실행·트리거. 운영 배포는 사용자만 수동으로 한다.
- 테스트를 통과시키려고 테스트를 약화·삭제·skip 처리하기.
- 테스트에서 외부 유료 API 호출. LLM·포트원·카카오는 테스트에서 항상 mock.
- 경쟁 서비스(두루미 등)의 이름·문구·디자인 사용.

## 명령어

Node 22 · pnpm 10 (`package.json`의 `packageManager`로 고정). 모든 명령은 저장소 루트에서 실행한다.

| 목적 | 명령 |
|---|---|
| 설치 | `pnpm install` (CI는 `pnpm install --frozen-lockfile`) |
| **공통 완료 기준 검사** | `pnpm lint && pnpm typecheck && pnpm test` |
| Lint | `pnpm lint` = ESLint(`--max-warnings 0`, typescript-eslint 타입 기반 규칙) + `prettier --check .` |
| 포맷 | `pnpm format` (Prettier. `docs/`·`*.md`·`supabase/`·`tests/db/`는 건드리지 않는다) |
| 타입 검사 | `pnpm typecheck` = 루트 `tsc`(설정·`tests/`) + 각 패키지 `typecheck` (웹은 `next typegen && tsc`) |
| 테스트 | `pnpm test` = Vitest projects (`@saju/core` · `@saju/content` · `@saju/report` · `web` · `scripts`) |
| 패키지 단독 | `pnpm --filter @saju/core test` · `pnpm --filter @saju/core typecheck` (다른 패키지도 같은 형식) |
| 웹 | `pnpm --filter web dev` (localhost:3000) · `pnpm --filter web build` |
| DB 테스트 | `bash scripts/db-test.sh` (= `pnpm db:test`) |
| 비밀값 스캔 | `bash scripts/secret-scan.sh` (= `pnpm secret-scan`) |
| Supabase CLI | `pnpm exec supabase <명령>` (devDependency. 로컬 스택 `supabase start`는 Docker 필요) |

- DB 테스트
  - Postgres 16+ 서버와 `psql`이 필요하다. 접속은 `PGHOST`·`PGPORT`·`PGUSER`·`PGPASSWORD` 환경변수.
  - 환경에 Postgres가 없으면 설치를 시도한다 (예: `apt-get install -y postgresql` 후 클러스터 시작). 설치가 막히면 CI `db` 잡 결과로 확인하고 PR 본문에 그렇게 적는다.
  - 예: `service postgresql start` → `PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres bash scripts/db-test.sh` (postgres 비밀번호가 없으면 먼저 `su postgres -c "psql -c \"alter user postgres password 'postgres'\""`)
- 비밀값 스캔
  - 추적 파일 + add 전 새 파일(.gitignore 제외)을 본다. 발견 시 `파일:줄: 규칙`만 출력하고 값은 출력하지 않는다.
  - 테스트용 가짜 값처럼 의도한 경우에만 그 줄에 `secret-scan: allow`를 적는다. 테스트 코드의 가짜 키는 문자열 조각을 이어 붙여 만든다 (`tests/scripts/secret-scan.test.ts` 참고).
- CI (`.github/workflows/ci.yml`, PR · main push)
  - `db`: Postgres 16 서비스 컨테이너 + `scripts/db-test.sh`
  - `app`: 설치 → lint → typecheck → test → web build → secret-scan (secret-scan은 앞 단계가 실패해도 실행)
  - S04에서 `supabase` 잡을 추가한다.

## 저장소 구조

```
apps/web/              Next.js 16 App Router + Tailwind 4 (OpenNext · Workers 설정은 S05·S09)
packages/saju-core/    @saju/core    만세력·피처 (순수 TypeScript)
packages/content/      @saju/content 근거 블록 데이터·검증·시드
packages/report/       @saju/report  프롬프트·검증·LLM 제공자
supabase/config.toml   Supabase CLI 로컬 설정 (supabase init)
supabase/migrations/   DB 마이그레이션 (init은 검증 완료)
tests/db/              DB 권한·RPC·동시성 테스트
tests/scripts/         저장소 스크립트 테스트 (secret-scan 등)
tests/fixtures/        사람이 확인한 만세력 기준 케이스
scripts/               db-test.sh · secret-scan.sh
docs/                  SPEC · PLAN · PROGRESS · HUMAN_TASKS · research
```

워크스페이스 패키지는 빌드 없이 TypeScript 원본을 내보낸다 (`exports` → `src/index.ts`). 웹은 `transpilePackages`로 가져온다.

## 기술 기본값

Node 22 · pnpm · TypeScript strict · Vitest · Playwright(스모크) · ESLint flat config + Prettier · zod(입력 검증) · luxon(시간대) · Tailwind
