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

// ---- their own quiet hours ----
import { quietHoursOf } from './topics.ts';

const addis = 'Africa/Addis_Ababa'; // UTC+3
const addisHour = (localHour: number) => localTime(at((localHour + 21) % 24), addis);
const within = (localHour: number, q: { enabled?: boolean; from: number; until: number }) =>
  isQuietHour(addisHour(localHour), { enabled: q.enabled ?? true, from: q.from, until: q.until });

Deno.test('a window that crosses midnight (23 to 6)', () => {
  const q = { from: 23, until: 6 };
  eq(within(22, q), false, '22:00 is awake now');
  eq(within(23, q), true, '23:00');
  eq(within(2, q), true, '02:00');
  eq(within(5, q), true, '05:00');
  eq(within(6, q), false, '06:00 awake');
  eq(within(7, q), false, '07:00 awake (the old default no longer applies)');
});

Deno.test('a window inside one day (13 to 15, a nap)', () => {
  const q = { from: 13, until: 15 };
  eq(within(12, q), false, '12:00');
  eq(within(13, q), true, '13:00');
  eq(within(14, q), true, '14:00');
  eq(within(15, q), false, '15:00');
  eq(within(3, q), false, '03:00 is not quiet any more');
});

Deno.test('switched off, or start equal to end, means never quiet', () => {
  for (let h = 0; h < 24; h++) {
    eq(within(h, { enabled: false, from: 22, until: 7 }), false, `off at ${h}`);
    eq(within(h, { from: 9, until: 9 }), false, `same hour at ${h}`);
  }
});

Deno.test('unset values fall back to 22 to 7 and bad values are ignored', () => {
  const d = quietHoursOf({});
  eq(d.enabled, true, 'enabled');
  eq(d.from, 22, 'from');
  eq(d.until, 7, 'until');
  const bad = quietHoursOf({ quiet_hours_enabled: null, quiet_from_hour: 25, quiet_until_hour: -1 });
  eq(bad.from, 22, 'from out of range');
  eq(bad.until, 7, 'until out of range');
  const mine = quietHoursOf({ quiet_hours_enabled: false, quiet_from_hour: 0, quiet_until_hour: 5 });
  eq(mine.enabled, false, 'their own off');
  eq(mine.from, 0, 'their from of midnight is kept (0 is a valid hour)');
  eq(mine.until, 5, 'their until');
});

Deno.test('their own window still needs a known timezone', () => {
  eq(isQuietHour(localTime(at(3), null), { enabled: true, from: 0, until: 23 }), false, 'unknown timezone');
});
