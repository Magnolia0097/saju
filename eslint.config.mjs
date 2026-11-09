// @ts-check
import js from '@eslint/js';
import nextPlugin from '@next/eslint-plugin-next';
import prettier from 'eslint-config-prettier/flat';
import reactHooks from 'eslint-plugin-react-hooks';
import { defineConfig, globalIgnores } from 'eslint/config';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default defineConfig([
  globalIgnores([
    '**/node_modules/',
    '**/.next/',
    '**/.open-next/',
    '**/.wrangler/',
    '**/dist/',
    '**/out/',
    '**/coverage/',
    'apps/web/next-env.d.ts',
    'supabase/.branches/',
    'supabase/.temp/',
  ]),

  js.configs.recommended,

  // TypeScript: 타입 정보 기반 규칙 (floating promise 등 서버 코드 실수 방지)
  {
    files: ['**/*.{ts,tsx,mts,cts}'],
    extends: [tseslint.configs.recommendedTypeChecked],
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_', caughtErrorsIgnorePattern: '^_' },
      ],
    },
  },

  // 설정 파일 · 스크립트 (Node)
  {
    files: ['**/*.{js,mjs,cjs}'],
    languageOptions: { globals: globals.node },
  },

  // 웹 앱 (Next.js + React Hooks)
  {
    files: ['apps/web/**/*.{ts,tsx}'],
    extends: [nextPlugin.configs['core-web-vitals'], reactHooks.configs.flat['recommended-latest']],
    settings: { next: { rootDir: 'apps/web/' } },
    languageOptions: { globals: globals.browser },
  },

  // 포매팅 규칙은 Prettier에 맡긴다 (항상 마지막)
  prettier,
]);
