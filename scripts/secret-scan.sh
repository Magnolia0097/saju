#!/usr/bin/env bash
# 비밀값 스캔 — 저장소에 키·토큰·비밀번호가 들어가지 않았는지 검사한다.
#
#   대상  git이 추적하는 파일 + 아직 add 하지 않은 새 파일 (.gitignore로 무시된 파일과 pnpm-lock.yaml 제외)
#   규칙  1) 개인키 블록  2) Supabase secret 키  3) JWT  4) sk-·sk_live_류 API 키
#         5) GitHub·AWS·Slack·Google 토큰
#         6) 값이 채워진 *SECRET* / *KEY* / *TOKEN* / *PASSWORD* 등 할당
#            (참조 `${{ secrets.X }}`·`$X`·`env(X)`·`process.env.X`, 테스트용 더미 값, 8자 미만 값은 통과.
#             .ts/.js 코드에서는 따옴표로 감싼 문자열 값만 본다)
#         7) .env.example 류: 비밀 이름(SECRET·KEY·TOKEN·PASSWORD·DSN 등) 변수는 값이 비어 있어야 한다
#         8) .env · .env.local · .dev.vars 같은 실제 환경 파일이 추적되고 있으면 실패
#   출력  "파일:줄: 규칙"만 출력한다. 값은 출력하지 않는다 (CI 로그로 새지 않게).
#   예외  테스트용 가짜 값처럼 의도한 경우에만 같은 줄에 `secret-scan: allow`를 적는다 (남용 금지).
#
# 사용  bash scripts/secret-scan.sh [저장소 경로]   (기본: 이 스크립트가 들어 있는 저장소)
# 종료  0 = 통과, 1 = 발견, 2 = 실행 오류
set -euo pipefail
export LC_ALL=C # 정규식 범위([A-Z] 등)를 바이트 기준으로 고정

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "secret-scan: git 저장소가 아니다: $ROOT" >&2
  exit 2
}

GIT=(git -c core.quotePath=false)
EXCLUDES=(':(exclude,glob)**/pnpm-lock.yaml')
FINDINGS=()

# git grep 결과("파일:줄:내용")를 받아 허용 표시가 없는 줄만 "파일:줄: 규칙"으로 기록한다.
grep_rule() {
  local rule="$1" re="$2" out status line
  set +e
  out="$("${GIT[@]}" grep --untracked -n -I -E -e "$re" -- . "${EXCLUDES[@]}")"
  status=$?
  set -e
  if [ "$status" -gt 1 ]; then
    echo "secret-scan: git grep 실행 실패 (규칙: $rule)" >&2
    exit 2
  fi
  [ -n "$out" ] || return 0
  while IFS= read -r line; do
    case "$line" in *"secret-scan: allow"*) continue ;; esac
    FINDINGS+=("$(printf '%s' "$line" | cut -d: -f1,2): $rule")
  done <<<"$out"
}

# ── 1~5. 형식이 알려진 비밀값 ──────────────────────────────────────────
grep_rule "개인키 블록" '-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY( BLOCK)?-----'
grep_rule "Supabase secret 키" 'sb_secret_[A-Za-z0-9_-]{16,}'
grep_rule "JWT" 'eyJ[A-Za-z0-9_=-]{10,}\.[A-Za-z0-9_=-]{10,}'
grep_rule "sk- API 키" '(^|[^A-Za-z0-9_-])sk-[A-Za-z0-9_-]{20,}'
grep_rule "sk_live_ 류 API 키" '(^|[^A-Za-z0-9_])(sk|rk)_(live|test)_[A-Za-z0-9]{10,}'
grep_rule "GitHub 토큰" '(gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,})'
grep_rule "AWS 액세스 키" '(^|[^A-Z0-9])(AKIA|ASIA)[A-Z0-9]{16}([^A-Z0-9]|$)'
grep_rule "Slack 토큰" 'xox[abprs]-[A-Za-z0-9-]{10,}'
grep_rule "Google API 키" 'AIza[0-9A-Za-z_-]{35}'

# ── 6·7. 비밀 이름 변수 할당 ───────────────────────────────────────────
NAME_RE='[A-Z0-9_]*(SECRET|KEY|TOKEN|PASSWORD|PASSWD|PRIVATE|CREDENTIAL|DSN)[A-Z0-9_]*'
set +e
candidates="$("${GIT[@]}" grep --untracked -n -I -E -e "${NAME_RE}[\"']?[[:space:]]*[:=]" -- . "${EXCLUDES[@]}")"
status=$?
set -e
if [ "$status" -gt 1 ]; then
  echo "secret-scan: git grep 실행 실패 (비밀 변수 할당)" >&2
  exit 2
