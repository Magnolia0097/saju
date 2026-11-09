import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { afterAll, describe, expect, it } from 'vitest';

const SCRIPT = resolve(dirname(fileURLToPath(import.meta.url)), '../../scripts/secret-scan.sh');

/** 스캐너가 이 테스트 파일 자체를 잡지 않도록 가짜 비밀값은 조각을 이어 붙여 만든다. */
const glue = (...parts: string[]) => parts.join('');

const FAKE = {
  privateKey: glue('-----BEGIN ', 'RSA PRIVATE KEY', '-----'),
  supabaseSecret: glue('sb_', 'secret_', 'A1b2C3d4E5f6G7h8I9j0K1l2'),
  jwt: glue(
    'eyJ',
    'hbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
    '.',
    'eyJ',
    'zdWIiOiIxMjM0NTY3ODkwIn0',
    '.',
    'c2lnbmF0dXJlc2lnbmF0dXJl',
  ),
  skKey: glue('sk', '-proj-', 'ABCDEFGHIJKLMNOPQRSTUVWX0123'),
  skLive: glue('sk', '_live_', '51HxYzABCDEFGHIJ'),
  github: glue('ghp', '_', 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij'),
  aws: glue('AKIA', 'ABCDEFGHIJKLMNOP'),
  slack: glue('xoxb', '-', '1234567890-abcdefghij'),
  google: glue('AIza', 'SyA1234567890abcdefghijklmnopqrstuv'),
  /** 형식이 없는 임의 비밀값 (할당 규칙 검사용) */
  value: glue('real', 'Value', '9f8e7d6c5b4a'),
} as const;

const created: string[] = [];

afterAll(() => {
  for (const dir of created) rmSync(dir, { recursive: true, force: true });
});

function git(cwd: string, ...args: string[]): void {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8' });
  if (r.status !== 0) throw new Error(`git ${args.join(' ')} 실패: ${r.stderr}`);
}

function writeFiles(root: string, files: Record<string, string>): void {
  for (const [path, content] of Object.entries(files)) {
    const full = join(root, path);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, content);
  }
}

/** tracked는 git add까지, untracked는 파일만 만든다. */
function makeRepo(tracked: Record<string, string>, untracked: Record<string, string> = {}): string {
  const dir = mkdtempSync(join(tmpdir(), 'secret-scan-'));
  created.push(dir);
  git(dir, 'init', '-q');
  writeFiles(dir, tracked);
  git(dir, 'add', '-A', '-f');
  writeFiles(dir, untracked);
  return dir;
}

function scan(dir: string) {
  const r = spawnSync('bash', [SCRIPT, dir], { encoding: 'utf8' });
  return { status: r.status, out: `${r.stdout}${r.stderr}` };
}

