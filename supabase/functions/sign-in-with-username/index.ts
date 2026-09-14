import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const allowedOrigins = new Set(['https://siviq.top', 'https://www.siviq.top']);

function corsHeaders(req: Request) {
  const origin = req.headers.get('origin') ?? '';
  return {
    'Access-Control-Allow-Origin': allowedOrigins.has(origin) ? origin : 'https://siviq.top',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    Vary: 'Origin',
  };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req) });
  if (req.method !== 'POST') return json(req, { error: 'Method not allowed' }, 405);
  try {
    const { username, password } = await req.json();
    if (typeof username !== 'string' || typeof password !== 'string') return invalidLogin(req);
    const url = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin = createClient(url, serviceKey);
    const { data: profile } = await admin.from('profiles').select('email').ilike('username', username.trim()).maybeSingle();
    if (!profile?.email) return invalidLogin(req);
    const auth = createClient(url, anonKey);
    const { data, error } = await auth.auth.signInWithPassword({ email: profile.email, password });
    if (error || !data.session) return invalidLogin(req);
    return json(req, { session: data.session });
  } catch (_) { return invalidLogin(req); }
});

function invalidLogin(req: Request) { return json(req, { error: 'Invalid username or password.' }, 400); }
function json(req: Request, body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { headers: { ...corsHeaders(req), 'Content-Type': 'application/json' }, status });
}
