import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';

import { SITE, pageTitle } from '@/lib/site';

import './globals.css';

export const metadata: Metadata = {
  title: pageTitle(),
  description: SITE.description,
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
