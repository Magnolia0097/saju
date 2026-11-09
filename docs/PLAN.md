# PLAN — 실행 계획 (Claude Code용)

> 이 문서는 **순서와 완료 기준**을 정의한다. 무엇을 만드는지는 `docs/SPEC.md`, 진행 상황은 `docs/PROGRESS.md`, 사람이 할 일은 `docs/HUMAN_TASKS.md`.

## 사용자가 Claude Code에 보내는 말

- **첫 세션**: `CLAUDE.md를 읽고 docs/PROGRESS.md 기준으로 다음 Step을 진행해 줘. 완료 기준을 전부 통과시키고 PR까지 만든 뒤 결과를 보고해. 사람 게이트에 걸리면 할 수 있는 데까지 하고 멈춰서 내가 할 일을 알려 줘.`
- **PR 머지 후**: `계속`
- **사람 작업을 끝낸 뒤**: `H2 끝났어. 계속` (끝낸 게이트 번호를 알려 준다)

## 전체 흐름

| Step | 이름 | 선행 | 사람 게이트 (🔒 = 이 Step 완료를 막음) |
|---|---|---|---|
| S00 | 저장소 골격 · CI | H0 | — |
| S01 | 만세력 코어 | S00 | — |
| S02 | 피처 추출 · 키 카탈로그 | S01 | — |
| S03a | 콘텐츠 가이드 · 검증기 · 일주 60 | S02 | (H8은 출시 전, 막지 않음) |
| S03b | 공통 근거 블록 65 | S03a | — |
| S03c | 테마 렌즈 블록 67 | S03b | — |
| S04 | Supabase 통합 테스트 | S00 | — |
| S05 | 웹: 온보딩 · 티저 · 페이월 | S02, S04 | — |
| S06 | 리포트 생성 (LLM) | S03c, S05 | 실제 제공자만 H5 (mock으로 완료 가능) |
| S07 | 결제 (포트원 V2) | S05 | — (실결제 확인은 S09) |
| S08 | 카카오 · 병합 · 초대 · 공유 | S05 | — (실로그인 확인은 S09) |
| S09 | 배포 파이프라인 | S06, S07, S08 | 🔒 H1 · H2 |
| S10 | 운영 기능 · 백업 | S09 | 🔒 H7 |
| S11 | 법무 페이지 · 출시 점검 | S10 | — |
| S12 | 운영 출시 (사람) | S11 | 🔒 H4 · H8 · H9 · H10 · H11 |

S04는 S01~S03과 독립이라 순서를 바꿔도 된다. 기본 순서는 표 순서.

**MVP 모드 (선택)**: PROGRESS 상단에 `MVP 모드: LIFE+YEAR`라고 적혀 있으면 S03c는 `SEUN`만 작성하고, 나머지 렌즈·테마(WEALTH·LOVE·CAREER·PAIR)는 `products.is_active=false` 상태로 두며 UI에서 숨긴다. 출시 후 별도 Step으로 추가한다.

## 공통 완료 기준 (모든 Step)

1. `pnpm lint && pnpm typecheck && pnpm test` 통과 (S00 이후)
2. DB에 영향이 있으면 `bash scripts/db-test.sh` 통과 (로컬 불가 시 CI `db` 잡 green)
3. PR의 CI 전체 green
4. `bash scripts/secret-scan.sh` 통과 (S00에서 생성)
5. `docs/PROGRESS.md` 갱신 (상태·PR·메모·작업 로그), 명령이 바뀌면 `CLAUDE.md` '명령어' 갱신
6. 새 환경변수는 `.env.example`과 `docs/HUMAN_TASKS.md` 시크릿 표에 함께 추가
7. 불변 규칙(SPEC 0.2) 위반 없음 — PR 본문에 "불변 규칙 확인" 체크

---

## S00 저장소 골격 · CI

