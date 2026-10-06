import { isQuietHour, localTime } from './topics.ts';

function eq<T>(actual: T, expected: T, name: string) {
  if (actual !== expected) throw new Error(`${name}: expected ${expected}, got ${actual}`);
}

// 2026-10-10 at the given UTC time.
const at = (utcHour: number, utcMinute = 0) => new Date(Date.UTC(2026, 9, 10, utcHour, utcMinute));
const quiet = (utcHour: number, utcMinute: number, zone: string | null) => isQuietHour(localTime(at(utcHour, utcMinute), zone));

Deno.test('Addis Ababa (UTC+3): quiet from 22:00 until 07:00 local', () => {
  const zone = 'Africa/Addis_Ababa';
  eq(quiet(18, 59, zone), false, '21:59');
  eq(quiet(19, 0, zone), true, '22:00');
  eq(quiet(21, 0, zone), true, '00:00');
  eq(quiet(0, 0, zone), true, '03:00');
  eq(quiet(3, 59, zone), true, '06:59');
  eq(quiet(4, 0, zone), false, '07:00');
  eq(quiet(9, 0, zone), false, '12:00');
});

Deno.test('New York (UTC-4 in October): follows their own clock, not UTC', () => {
  const zone = 'America/New_York';
  eq(quiet(2, 0, zone), true, '22:00 the evening before');
  eq(quiet(10, 59, zone), true, '06:59');
  eq(quiet(11, 0, zone), false, '07:00');
  eq(quiet(23, 0, zone), false, '19:00');
});

Deno.test('the same moment is night for one person and day for another', () => {
  eq(quiet(3, 0, 'Africa/Addis_Ababa'), true, '06:00 in Addis');
  eq(quiet(3, 0, 'Asia/Tokyo'), false, '12:00 in Tokyo');
});

Deno.test('unknown or unrecognised timezone: no quiet hours (a UTC guess could silence their morning)', () => {
  eq(quiet(3, 0, null), false, 'null');
  eq(quiet(3, 0, ''), false, 'empty');
  eq(quiet(3, 0, 'Not/AZone'), false, 'invalid');
  eq(localTime(at(3), null).known, false, 'known flag');
  eq(localTime(at(3), 'Africa/Addis_Ababa').known, true, 'known flag');
});
