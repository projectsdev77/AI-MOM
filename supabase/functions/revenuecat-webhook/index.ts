// Receives RevenueCat webhook events and keeps `profiles.plan` in sync,
// so server-side logic (the weekly chat cap, Full-tier data gating) has
// something to check without calling out to RevenueCat on every request.
//
// Configure this URL under RevenueCat > Project settings > Integrations
// > Webhooks, with the shared secret below set as a custom header
// (RevenueCat calls it "Authorization").
import { createClient } from 'jsr:@supabase/supabase-js@2';

const FULL_ENTITLEMENT_ID = 'full_mom';

const ENTITLED_EVENT_TYPES = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'UNCANCELLATION',
  'PRODUCT_CHANGE',
]);
const UNENTITLED_EVENT_TYPES = new Set(['CANCELLATION', 'EXPIRATION', 'BILLING_ISSUE']);

Deno.serve(async (req) => {
  const authHeader = req.headers.get('Authorization');
  const expectedSecret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
  if (!expectedSecret || authHeader !== `Bearer ${expectedSecret}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  const payload = await req.json();
  const event = payload.event;
  const appUserId: string | undefined = event?.app_user_id;
  const eventType: string | undefined = event?.type;
  const entitlementIds: string[] = event?.entitlement_ids ?? [];

  if (!appUserId || !eventType) {
    return new Response('Malformed payload', { status: 400 });
  }

  let plan: 'full' | 'basic' | null = null;
  if (ENTITLED_EVENT_TYPES.has(eventType) && entitlementIds.includes(FULL_ENTITLEMENT_ID)) {
    plan = 'full';
  } else if (UNENTITLED_EVENT_TYPES.has(eventType)) {
    plan = 'basic';
  }

  if (plan) {
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    // app_user_id is the Supabase user id — see PurchasesService.logIn.
    await adminClient.from('profiles').update({ plan }).eq('id', appUserId);
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