- **읽을 것**: `CLAUDE.md`, SPEC 6.2
- **작업**
  1. 루트: `package.json`(private, `packageManager` pnpm 9+, scripts `lint`·`typecheck`·`test`·`format`·`db:test`), `pnpm-workspace.yaml`(`apps/*`, `packages/*`), `.nvmrc`(22), `tsconfig.base.json`(strict, `noUncheckedIndexedAccess`), ESLint flat config + Prettier, Vitest 설정
  2. 패키지 골격: `packages/saju-core`(`@saju/core`), `packages/content`(`@saju/content`), `packages/report`(`@saju/report`) — 각 `src/index.ts` + 샘플 테스트 1개 + `typecheck`·`test` 스크립트
  3. `apps/web`: Next.js App Router + TypeScript + Tailwind 최소 골격(홈 1개). 빌드 통과까지만 (OpenNext·배포 설정은 S05·S09)
  4. Supabase CLI(devDependency)로 `supabase init` → `supabase/config.toml` 생성. 기존 `supabase/migrations/`는 그대로
  5. `scripts/secret-scan.sh`: 추적 파일에서 비밀값 패턴(`sb_secret_`, `-----BEGIN`, JWT 형태 `eyJ...` 긴 문자열, `sk-`·`sk_live_`류, 값이 채워진 `*_SECRET=`/`*_KEY=` 할당) 검색 → 발견 시 실패. `.env.example`은 값이 비어 있는지만 검사
  6. CI에 `app` 잡 추가: pnpm 설치·캐시 → `pnpm install --frozen-lockfile` → lint → typecheck → test → `pnpm --filter web build` → secret-scan. 기존 `db` 잡 유지
  7. `CLAUDE.md` '명령어' 절을 실제 명령으로 갱신
- **완료 기준**
  - `pnpm install --frozen-lockfile && pnpm lint && pnpm typecheck && pnpm test && pnpm --filter web build`
  - `bash scripts/db-test.sh` (또는 CI `db` 잡 green)
  - `bash scripts/secret-scan.sh`
  - PR CI(`db`, `app`) green
- **PR**: `[S00] 저장소 골격 · CI`

## S01 만세력 코어 (`@saju/core`)

- **읽을 것**: SPEC 3.3, 부록 A, `docs/research/calendar-crosscheck.md`
- **의존성**: `luxon`, `korean-lunar-calendar` (dependencies) / `astronomy-engine`, `lunar-javascript` (devDependencies — 표 생성·교차검증용). 각 라이선스를 확인해 PR 본문에 기록
- **작업**
  1. 타입: `BirthInput { gender: 'M'|'F'; calendar: 'SOLAR'|'LUNAR'|'LUNAR_LEAP'; date: 'YYYY-MM-DD'; time: 'HH:mm' | null }`, `EnginePolicy { zi: 'YAJASI'|'JEONGJASI'; solarOffset: {mode:'FIXED', minutes} | {mode:'LONGITUDE', lon} | {mode:'OFF'}; daeunRounding: 'ROUND'|'FLOOR' }` (기본값은 SPEC 3.3), JSON 직렬화 가능한 `Chart`
  2. 입력 검증: 1900-01-01 ~ 오늘, 음력은 `korean-lunar-calendar`로 유효성(윤달 존재) 확인, 오류 코드 정의
  3. `scripts/gen-solar-terms.ts`: `astronomy-engine`의 `SearchSunLongitude`로 1900~2100년 12절 절입 시각(UTC, 초 단위)을 `src/data/solar-terms.json`으로 생성·커밋. 런타임은 JSON만 조회
  4. 시간 보정: luxon `Asia/Seoul` → UTC → 보정 시각 (SPEC 3.3 ①②③), 존재하지 않거나 중복되는 시각은 `ambiguous`
  5. 4주: 연주(입춘 절대 시각), 월주(12절 + 오호둔), 일주(`(JDN + 49) mod 60`, 자시 정책), 시주(오서둔, 시간 모름이면 `null`)
  6. 오행 개수(8자/6자), 글자별 십성(지지는 본기)
  7. 대운: 방향(양남음녀 순행), 대운수(절입까지 일수 ÷ 3, 정책별 반올림), 대운 10개 간지·시작 나이·연도. 시간 모름이면 12:00 가정
  8. 세운: `seunPillar(year)`(입춘 기준), `currentDaeun(chart, asOf)`
  9. 공개 API: `computeChart(input, policy?) => Chart`, `ENGINE_VERSION = 'calc-1.0.0'`
