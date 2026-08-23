// Mom's chat brain. Runs server-side so the Gemini API key never
// reaches the client, and so the Basic-tier weekly message cap is a
// real limit (the client-side counter is just for instant UI feedback).
//
// Uses Google's Gemini API (free tier, no card required — see
// README.md) rather than a paid provider, so this can run without
// anyone having to add payment anywhere.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const GEMINI_MODEL = 'gemini-2.5-flash';
const BASIC_WEEKLY_MESSAGE_LIMIT = 15;

interface ChatRequestBody {
  sessionId?: string;
  message: string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return new Response('Missing Authorization header', { status: 401, headers: corsHeaders });

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return new Response('Invalid session', { status: 401, headers: corsHeaders });

  const body: ChatRequestBody = await req.json();
  if (!body.message || !body.message.trim()) {
    return new Response('message is required', { status: 400, headers: corsHeaders });
  }

  const { data: profile } = await userClient
    .from('profiles')
    .select('name, plan, goals, procrastination_areas, check_in_frequency')
    .eq('id', user.id)
    .single();

  let remainingThisWeek: number | null = null;
  if (profile?.plan === 'basic') {
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    const { count } = await userClient
      .from('chat_messages')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('from_mom', false)
      .gte('created_at', weekAgo);
    if ((count ?? 0) >= BASIC_WEEKLY_MESSAGE_LIMIT) {
      return new Response(
        JSON.stringify({ error: 'weekly_limit_reached', limit: BASIC_WEEKLY_MESSAGE_LIMIT }),
        { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
    remainingThisWeek = BASIC_WEEKLY_MESSAGE_LIMIT - (count ?? 0) - 1;
  }

  // Get-or-create the session.
  let sessionId = body.sessionId;
  if (!sessionId) {
    const { data: session, error } = await userClient
      .from('chat_sessions')
      .insert({ user_id: user.id, title: body.message.slice(0, 60) })
      .select('id')
      .single();
    if (error || !session) return new Response('Could not create session', { status: 500, headers: corsHeaders });
    sessionId = session.id;
  }

  const context = await gatherUserContext(userClient, user.id, profile?.plan ?? 'basic');
  const { data: history } = await userClient
    .from('chat_messages')
    .select('from_mom, content')
    .eq('session_id', sessionId)
    .order('created_at', { ascending: true })
    .limit(30);

  const geminiApiKey = Deno.env.get('GEMINI_API_KEY');

  let reply: string;
  if (!geminiApiKey) {
    // Test mode: no Gemini key configured yet (no account/payment
    // needed to reach this). Everything else — auth, weekly cap,
    // session/message persistence, context gathering — still runs for
    // real; only the actual AI call is skipped. Swap in a real key
    // later (`supabase secrets set GEMINI_API_KEY=...`) and this
    // branch stops firing automatically.
    reply = buildMockReply(body.message, context);
  } else {
    const systemPrompt = buildSystemPrompt(profile, context);
    // Gemini has no "assistant" role — Mom's own past turns are "model".
    const geminiContents = [
      ...(history ?? []).map((m) => ({
        role: m.from_mom ? 'model' : 'user',
        parts: [{ text: m.content }],
      })),
      { role: 'user', parts: [{ text: body.message }] },
    ];

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
      {
        method: 'POST',
        headers: {
          'x-goog-api-key': geminiApiKey,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: systemPrompt }] },
          contents: geminiContents,
          generationConfig: { maxOutputTokens: 1024 },
        }),
      },
    );

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error('Gemini API error', geminiResponse.status, errorText);
      return new Response('Mom is not answering right now.', { status: 502, headers: corsHeaders });
    }

    const geminiJson = await geminiResponse.json();
    reply = (geminiJson.candidates?.[0]?.content?.parts ?? [])
      // deno-lint-ignore no-explicit-any
      .map((part: any) => part.text ?? '')
      .join('\n')
      .trim();

    if (!reply) {
      // No usable text — most often Gemini's own safety filter blocked
      // the turn (finishReason "SAFETY"/"RECITATION" with no parts).
      console.error('Gemini returned no text', JSON.stringify(geminiJson));
      return new Response('Mom is not answering right now.', { status: 502, headers: corsHeaders });
    }
  }

  await userClient.from('chat_messages').insert([
    { session_id: sessionId, user_id: user.id, from_mom: false, content: body.message },
    { session_id: sessionId, user_id: user.id, from_mom: true, content: reply },
  ]);
  await userClient
    .from('chat_sessions')
    .update({ last_message_at: new Date().toISOString() })
    .eq('id', sessionId);

  return new Response(JSON.stringify({ sessionId, reply, remainingThisWeek }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});

