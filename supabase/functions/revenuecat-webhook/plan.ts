// Decides, from one RevenueCat webhook event, what `profiles.plan` should
// become. Kept apart from index.ts so it can be tested without a server.

export const FULL_ENTITLEMENT_ID = 'full_mom';

const ENTITLED_EVENT_TYPES = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'UNCANCELLATION',
  'PRODUCT_CHANGE',
  'SUBSCRIPTION_EXTENDED',
]);

// Events that mean "something went wrong or was switched off" — these only
// take the Full plan away if the paid time has actually run out. A
// CANCELLATION usually just means auto-renew was turned off: the user paid
// for the period and keeps Full until it ends, when EXPIRATION arrives.
const MAYBE_ENDED_EVENT_TYPES = new Set(['CANCELLATION', 'BILLING_ISSUE']);

export interface RevenueCatEvent {
  type?: string;
  app_user_id?: string;
  entitlement_ids?: string[] | null;
  expiration_at_ms?: number | null;
}

/** 'full' / 'basic' to write, or null to leave the plan alone. */
export function planFromEvent(event: RevenueCatEvent, nowMs: number): 'full' | 'basic' | null {
  const type = event.type;
  if (!type) return null;

  if (ENTITLED_EVENT_TYPES.has(type)) {
    return (event.entitlement_ids ?? []).includes(FULL_ENTITLEMENT_ID) ? 'full' : null;
  }
  if (type === 'EXPIRATION') return 'basic';
  if (MAYBE_ENDED_EVENT_TYPES.has(type)) {
    const expires = event.expiration_at_ms;
    return typeof expires === 'number' && expires <= nowMs ? 'basic' : null;
  }
  return null;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** RevenueCat also reports anonymous ids ("$RCAnonymousID:…"); those are not accounts here. */
export const isAccountId = (id: string): boolean => UUID.test(id);