- **테스트 (Vitest)**
  - 절입 표 2,412건 전부 `lunar-javascript`(UTC+8 → UTC 환산)와 2분 이내
  - 일진: 1900~2100 전 일자 `lunar-javascript`와 불일치 0
  - 음력: 양력 1950-03-18 → 한국 음력 1950-01-30 (중국 기준이면 2-1) 회귀 테스트, 윤달 왕복 변환
  - tzdata: `docs/research`의 오프셋 8건
  - 경계: 절입 ±1분 출생 시 월주(입춘이면 연주도) 전환, 22:30·23:20·23:40·00:20·00:40·01:20·01:40 출생 × 자시 정책 2종, 서머타임 시작·종료일, 시간 모름
  - 대운: 방향 4조합, 대운수를 `lunar-javascript`의 운(運) 계산과 비교 — 반올림 규칙 차이는 ±1년 허용, 차이 규칙을 테스트 주석으로 문서화
  - 기준 케이스: `tests/fixtures/reference_charts.json`에서 `_example`이 아닌 케이스 전부 일치 (없으면 통과)
  - 성능: `computeChart` 1,000회 평균 2ms 미만
- **완료 기준**: `pnpm --filter @saju/core test` 통과, `@saju/core` 라인 커버리지 90% 이상, 공통 완료 기준
- **PR**: `[S01] 만세력 코어`

## S02 피처 추출 · 키 카탈로그

- **읽을 것**: SPEC 3.4, 3.7, 부록 A
- **작업**
  1. `extractFeatures(chart, { asOf }) => FeatureKeys` — SPEC 3.4 표 그대로 (신강약 가중치, 오행·십성 동률 규칙, 신살 다중 라벨과 우선순위, 현재 대운 십성, 세운 관계, 렌즈 키)
  2. 궁합: `extractPairFeatures(a, b)` → 일간 관계 · 일지 관계 · 오행 보완 · 배틀 점수 (SPEC 3.4)
  3. 티저 데이터: 일주 동물 이름(천간 색 + 띠), 오행 차트 데이터
  4. 키 카탈로그: `pnpm --filter @saju/core catalog` → `packages/content/catalog.json` (theme, axis, condition_key, 설명). 합계 약 192 — 다르면 이유를 PR에 기록
  5. `chart_json`·`feature_keys` 직렬화 형식 확정 (SPEC 3.4 예시 형태)
- **테스트**: 부록 A 표 기반 단위 테스트(신살·관계 판정 전부), fast-check 속성 테스트(1900~2050 임의 출생 1만 건 → 모든 키가 카탈로그에 존재, 결정론), 궁합 대칭성
- **완료 기준**: 테스트 통과, `catalog.json` 생성·커밋, 공통 완료 기준
- **PR**: `[S02] 피처 추출 · 키 카탈로그`

## S03a 콘텐츠 가이드 · 검증기 · 일주 60

