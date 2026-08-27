// Mom's proactive nudge: called hourly by pg_cron (see
// migrations/0009_nudge_scheduling.sql and 0010_nudge_frequency.sql),
// never by the app directly. Finds everyone due for a nudge
// (users_to_nudge, in that second migration — it honors each user's
// own check_in_frequency from onboarding), sends each a push via
// Firebase Cloud Messaging's HTTP v1 API, and stamps
// profiles.last_nudged_at so they aren't nudged again too soon.
//
// FCM v1 needs an OAuth2 access token minted from a Firebase service
// account — there's no simple static server key anymore (Google
// retired that). This signs the JWT assertion itself with the Web
// Crypto API rather than pulling in a Node-oriented auth library,
// since Deno edge functions don't have one readily available.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

const NUDGE_LINES = [
  "Still a couple of things on your list today — I know you've got this.",
  "Just checking in — anything on today's list you want to knock out now?",
  'No pressure, just a nudge: today’s list is still waiting for you.',
];

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return crypto.subtle.importKey(
    'pkcs8',
    bytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

async function getAccessToken(account: ServiceAccount): Promise<string> {
  const encoder = new TextEncoder();
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = base64UrlEncode(
    encoder.encode(
      JSON.stringify({
        iss: account.client_email,
        scope: FCM_SCOPE,
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
      }),
    ),
  );
  const signingInput = `${header}.${claims}`;
  const key = await importPrivateKey(account.private_key);
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    encoder.encode(signingInput),
  );
  const jwt = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`Firebase token exchange failed: ${await res.text()}`);
  const data = await res.json();
  return data.access_token as string;
}

async function sendPush(accessToken: string, projectId: string, token: string, body: string): Promise<boolean> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: { token, notification: { title: 'Mom', body } } }),
  });
  return res.ok;
}

Deno.serve(async (req) => {
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  if (req.headers.get('Authorization') !== `Bearer ${serviceRoleKey}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!serviceAccountJson) {
    // Firebase isn't set up yet — nothing to send, but this isn't an
    // error worth alarming a cron job's logs over every two hours.
    return new Response(JSON.stringify({ sent: 0, reason: 'firebase_not_configured' }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }
  const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, serviceRoleKey);
  const { data: candidates, error } = await supabase.rpc('users_to_nudge');
  if (error) return new Response(`Query failed: ${error.message}`, { status: 500 });
  if (!candidates || candidates.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { headers: { 'Content-Type': 'application/json' } });
  }

  const accessToken = await getAccessToken(serviceAccount);

  let sent = 0;
  const nudgedIds: string[] = [];
  for (const candidate of candidates as { user_id: string; fcm_token: string; name: string }[]) {
    const line = NUDGE_LINES[Math.floor(Math.random() * NUDGE_LINES.length)];
    const ok = await sendPush(accessToken, serviceAccount.project_id, candidate.fcm_token, line);
    if (ok) {
      sent++;
      nudgedIds.push(candidate.user_id);
    }
  }

  if (nudgedIds.length > 0) {
    await supabase.from('profiles').update({ last_nudged_at: new Date().toISOString() }).in('id', nudgedIds);
  }

  return new Response(JSON.stringify({ sent, candidates: candidates.length }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
