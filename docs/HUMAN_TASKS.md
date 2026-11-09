# HUMAN_TASKS — 사람만 할 수 있는 일

Claude Code는 코드·테스트·워크플로·문서는 전부 만들 수 있지만, **계정 생성, 키 발급, 결제 수단 등록, 사업자·PG 심사, 법률 검토**는 할 수 없다. 아래 항목이 끝나면 Claude Code에 `H번호 끝났어. 계속`이라고 알려 준다.

> 비밀값은 채팅으로 Claude Code에 보내지 말고 **GitHub Secrets에만** 넣는다. Claude Code는 시크릿 이름만 알면 된다.

## 한눈에 보기

| ID | 할 일 | 언제까지 | 비용 | 막는 Step |
|---|---|---|---|---|
| H0 | GitHub 저장소 + Claude Code 연결 | 지금 | 0원 | 전부 |
| H4 | 겸업 확인 · 사업자등록 · 통신판매업 · PG 신청 | **지금 시작** (리드타임 수 주) | 신고 비용 소액 | S12 |
| H1 | Supabase 프로젝트 2개(스테이징·운영) + 설정 | S09 전 | 0원 (트래픽 늘면 Pro 월 25달러 ≈ 3.6만 원) | S09 |
| H2 | Cloudflare 계정 · API 토큰 · Turnstile · 도메인 | S09 전 | Workers Paid 월 5달러 ≈ 7,250원 + 도메인 연 1.5만 원 안팎 | S09 |
| H3 | 카카오 디벨로퍼스 앱 | S09 스테이징 확인 전 | 0원 | S09 스모크 일부 |
| H5 | LLM 제공자 선택 · API 키 | S06 실호출 / S09 전 | 리포트 1건 약 30~50원 | S06 실제 제공자 |
| H6 | 포트원 상점 · 테스트 채널 · 웹훅 | S09 스테이징 결제 전 | 0원 | S09 스모크 일부 |
| H7 | R2 버킷 · 액세스 키 (백업) | S10 전 | 무료 한도 내 | S10 |
| H8 | 콘텐츠 표본 검수 | 출시 전 | — | S12 |
| H9 | PG 운영 채널 키 (심사 승인 후) | 출시 전 | 결제 수수료 | S12 |
| H10 | 약관 · 처리방침 법률 검토 + 사업자 정보 | 출시 전 | 검토 비용(선택) | S12 |
| H11 | 운영 배포 실행 | 출시 | — | S12 |

---

## H0. GitHub 저장소 + Claude Code 연결 (지금)

1. GitHub에 **private** 저장소 생성 (예: `saju-service`)
2. 이 스타터 키트 파일 전체를 main에 올린다
3. 저장소 설정
   - Actions 허용
   - (권장) main 브랜치 보호: PR 필수 + CI 통과 필수 → Claude Code가 main에 직접 푸시하지 못하게
4. Claude Code(웹 또는 GitHub 연동)에 이 저장소 접근 권한 부여 → 첫 세션에 `docs/PLAN.md`의 '첫 세션' 문장 전달

## H4. 사업자 · PG (지금 시작 — 가장 오래 걸림)

1. **재직 중이면 회사 겸업 규정부터 확인**
2. 사업자등록 (홈택스) — 간이과세 여부는 세무 상담
3. 통신판매업 신고 (정부24) — 법상 면제 기준이 있어도 PG가 신고증을 요구하는 경우가 많다
4. 포트원 가입 → PG 2~3곳 동시 신청 (사주·운세는 유의업종. KG이니시스·네이버페이는 취급 불가 — SPEC 5.1)
   - 심사 서류의 약관·처리방침·환불정책은 S11 초안을 쓰면 된다 (그 전에 필요하면 Claude Code에 초안만 먼저 요청)
5. 승인되면 H9로

## H1. Supabase (S09 전)