- **읽을 것**: SPEC 3.5, 3.6.4, 5.6, 부록 A
- **작업**
  1. `packages/content/STYLE.md`: 톤(친근·구체·긍정 프레이밍), 금지 표현(SPEC 5.6), 블록 구조, 좋은 예·나쁜 예 각 3개
  2. 금지 표현 규칙 모듈 `@saju/content/rules` (정규식 목록, S06 리포트 검증에서도 재사용)
  3. 블록 파일 형식 — `packages/content/blocks/<THEME>/<AXIS>/<CONDITION_KEY>.md`
     ```markdown
     ---
     theme: COMMON
     axis: ILJU
     key: GAP_JA
     version: 1
     status: DRAFT
     title: 갑자일주 · 푸른 쥐
     teaser: 무료로 보여 줄 1~2문장 (120자 이내)
     ---
     ## grounding
     - 해석 포인트 bullet (합계 300~600자)

     ## fallback
     LLM 실패 시 대체 본문 (700~1,000자, 선택)
     ```
  4. 검증기 `pnpm --filter @saju/content validate`: 필수 필드, 카탈로그 대비 누락·잉여 키, 분량, 금지 표현, 같은 축 블록 간 유사도(3-gram Jaccard 0.5 미만), 상태값
  5. 시드 생성기 `pnpm --filter @saju/content seed` → `supabase/seed.sql` (`content_blocks` upsert, `REVIEWED`·`PUBLISHED`만). `scripts/db-test.sh`가 이 파일을 자동 적용한다
  6. ILJU 60개 블록 작성 — Claude Code가 직접 쓴다 (외부 LLM API 불필요). 타 서비스·서적 문장 복제 금지
  7. 자체 검수 패스: 부록 A 기준 명리 정합성(일간·일지 오행, 십성 관계)을 다시 확인한 뒤 `status: REVIEWED`
- **완료 기준**: validate 0 오류, ILJU 60개 REVIEWED, 시드 포함 `bash scripts/db-test.sh` 통과, 공통 완료 기준
- **PR**: `[S03a] 콘텐츠 가이드 · 검증기 · 일주 60`

## S03b 공통 근거 블록 65

- **작업**: S03a와 같은 절차로 `SEASON` 12 · `ELEMENT` 21 · `TENGOD` 10 · `SHINSAL` 12 · `DAEUN` 10 작성 → 자체 검수 → REVIEWED
- **완료 기준**: validate 0 오류, 공통 125개 전부 REVIEWED, 시드 포함 db-test 통과, 공통 완료 기준
- **PR**: `[S03b] 공통 근거 블록 65`

## S03c 테마 렌즈 블록 67

- **작업**: `SEUN` 15 → `WEALTH_LENS` 8 → `LOVE_LENS` 20 → `CAREER_LENS` 10 → `PAIR` 14 순서로 작성 (MVP 모드면 `SEUN`만)
- **완료 기준**: validate 0 오류, 카탈로그 전 키(또는 MVP 범위) REVIEWED, db-test 통과, 공통 완료 기준
- **PR**: `[S03c] 테마 렌즈 블록`

## S04 Supabase 통합 테스트

- **읽을 것**: SPEC 7장, 6.6
- **작업**
  1. `supabase/config.toml`: 익명 로그인·수동 계정 연결 활성화, 로컬 CAPTCHA 비활성, 로컬 site_url·redirect URL
  2. `tests/integration/` (Vitest): `supabase start`로 띄운 로컬 스택에 supabase-js로 접속해 SPEC 7.3 표의 시나리오를 publishable 키(익명·로그인 사용자)와 secret 키(서버)로 재현 — RLS 읽기 범위, 쓰기 거부, RPC 오류 코드, `svc_` 함수 권한
  3. 테스트 사용자는 Admin API로 생성. 익명 → 영구 전환은 로컬에서 흉내 (실제 카카오 연결은 S08·스테이징)
  4. CI에 `supabase` 잡 추가: `supabase/setup-cli` 액션 → `supabase start` → 상태 출력으로 환경변수 주입 → 통합 테스트 → `supabase stop`
  5. 로컬에 Docker가 없으면 통합 테스트는 안내와 함께 skip. 단 `CI=true`에서는 skip 대신 실패
- **완료 기준**: CI `supabase` 잡 green, 공통 완료 기준
- **PR**: `[S04] Supabase 통합 테스트`

## S05 웹: 온보딩 · 티저 · 페이월

