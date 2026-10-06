// Receives RevenueCat webhook events and keeps `profiles.plan` in sync,
// so server-side logic (the weekly chat cap, the 5-task cap, Full-tier data
// gating, nudges) has something to check without calling out to RevenueCat
// on every request. What each event means is decided in plan.ts.
//
// Setup (see README "RevenueCat webhook"):
//   - Deploy with --no-verify-jwt: RevenueCat can't send a Supabase login
//     token, so this function checks its own shared secret instead.
//   - RevenueCat > Project settings > Integrations > Webhooks: set the URL to
//     <project>/functions/v1/revenuecat-webhook and the Authorization header
//     to "Bearer <REVENUECAT_WEBHOOK_SECRET>".
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { isAccountId, planFromEvent } from './plan.ts';

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

  if (!appUserId || !eventType) {
    return new Response('Malformed payload', { status: 400 });
  }

  const plan = planFromEvent(event, Date.now());

  // app_user_id is the Supabase user id — see PurchasesService.logIn. Anonymous
  // RevenueCat ids don't belong to an account, so there is nothing to update.
  if (plan && isAccountId(appUserId)) {
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const { error } = await adminClient.from('profiles').update({ plan }).eq('id', appUserId);
    if (error) {
      // A non-2xx makes RevenueCat retry later, instead of the change being lost.
      console.error('Could not update plan', appUserId, plan, error.message);
      return new Response('Update failed', { status: 500 });
    }
  }

  console.log(`revenuecat event ${eventType} for ${appUserId}: plan ${plan ?? 'unchanged'}`);
  return new Response(JSON.stringify({ ok: true, plan }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