1. 계정 생성 → 프로젝트 2개: `saju-staging`, `saju-prod` (리전: 서울)
2. 각 프로젝트 인증 설정
   - 익명 로그인(Anonymous sign-ins) 켜기
   - 수동 계정 연결(Manual linking) 켜기
   - CAPTCHA 보호 켜기 → 제공자 Turnstile, 시크릿 키는 H2에서 발급
   - Site URL / Redirect URLs: 스테이징·운영 도메인과 `http://localhost:3000`
   - 카카오 제공자는 H3에서
3. 값 모으기 → GitHub Secrets (아래 표)
   - 프로젝트 ref, DB 비밀번호
   - API 키: publishable 키(구 anon), secret 키(구 service_role)
   - DB 연결 문자열: **Session pooler** 것 (GitHub Actions는 IPv6를 지원하지 않음)
   - 계정 액세스 토큰 (CLI용, 계정 설정에서 발급) → `SUPABASE_ACCESS_TOKEN`

## H2. Cloudflare (S09 전)

1. 계정 생성 → Workers Paid 플랜(월 5달러) — 결제 오픈 전에는 무료로 시작해도 된다
2. API 토큰: 'Edit Cloudflare Workers' 템플릿으로 생성 → `CLOUDFLARE_API_TOKEN`, 계정 ID → `CLOUDFLARE_ACCOUNT_ID`
3. Turnstile 위젯 생성 (도메인: 스테이징·운영·localhost) → 사이트 키는 GitHub Variables, 시크릿 키는 Supabase CAPTCHA 설정(H1)에 입력
4. 도메인 구매(Cloudflare 또는 국내 등록업체) → Cloudflare DNS에 연결. 스테이징은 `staging.<도메인>` 사용 예정 (설정은 Claude Code가 S09에서)

## H3. 카카오 디벨로퍼스 (S09 스테이징 확인 전)

1. 애플리케이션 추가 → 앱 키 확인 (REST API 키, JavaScript 키)
2. 플랫폼 Web 사이트 도메인 등록: 스테이징·운영·`http://localhost:3000`
3. 카카오 로그인 활성화 → Redirect URI에 각 Supabase 프로젝트 콜백 `https://<project-ref>.supabase.co/auth/v1/callback` 등록
4. 동의항목: 닉네임. 이메일이 필요하다고 나오면 비즈앱 전환 조건 확인 (사업자등록 후 가능)
5. 보안: Client Secret 생성·활성화
6. Supabase(스테이징·운영) 인증 제공자 Kakao에 REST API 키(Client ID)와 Client Secret 입력
7. JavaScript 키 → GitHub Variables `NEXT_PUBLIC_KAKAO_JS_KEY` (공유 기능용, 공개돼도 되는 키)

## H5. LLM (S06 실호출 / S09 전)

1. 제공자 선택 (경량 모델, 한국어 품질 기준) → Claude Code에 제공자·모델명을 알려 준다 (S06에서 어댑터 구현)
2. API 키 발급 → `LLM_API_KEY` 시크릿, 제공자 콘솔에서 월 사용 한도·알림 설정
3. 단가가 SPEC 가정과 다르면 Variables `LLM_PRICE_INPUT_USD_PER_M`·`LLM_PRICE_OUTPUT_USD_PER_M` 수정

## H6. 포트원 (S09 스테이징 결제 전)

1. 포트원 콘솔 → 상점 생성 → Store ID
2. **테스트 채널** 추가 (PG 승인 전에도 가능) → Channel Key
3. V2 API Secret 발급
4. 웹훅: URL `https://staging.<도메인>/api/webhooks/portone` 등록 → 웹훅 시크릿
5. 운영 채널은 PG 승인 후 H9에서

## H7. 백업용 R2 (S10 전)

1. Cloudflare R2 버킷 생성: `saju-backups`
2. R2 API 토큰(Access Key ID / Secret) 발급 → 시크릿

## H8. 콘텐츠 표본 검수 (출시 전)

- `packages/content/blocks/`에서 무작위 30개를 읽고, 명리적으로 틀리거나 어색한 블록을 Claude Code에 알려 준다 (Claude Code가 수정 → `PUBLISHED`)
- 가능하면 명리 지식이 있는 사람에게 일부 감수 요청

