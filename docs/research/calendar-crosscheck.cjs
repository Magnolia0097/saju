// 만세력 계산 방식 사전 검증 스크립트 (2026-11-09 실행, 결과는 calendar-crosscheck.md)
// 실행: packages/saju-core에 의존성 설치 후
//   node docs/research/calendar-crosscheck.cjs
// 필요 패키지: astronomy-engine, korean-lunar-calendar, lunar-javascript, luxon
const Astronomy = require('astronomy-engine');
const { Solar } = require('lunar-javascript');
const KoreanLunarCalendar = require('korean-lunar-calendar');
const { DateTime } = require('luxon');

// 1) tzdata: Asia/Seoul 과거 오프셋 → 보정 시각(UTC + 8:30)
const tzCases = [
  [1988, 7, 15, 14, 20, '1988 서머타임'],
  [1987, 7, 1, 12, 0, '1987 서머타임'],
  [1988, 11, 1, 12, 0, '1988 서머타임 종료 후'],
  [1960, 1, 15, 12, 0, '1954~61 표준시'],
  [1957, 7, 15, 12, 0, '1955~60 서머타임'],
  [1950, 7, 1, 12, 0, '1948~51 서머타임'],
  [1965, 7, 1, 12, 0, '평시'],
  [2026, 11, 9, 12, 0, '현재'],
];
console.log('== tzdata Asia/Seoul ==');
for (const [y, m, d, h, mi, label] of tzCases) {
  const dt = DateTime.fromObject({ year: y, month: m, day: d, hour: h, minute: mi }, { zone: 'Asia/Seoul' });
  const corrected = dt.toUTC().plus({ minutes: 510 });
  console.log(`${label}: offset=${dt.offset}분, 보정 시각=${corrected.toFormat('HH:mm')}`);
}

// 2) 12절 절입 시각: astronomy-engine(태양 황경) vs lunar-javascript(UTC+8 표)
const JIE = [[315, '立春'], [345, '惊蛰'], [15, '清明'], [45, '立夏'], [75, '芒种'], [105, '小暑'],
  [135, '立秋'], [165, '白露'], [195, '寒露'], [225, '立冬'], [255, '大雪'], [285, '小寒']];
function astroTime(year, lon) {
  const approxDay = ((lon - 280 + 360) % 360) / 360 * 365.2422;
  const start = new Date(Date.UTC(year, 0, 1) + (approxDay - 12) * 86400000);
  return Astronomy.SearchSunLongitude(lon, start, 30).date;
}
let maxDiff = 0, n = 0;
for (let year = 1900; year <= 2100; year++) {
  const table = Solar.fromYmd(year, 6, 1).getLunar().getJieQiTable();
  for (const [lon, han] of JIE) {
    const s = table[han];
    if (!s || s.getYear() !== year) continue;
    const ljUtc = Date.UTC(s.getYear(), s.getMonth() - 1, s.getDay(), s.getHour(), s.getMinute(), s.getSecond()) - 8 * 3600000;
    maxDiff = Math.max(maxDiff, Math.abs(astroTime(year, lon).getTime() - ljUtc) / 60000);
    n++;
  }
}
console.log(`\n== 12절 절입 (1900~2100, ${n}건) == 최대 차이 ${maxDiff.toFixed(2)}분`);

// 3) 일진 산술식: (JDN + 49) mod 60, 0 = 甲子
const STEMS = '甲乙丙丁戊己庚辛壬癸', BRANCHES = '子丑寅卯辰巳午未申酉戌亥';
function jdn(y, m, d) {
  const a = Math.floor((14 - m) / 12), yy = y + 4800 - a, mm = m + 12 * a - 3;
  return d + Math.floor((153 * mm + 2) / 5) + 365 * yy + Math.floor(yy / 4) - Math.floor(yy / 100) + Math.floor(yy / 400) - 32045;
}
const klc = new KoreanLunarCalendar();
let badLj = 0, badKr = 0, days = 0;
for (let t = Date.UTC(1900, 0, 1); t <= Date.UTC(2100, 11, 31); t += 86400000) {
  const d = new Date(t), y = d.getUTCFullYear(), m = d.getUTCMonth() + 1, dd = d.getUTCDate();
  const i = ((jdn(y, m, dd) + 49) % 60 + 60) % 60;
  const gz = STEMS[i % 10] + BRANCHES[i % 12];
  if (gz !== Solar.fromYmd(y, m, dd).getLunar().getDayInGanZhi()) badLj++;
  if (y <= 2049) { klc.setSolarDate(y, m, dd); if (klc.getChineseGapja().day.replace('日', '') !== gz) badKr++; }
  days++;
}
console.log(`\n== 일진 (1900~2100, ${days}일) == lunar-javascript 불일치 ${badLj}, korean-lunar-calendar(~2049) 불일치 ${badKr}`);

// 4) 한국·중국 음력 날짜 차이 (1950~2049)
let lunarDiff = 0;
for (let t = Date.UTC(1950, 0, 1); t <= Date.UTC(2049, 11, 31); t += 86400000) {
  const d = new Date(t), y = d.getUTCFullYear(), m = d.getUTCMonth() + 1, dd = d.getUTCDate();
  klc.setSolarDate(y, m, dd);
  const kr = klc.getLunarCalendar();
  const cn = Solar.fromYmd(y, m, dd).getLunar();
  if (kr.year !== cn.getYear() || kr.month !== Math.abs(cn.getMonth()) || kr.day !== cn.getDay() || !!kr.intercalation !== (cn.getMonth() < 0)) lunarDiff++;
}
console.log(`\n== 한·중 음력 날짜 차이 (1950~2049) == ${lunarDiff}일`);