- **읽을 것**: SPEC 2장, 3.7, 6.4, 6.6
- **작업**
  1. `apps/web`: Tailwind 디자인 토큰, 모바일 우선 레이아웃, 자체 캐릭터 자리 (타 서비스 디자인 차용 금지)
  2. Supabase 클라이언트: 브라우저(publishable 키) / 서버(secret 키 — `server-only`로 클라이언트 번들 유입 차단)
  3. 익명 로그인 + Turnstile. 개발·테스트는 Cloudflare 테스트 키(사이트 `1x00000000000000000000AA`, 시크릿 `1x0000000000000000000000000000000AA`)
  4. 페이지: `/`(랜딩), `/start`(4단계 카드 온보딩, 시간 모름, 22:30~01:30·절입일 안내), `/r/[profileId]`(티저 — 일주 동물, 오행 차트, 핵심 기질 3줄, 섹션 제목 + 첫 섹션 티저, 잠긴 섹션은 더미 텍스트 블러, 결제·초대 버튼은 S07·S08 전까지 '준비 중')
  5. API: `POST /api/ref/capture`, `POST /api/profiles`(zod 검증, 만 14세 미만 차단, 사용자당 24시간 20개 제한, `computeChart` → `extractFeatures` → 저장 → 티저 반환), `GET /api/profiles/[id]/teaser`
  6. `@opennextjs/cloudflare` 설치·설정, `wrangler.jsonc`에 staging·production 환경 이름만. 빌드 확인 (배포는 S09)
- **테스트**: 라우트 핸들러(Supabase mock), 티저 응답에 `grounding`·`fallback` 원문이 없음, 입력 검증 경계값, 온보딩 단계 전환 컴포넌트 테스트
- **완료 기준**: 테스트 통과, `pnpm --filter web build`와 OpenNext 빌드 성공, 공통 완료 기준
- **PR**: `[S05] 온보딩 · 티저 · 페이월`

## S06 리포트 생성 (LLM)

- **읽을 것**: SPEC 3.6 전체, 0.2, 5.6
- **작업**
  1. `@saju/report`: `buildPrompt(theme, chartFacts, blocks, sectionPlan)` — 호칭은 `{{name}}`, 생년월일·시각·ID 미포함. 섹션 계획 상수(SPEC 3.6.3)
  2. 제공자 인터페이스 `LLMProvider` + `MockProvider`(테마별 정상 픽스처 + 실패 유형 주입: 분량 미달, 금지 표현, 사실 불일치, JSON 깨짐)
  3. 실제 제공자 어댑터: H5에서 사용자가 정한 제공자 1개. 미정이면 구현하지 않고 PROGRESS 메모에 `H5 대기(실제 제공자)`를 남긴 뒤 이 Step은 mock으로 완료
  4. 검증기 `validateReport(json, facts, plan)` — SPEC 3.6.4의 1~5 (금지 표현은 `@saju/content/rules` 재사용)
  5. fallback 조립기, 비용 계산(토큰 × 단가 환경변수 → 원화), `LLM_DAILY_BUDGET_KRW` 초과 시 fallback
  6. `POST /api/reports/[id]/generate`: 소유권 확인 → `svc_claim_generation` → 스트리밍 생성 → 검증 → READY 저장(`content_json`, `generation_meta`) / 실패 시 재시도(최대 3회) → fallback → 그래도 실패하면 `svc_refund_report`
  7. `/report/[id]`: 생성 중 화면(재방문 시 잠금이 만료됐으면 재호출) · READY 렌더 · 고지 문구(템플릿)
- **테스트**: 검증기 규칙별, 오케스트레이션(성공 / 실패→재시도→성공 / 3회 실패→fallback / fallback 실패→환불), 프롬프트 스냅샷 + 개인정보 미포함 단언, 비용 계산
- **완료 기준**: 테스트 통과(외부 호출 0), 공통 완료 기준
- **PR**: `[S06] 리포트 생성`

## S07 결제 (포트원 V2)