async function gatherUserContext(
  // deno-lint-ignore no-explicit-any
  client: any,
  userId: string,
  plan: string,
) {
  const { data: tasks } = await client
    .from('tasks')
    .select('title, category, recurrence, streak_count')
    .eq('user_id', userId)
    .is('archived_at', null)
    .limit(20);

  const context: Record<string, unknown> = { tasks: tasks ?? [] };

  if (plan === 'full') {
    const monthStart = new Date();
    monthStart.setDate(1);
    const { data: expenses } = await client
      .from('expenses')
      .select('amount_cents, category')
      .eq('user_id', userId)
      .gte('spent_at', monthStart.toISOString().slice(0, 10));
    const { data: budgets } = await client.from('budgets').select('category, amount_cents').eq('user_id', userId);
    const { data: healthGoals } = await client
      .from('health_goals')
      .select('water_target, sleep_target_hours, workout_target_minutes')
      .eq('user_id', userId)
      .maybeSingle();
    const today = new Date().toISOString().slice(0, 10);
    const { data: healthToday } = await client
      .from('health_logs')
      .select('water_count, sleep_hours, workout_minutes')
      .eq('user_id', userId)
      .eq('log_date', today)
      .maybeSingle();

    context.expensesThisMonth = expenses ?? [];
    context.budgets = budgets ?? [];
    context.healthGoals = healthGoals ?? null;
    context.healthToday = healthToday ?? null;
  }

  return context;
}

/**
 * Placeholder reply used only when GEMINI_API_KEY isn't set (see the
 * test-mode branch above). References the real gathered context so it
 * still proves the context-gathering query worked, not just the round
 * trip — clearly labeled so nobody mistakes it for real Mom.
 */
function buildMockReply(message: string, context: Record<string, unknown>): string {
  const tasks = (context.tasks as unknown[] | undefined) ?? [];
  return `[TEST MODE — no Gemini key set, this isn't a real reply] ` +
    `I heard you say "${message.slice(0, 80)}". ` +
    `I can see ${tasks.length} task${tasks.length === 1 ? '' : 's'} on your list right now. ` +
    `Add a real GEMINI_API_KEY secret when you're ready for actual me.`;
}

// deno-lint-ignore no-explicit-any
function buildSystemPrompt(profile: any, context: Record<string, unknown>): string {
  const name = profile?.name || 'there';
  const goals = (profile?.goals ?? []).join(', ') || 'not specified yet';
  const procrastination = (profile?.procrastination_areas ?? []).join(', ') || 'not specified yet';

  return `You are the user's AI Mom inside the "AI Mom" app: caring, a little sassy, occasionally guilt-trippy, but always fundamentally on their side. Speak like a real mom texting her kid — warm, funny, direct, never a generic life coach. Keep replies conversational and fairly short.

The user's name is ${name}. Their stated goals: ${goals}. What they tend to put off: ${procrastination}.

Always ground your replies in their REAL data below rather than generic advice. Reference specific tasks, streaks, spending, or health numbers when relevant — that's what makes you feel like their actual mom and not a chatbot.

Current data (JSON): ${JSON.stringify(context)}

If the user brings up self-harm, abuse, or a genuine crisis: immediately drop the sassy persona, point them to a real crisis resource (988 Suicide & Crisis Lifeline for US users, or a relevant local equivalent if their region is apparent from context), and decline to continue that topic in character. Never joke about crisis situations.`;
}
