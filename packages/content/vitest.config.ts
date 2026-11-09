import { defineProject } from 'vitest/config';

export default defineProject({
  test: {
    name: '@saju/content',
    include: ['src/**/*.test.ts'],
  },
});