- **읽을 것**: SPEC 5.1, 5.4, 6.4, 6.5
- **작업**
  1. `POST /api/orders`: 상품·대상·기간 검증, 이미 언락된 대상 거절, 금액은 `products`에서, `order_id` = 포트원 paymentId
  2. 클라이언트 결제: `@portone/browser-sdk`로 결제 요청 (storeId, channelKey, paymentId, orderName, totalAmount = 서버 금액)
  3. `POST /api/payments/complete`: `@portone/server-sdk`로 결제 단건 조회 → 상태·금액 확인 → `svc_mark_order_paid` → `*_CANCEL_REQUIRED`면 포트원 취소 후 주문 상태 반영
  4. `POST /api/webhooks/portone`: 서명 검증 → 같은 처리 (멱등)
  5. 페이월 결제 버튼 활성화 + 결제 전 고지(청약철회 제한, SPEC 5.4) + 결제 완료 → 생성 페이지 이동
- **테스트**: 포트원 클라이언트 mock — 정상, 금액 불일치 → 취소, 이미 언락 → 취소, 콜백·웹훅 중복·순서 뒤바뀜 멱등, 잘못된 서명 401
- **완료 기준**: 테스트 통과, 공통 완료 기준 (실결제 확인은 S09 스테이징)
- **PR**: `[S07] 결제`

## S08 카카오 · 병합 · 초대 · 공유

- **읽을 것**: SPEC 2장, 6.4, 8장
- **작업**
  1. 익명 → 카카오 연결: `linkIdentity({ provider: 'kakao' })`. '이미 연결된 계정' 오류면 병합 흐름
  2. 병합: 익명 상태에서 `/api/auth/merge/token` → HMAC 서명 토큰(익명 user id, 10분 만료, `MERGE_TOKEN_SECRET`) → 카카오 로그인 → 콜백에서 `/api/auth/merge`로 토큰 제출 → 검증 → `svc_merge_anonymous` → Admin API로 익명 사용자 삭제
  3. `POST /api/referrals/confirm`: 카카오 연결 직후·본인 티저 생성 직후 호출. 위험 신호(클라이언트 경량 지문 해시, `CF-Connecting-IP` /24 해시, 24시간 내 같은 지문 신규 연결 3건 이상이면 `hold`) → `svc_confirm_referral`
  4. 초대 UI: 내 초대 링크, 적립 현황, 티켓으로 열기(`rpc_unlock_with_ticket`, 오류 코드별 문구)
  5. 공유: 카카오 JS SDK 공유, 이미지 저장. `apps/web/scripts/gen-cards.ts`(satori + resvg)로 60일주 카드 PNG를 `public/cards/`에 생성
- **테스트**: 병합 토큰 서명·만료·위조, 병합·초대 오케스트레이션(mock), 오류 코드 → 문구 매핑, 카드 60장 생성
- **완료 기준**: 테스트 통과, 공통 완료 기준 (실로그인 확인은 S09 스테이징)
- **PR**: `[S08] 카카오 · 병합 · 초대 · 공유`

## S09 배포 파이프라인

- **읽을 것**: SPEC 6.1~6.3, 6.6, `docs/HUMAN_TASKS.md` 시크릿 표
- **작업**
  1. `wrangler.jsonc`: staging·production 환경, 커스텀 도메인(H2), 호환성 설정
  2. `.github/workflows/deploy-staging.yml`: main push 시 CI 성공 후 → 빌드 → `supabase link` + `supabase db push`(staging, Session pooler) → 콘텐츠 시드 upsert → Workers 시크릿 동기화 → OpenNext 배포(staging) → 스모크
  3. `.github/workflows/deploy-production.yml`: `workflow_dispatch`만, 입력 `confirm`이 `DEPLOY`일 때만 진행 → 같은 단계(PROD_ 시크릿) → 스모크. **Claude Code는 이 워크플로를 실행하지 않는다**
  4. 스모크(Playwright): 랜딩 200, 온보딩 → 티저 렌더, 티저 응답에 원문 미포함, `/api/health`(DB 연결·마이그레이션 버전) 200. H3·H5·H6이 끝나 있으면 카카오 로그인·실제 LLM 생성·테스트 결제 시나리오 추가
  5. `docs/RUNBOOK.md`: 배포·롤백(이전 Workers 버전 복귀, DB는 앞으로 고치는 마이그레이션 원칙), 장애 대응, 시크릿 교체
