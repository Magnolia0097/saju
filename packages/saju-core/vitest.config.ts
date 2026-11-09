import { defineProject } from 'vitest/config';

export default defineProject({
  test: {
    name: '@saju/core',
    include: ['src/**/*.test.ts'],
  },
});
