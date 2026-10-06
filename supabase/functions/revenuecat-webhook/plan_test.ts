import { isAccountId, planFromEvent } from './plan.ts';

function eq<T>(actual: T, expected: T, name: string) {
  if (actual !== expected) throw new Error(`${name}: expected ${expected}, got ${actual}`);
}

const now = Date.parse('2026-10-10T12:00:00Z');
const future = now + 20 * 24 * 3600 * 1000;
const past = now - 3600 * 1000;
const full = ['full_mom'];

Deno.test('buying or renewing gives Full', () => {
  for (const type of ['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE', 'SUBSCRIPTION_EXTENDED']) {
    eq(planFromEvent({ type, entitlement_ids: full }, now), 'full', type);
  }
});

Deno.test('a purchase of something else does not give Full', () => {
  eq(planFromEvent({ type: 'INITIAL_PURCHASE', entitlement_ids: ['other'] }, now), null, 'other');
  eq(planFromEvent({ type: 'INITIAL_PURCHASE', entitlement_ids: null }, now), null, 'null');
});

Deno.test('turning off auto-renew keeps Full until the paid time ends', () => {
  eq(planFromEvent({ type: 'CANCELLATION', expiration_at_ms: future }, now), null, 'cancel mid-period');
});

Deno.test('a cancellation that is already past its end (refund) removes Full', () => {
  eq(planFromEvent({ type: 'CANCELLATION', expiration_at_ms: past }, now), 'basic', 'refund');
});

Deno.test('a payment problem inside the grace period keeps Full', () => {
  eq(planFromEvent({ type: 'BILLING_ISSUE', expiration_at_ms: future }, now), null, 'grace');
  eq(planFromEvent({ type: 'BILLING_ISSUE', expiration_at_ms: past }, now), 'basic', 'after grace');
});

Deno.test('expiry removes Full', () => {
  eq(planFromEvent({ type: 'EXPIRATION' }, now), 'basic', 'expiration');
});

Deno.test('test pings and unknown events change nothing', () => {
  eq(planFromEvent({ type: 'TEST' }, now), null, 'test');
  eq(planFromEvent({}, now), null, 'empty');
  eq(planFromEvent({ type: 'CANCELLATION' }, now), null, 'cancel without a date');
});

Deno.test('only real account ids are updated', () => {
  eq(isAccountId('0b9a4d3e-7c61-4f0a-9d52-1a2b3c4d5e6f'), true, 'uuid');
  eq(isAccountId('$RCAnonymousID:abc123'), false, 'anonymous');
  eq(isAccountId(''), false, 'empty');
});
