import { describe, expect, it } from 'vitest';

import { PACKAGE_NAME } from './index';

describe('@saju/content', () => {
  it('패키지 이름을 내보낸다', () => {
    expect(PACKAGE_NAME).toBe('@saju/content');
  });
});