## H9. PG 운영 채널 (심사 승인 후)

- 포트원 콘솔에서 운영 채널 추가 → `PROD_PORTONE_CHANNEL_KEY` 등 운영 시크릿 갱신, 운영 웹훅 URL 등록

## H10. 법무 (출시 전)

- `/legal/*` 초안 법률 검토 (환불·청약철회, 개인정보 국외 이전, 보유 기간)
- 사업자 정보 입력: `BUSINESS_*`, `MAIL_ORDER_REG_NO`, `CS_EMAIL` (GitHub Variables 또는 Secrets)

## H11. 운영 배포 (출시)

- GitHub → Actions → `deploy-production` → Run workflow → `confirm`에 `DEPLOY` 입력
- 스모크 통과 확인 → 실결제 소액 1건 → 즉시 환불로 경로 확인

---

## GitHub Secrets / Variables 목록

저장소 Settings → Secrets and variables → Actions. `STAGING_`·`PROD_` 접두사로 환경을 구분한다.

### Secrets (비밀)

| 이름 | 출처 | 필요 시점 |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | H1 | S09 |
| `STAGING_SUPABASE_PROJECT_REF` / `PROD_SUPABASE_PROJECT_REF` | H1 | S09 |
| `STAGING_SUPABASE_DB_PASSWORD` / `PROD_SUPABASE_DB_PASSWORD` | H1 | S09 |
| `STAGING_SUPABASE_DB_URL` / `PROD_SUPABASE_DB_URL` | H1 (Session pooler) | S09 · S10 |
| `STAGING_SUPABASE_SECRET_KEY` / `PROD_SUPABASE_SECRET_KEY` | H1 | S09 |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | H2 | S09 |
| `LLM_API_KEY` | H5 | S09 (실제 LLM) |
| `STAGING_PORTONE_API_SECRET` / `PROD_PORTONE_API_SECRET` | H6 / H9 | S09 / 출시 |
| `STAGING_PORTONE_WEBHOOK_SECRET` / `PROD_PORTONE_WEBHOOK_SECRET` | H6 / H9 | S09 / 출시 |
| `STAGING_MERGE_TOKEN_SECRET` / `PROD_MERGE_TOKEN_SECRET` | 직접 생성 (32바이트 이상 랜덤) | S09 |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | H7 | S10 |
| `SENTRY_DSN` (선택) | 에러 추적 서비스 | S10 |

### Variables (공개돼도 되는 값)

| 이름 | 출처 | 필요 시점 |
|---|---|---|
| `STAGING_SUPABASE_URL` / `PROD_SUPABASE_URL` | H1 | S09 |
| `STAGING_SUPABASE_PUBLISHABLE_KEY` / `PROD_SUPABASE_PUBLISHABLE_KEY` | H1 | S09 |
| `STAGING_BASE_URL` / `PROD_BASE_URL` | H2 도메인 | S09 |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | H2 | S09 |
| `NEXT_PUBLIC_KAKAO_JS_KEY` | H3 | S09 |
| `STAGING_PORTONE_STORE_ID` · `STAGING_PORTONE_CHANNEL_KEY` / `PROD_…` | H6 / H9 | S09 / 출시 |
| `LLM_PROVIDER`, `LLM_MODEL` | H5 | S09 |
| `LLM_PRICE_INPUT_USD_PER_M`, `LLM_PRICE_OUTPUT_USD_PER_M`, `USD_KRW`, `LLM_DAILY_BUDGET_KRW` | SPEC 3.6.6 | S09 |
| `ADMIN_USER_IDS` | 운영자 auth user id | S10 |
| `R2_BUCKET` | H7 | S10 |
| `BUSINESS_NAME`, `BUSINESS_CEO`, `BUSINESS_REG_NO`, `MAIL_ORDER_REG_NO`, `BUSINESS_ADDRESS`, `CS_EMAIL` | H4 · H10 | 출시 |

Claude Code가 새 환경변수를 추가하면 이 표와 `.env.example`을 함께 갱신한다.
