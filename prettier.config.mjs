/** @type {import('prettier').Config} */
export default {
  singleQuote: true,
  trailingComma: 'all',
  printWidth: 100,
  overrides: [
    {
      // GitHub Actions · pnpm 설정 등 YAML은 큰따옴표 관례를 따른다
      files: ['*.yml', '*.yaml'],
      options: { singleQuote: false },
    },
  ],
};
