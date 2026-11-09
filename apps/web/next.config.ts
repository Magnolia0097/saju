import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  // 워크스페이스 패키지는 빌드 없이 TypeScript 원본을 내보낸다 (exports → src/index.ts).
  transpilePackages: ['@saju/core', '@saju/content', '@saju/report'],
};

export default nextConfig;