fi
if [ -n "$candidates" ]; then
  while IFS= read -r finding; do
    [ -n "$finding" ] && FINDINGS+=("$finding")
  done < <(printf '%s\n' "$candidates" | awk -v NAME="$NAME_RE" '
    function basename(p,   i) { i = split(p, parts, "/"); return parts[i] }
    function is_env_example(p,   b) {
      b = basename(p)
      return b ~ /^\.env(\..+)?\.example$/ || b ~ /^\.dev\.vars(\..+)?\.example$/
    }
    function is_code(p) { return p ~ /\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$/ }
    # 따옴표 값이면 따옴표 안, 아니면 공백·구분자 앞까지. 주석(#)으로 시작하면 빈 값.
    function value_of(s, code_only,   q, i) {
      sub(/^[ \t]+/, "", s)
      if (s == "") return ""
      q = substr(s, 1, 1)
      if (q == "\"" || q == "\047" || q == "`") {
        s = substr(s, 2)
        i = index(s, q)
        return i ? substr(s, 1, i - 1) : s
      }
      if (code_only) return ""
      if (q == "#") return ""
      if (match(s, /[ \t"\047`,;)}\]]/)) s = substr(s, 1, RSTART - 1)
      return s
    }
    function allowed(v,   lv) {
      if (v == "") return 1
      if (length(v) < 8) return 1
      if (v ~ /^[0-9.]+$/) return 1
      lv = tolower(v)
      if (lv ~ /^(\$|<|\{\{|env\(|process\.env|import\.meta\.env|secrets\.|vars\.)/) return 1
      if (lv ~ /^(dummy|fake|mock|test|example|placeholder|changeme|change-me|your[-_]|xxx|\*\*\*|redacted|undefined)/) return 1
      if (v == "postgres") return 1                       # 로컬·CI 테스트 DB 기본 비밀번호
      if (v ~ /^[0-9]x00000000+[A-Z][A-Z]$/) return 1   # Cloudflare Turnstile 공개 테스트 키
      return 0
    }
    {
      p = index($0, ":"); path = substr($0, 1, p - 1); rest = substr($0, p + 1)
      p = index(rest, ":"); ln = substr(rest, 1, p - 1); line = substr(rest, p + 1)
      if (index(line, "secret-scan: allow")) next

      if (is_env_example(path)) {
        if (match(line, "^[ \t]*(export[ \t]+)?" NAME "=")) {
          if (value_of(substr(line, RSTART + RLENGTH), 0) != "")
            print path ":" ln ": .env.example 비밀 변수에 값이 들어 있음"
        }
        next
      }

      # 줄 맨 앞의 키 (env · shell · YAML · TOML · JSON 키)
      if (match(line, "^[ \t]*(export[ \t]+|ENV[ \t]+|-[ \t]+)?[\"\047]?" NAME "[\"\047]?[ \t]*[:=]")) {
        if (!allowed(value_of(substr(line, RSTART + RLENGTH), is_code(path)))) {
          print path ":" ln ": 값이 채워진 비밀 변수 할당"
          next
        }
      }
      # 줄 중간의 NAME=값 (명령 앞 환경변수, 문자열 속 env 형식)
      s = line
      while (match(s, "(^|[ \t\"\047`])" NAME "=")) {
        rest = substr(s, RSTART + RLENGTH)
        if (rest !~ /^[ \t]/ && !allowed(value_of(rest, 0))) {
          print path ":" ln ": 값이 채워진 비밀 변수 할당"
          break
        }
        s = rest
      }
    }')
fi

# ── 8. 추적 중인 실제 환경 파일 ────────────────────────────────────────
while IFS= read -r f; do
  b="${f##*/}"
  case "$b" in
    *.example) ;;
    .env | .env.* | .dev.vars | .dev.vars.*) FINDINGS+=("$f:0: 실제 환경 파일이 저장소에 포함됨") ;;
  esac
done < <("${GIT[@]}" ls-files --cached --others --exclude-standard)

count="$("${GIT[@]}" ls-files --cached --others --exclude-standard | wc -l | tr -d ' ')"
if [ "${#FINDINGS[@]}" -gt 0 ]; then
  echo "secret-scan: 비밀값으로 보이는 항목 ${#FINDINGS[@]}건 (값은 출력하지 않음)"
  printf '  %s\n' "${FINDINGS[@]}" | sort -u
  echo "→ 실제 비밀값이면 파일에서 지우고 키를 즉시 폐기·재발급한다. 의도한 가짜 값이면 그 줄에 'secret-scan: allow'를 적는다."
  exit 1
fi
echo "secret-scan: OK (파일 ${count}개 검사)"