- **🔒 게이트**: H1 · H2. 시크릿이 없으면 워크플로·문서까지 작성하고 PROGRESS에 `🔒 H1·H2 대기`
- **완료 기준**: 스테이징 배포 워크플로 green + 스모크 통과, 공통 완료 기준
- **PR**: `[S09] 배포 파이프라인`

## S10 운영 기능 · 백업

- **읽을 것**: SPEC 4.4, 6.2, 8.3
- **작업**
  1. `.github/workflows/backup.yml`: 매일 18:00 UTC(03:00 KST) `pg_dump`(서버 메이저 버전과 일치, Session pooler) → gzip → R2 업로드 → 14일 초과분 삭제. 주 1회 복구 리허설 잡(최신 덤프를 Postgres 서비스 컨테이너에 복원 → 행 수 점검)
  2. 새 마이그레이션: `funnel_events`(서버만 INSERT, RLS·권한 회수), `svc_release_held_referral`, KPI 뷰(일별 퍼널·결제·생성 실패율·LLM 비용). `tests/db`에 테스트 추가
  3. `/admin`(서버에서 `ADMIN_USER_IDS` 확인): 주문·환불(포트원 취소 → `svc_refund_report`), 보류 초대 처리, KPI·비용 대시보드
  4. SPEC 4.4 이벤트를 서버 API로 기록 (레이트 리밋)
  5. 에러 추적: `SENTRY_DSN`이 있을 때만 활성
- **🔒 게이트**: H7 (없으면 워크플로 작성까지)
- **완료 기준**: 새 마이그레이션 포함 db-test 통과, 관리자 권한 테스트, 백업 워크플로 수동 실행 1회 성공, 공통 완료 기준
- **PR**: `[S10] 운영 기능 · 백업`

## S11 법무 페이지 · 출시 점검

- **읽을 것**: SPEC 5장, 6.6
- **작업**
  1. `/legal/terms` · `/legal/privacy` · `/legal/refund` · `/legal/youth` 초안 — 상단에 "법률 검토 전 초안" 배지 (H10 완료 후 제거). 사업자 정보는 환경변수에서 푸터·법무 페이지로
  2. `scripts/security-check.sql` + 스테이징 대상 읽기 전용 점검 단계: 모든 public 테이블 RLS ON, anon·authenticated 쓰기 권한 없음, `svc_` 함수 authenticated 실행 불가, `content_blocks` 접근 불가
  3. 금지 표현 전수 검사 (콘텐츠 + 리포트 픽스처)
  4. `docs/LAUNCH_CHECKLIST.md`: 자동 점검 결과 + 사람 항목(H4 · H8 · H9 · H10 · H11)
- **완료 기준**: 스테이징 대상 자동 점검 전부 통과, 체크리스트 작성, 공통 완료 기준
- **PR**: `[S11] 법무 · 출시 점검`

## S12 운영 출시 (사람)

1. H8 콘텐츠 표본 검수, H9 PG 운영 채널, H10 법률 검토·사업자 정보 입력 완료
2. PROD_ 시크릿 확인 → 사용자가 GitHub Actions에서 `deploy-production` 실행 (`confirm: DEPLOY`)
3. 스모크 통과 확인 → 실결제 소액 1건 → 즉시 환불로 결제·환불 경로 확인
4. Claude Code에 `출시 완료`라고 알리면 PROGRESS를 갱신하고 출시 후 백로그(미구현 테마, 가격 실험 등)를 정리한다