describe('secret-scan.sh', () => {
  it.each([
    ['개인키 블록', FAKE.privateKey],
    ['Supabase secret 키', FAKE.supabaseSecret],
    ['JWT', FAKE.jwt],
    ['sk- API 키', FAKE.skKey],
    ['sk_live_ 류 API 키', FAKE.skLive],
    ['GitHub 토큰', FAKE.github],
    ['AWS 액세스 키', FAKE.aws],
    ['Slack 토큰', FAKE.slack],
    ['Google API 키', FAKE.google],
  ])('%s를 위치와 함께 보고하고 값은 출력하지 않는다', (rule, secret) => {
    const dir = makeRepo({ 'src/leak.txt': `첫 줄\nconfig ${secret}\n` });
    const { status, out } = scan(dir);
    expect(status).toBe(1);
    expect(out).toContain(`src/leak.txt:2: ${rule}`);
    expect(out).not.toContain(secret);
  });

  it.each([
    ['deploy.sh', `export SUPABASE_SECRET_KEY=${FAKE.value}\n`],
    ['ci.yml', `env:\n  PORTONE_API_SECRET: ${FAKE.value}\n`],
    ['wrangler.jsonc', `{\n  "LLM_API_KEY": "${FAKE.value}"\n}\n`],
    ['src/config.ts', `export const env = {\n  MERGE_TOKEN_SECRET: '${FAKE.value}',\n};\n`],
    ['inline.yml', `run: LLM_API_KEY=${FAKE.value} pnpm test\n`],
  ])('값이 채워진 비밀 변수 할당을 잡는다 (%s)', (path, content) => {
    const dir = makeRepo({ [path]: content });
    const { status, out } = scan(dir);
    expect(status).toBe(1);
    expect(out).toContain('값이 채워진 비밀 변수 할당');
    expect(out).toContain(`${path}:`);
    expect(out).not.toContain(FAKE.value);
  });

  it('참조 · 더미 · 테스트 키 · 코드 표현식은 통과시킨다', () => {
    const dir = makeRepo(
      {
        'docs/guide.md': [
          '패턴 예: `sb_secret_`, `-----BEGIN`, `eyJ...`, 값이 채워진 `*_SECRET=`/`*_KEY=`',
          'PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres bash scripts/db-test.sh',
        ].join('\n'),
        '.github/workflows/deploy.yml': [
          'env:',
          '  SUPABASE_SECRET_KEY: ${{ secrets.STAGING_SUPABASE_SECRET_KEY }}',
          '  PGPASSWORD: postgres',
          '  POSTGRES_PASSWORD: postgres',
          '  NEXT_PUBLIC_TURNSTILE_SITE_KEY: 1x00000000000000000000AA',
          '  TOKEN_TTL_SECONDS: 86400',
          '  MERGE_TOKEN_SECRET: ""',
        ].join('\n'),
        'src/env.ts': [
          'export const schema = z.object({',
          '  SUPABASE_SECRET_KEY: z.string().min(1),',
          '  MERGE_TOKEN_SECRET: process.env.MERGE_TOKEN_SECRET,',
          '});',
          "const CACHE_KEY = 'profile-teaser-cache-v1';",
          "const secret = process.env.SUPABASE_SECRET_KEY ?? '';",
        ].join('\n'),
        'scripts/run.sh': [
          'TURNSTILE_SECRET_KEY=1x0000000000000000000000000000000AA pnpm dev',
          'LLM_API_KEY="$LLM_API_KEY" pnpm test',
          `MERGE_TOKEN_SECRET=${FAKE.value} pnpm test # secret-scan: allow`,
        ].join('\n'),
        'supabase/config.toml': 'secret = "env(SUPABASE_AUTH_EXTERNAL_KAKAO_SECRET)"\n',
        '.env.example': [
          'SUPABASE_SECRET_KEY=                      # 서버 전용',
          'LLM_PROVIDER=mock',
          'LLM_PRICE_INPUT_USD_PER_M=0.75',
          'APP_BASE_URL=http://localhost:3000',
          'SENTRY_DSN=',
        ].join('\n'),
        '.gitignore': '.env.local\n',
      },
      { '.env.local': `SUPABASE_SECRET_KEY=${FAKE.value}\n` },
    );
    const { status, out } = scan(dir);
    expect(out).toMatch(/secret-scan: OK/);
    expect(status).toBe(0);
  });

  it('.env.example의 비밀 이름 변수에 값이 있으면 실패한다', () => {
    const dir = makeRepo({
      '.env.example': `LLM_PROVIDER=mock\nLLM_API_KEY=${FAKE.value}\n`,
      'apps/web/.dev.vars.example': 'PORTONE_WEBHOOK_SECRET=abc\n',
    });
    const { status, out } = scan(dir);
    expect(status).toBe(1);
    expect(out).toContain('.env.example:2: .env.example 비밀 변수에 값이 들어 있음');
    // .env.example 은 길이와 무관하게 비어 있어야 한다
    expect(out).toContain('apps/web/.dev.vars.example:1: .env.example 비밀 변수에 값이 들어 있음');
    expect(out).not.toContain(FAKE.value);
  });

  it('추적 중인 실제 환경 파일을 잡는다', () => {
    const dir = makeRepo({ '.env': 'APP_ENV=development\n', 'apps/web/.dev.vars': 'X=1\n' });
    const { status, out } = scan(dir);
    expect(status).toBe(1);
    expect(out).toContain('.env:0: 실제 환경 파일이 저장소에 포함됨');
    expect(out).toContain('apps/web/.dev.vars:0: 실제 환경 파일이 저장소에 포함됨');
  });

  it('아직 add 하지 않은 새 파일도 검사한다', () => {
    const dir = makeRepo(
      { 'README.md': '# ok\n' },
      { 'notes.txt': `key ${FAKE.supabaseSecret}\n` },
    );
    const { status, out } = scan(dir);
    expect(status).toBe(1);
    expect(out).toContain('notes.txt:1: Supabase secret 키');
  });

  it('git 저장소가 아니면 실행 오류(2)로 끝난다', () => {
    const dir = mkdtempSync(join(tmpdir(), 'secret-scan-nogit-'));
    created.push(dir);
    expect(scan(dir).status).toBe(2);
  });
});
