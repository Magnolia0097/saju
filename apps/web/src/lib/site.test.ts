import { describe, expect, it } from 'vitest';

import { SITE, pageTitle } from '@/lib/site';

describe('pageTitle', () => {
  it('제목이 없으면 사이트 이름만 쓴다', () => {
    expect(pageTitle()).toBe(SITE.name);
    expect(pageTitle('   ')).toBe(SITE.name);
  });

  it('페이지 제목 뒤에 사이트 이름을 붙인다', () => {
    expect(pageTitle('무료 사주')).toBe(`무료 사주 · ${SITE.name}`);
  });
});
