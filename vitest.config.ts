import { defineConfig } from 'vitest/config';

// `pnpm test`는 저장소 전체 테스트를 한 번에 실행한다.
// 패키지 단독 실행은 `pnpm --filter <패키지> test` (각 패키지의 vitest.config.ts 사용).
export default defineConfig({
  test: {
    projects: [
      'packages/*',
      'apps/web',
      {
        test: {
          name: 'scripts',
          include: ['tests/scripts/**/*.test.ts'],
          environment: 'node',
        },
      },
    ],
  },
});
