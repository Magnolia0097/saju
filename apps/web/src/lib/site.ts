/** 사이트 공통 정보. 서비스 이름은 가칭이며 브랜드가 정해지면 여기만 바꾼다. */
export const SITE = {
  name: '스낵 사주',
  description: '생년월일만 넣으면 무료로 보는 내 사주 요약. 전체 풀이는 990원.',
  locale: 'ko_KR',
} as const;

/** 브라우저 탭 제목. 페이지 제목이 없으면 사이트 이름만 쓴다. */
export function pageTitle(title?: string): string {
  const trimmed = title?.trim();
  return trimmed ? `${trimmed} · ${SITE.name}` : SITE.name;
}
