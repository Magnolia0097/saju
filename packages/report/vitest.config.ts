import { defineProject } from 'vitest/config';

export default defineProject({
  test: {
    name: '@saju/report',
    include: ['src/**/*.test.ts'],
  },
});
