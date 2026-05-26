import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const alertCopy: Record<string, { title: string; body: (name: string) => string }> = {
  pin_enabled: {
    title: 'CIVIQ Security',
    body: (name) => `Hello ${name}, your CIVIQ app PIN has been enabled on this device.`,
  },
  pin_reset: {
    title: 'PIN reset',
    body: (name) => `Hello ${name}, your CIVIQ app PIN was reset.`,
  },
  biometrics_enabled: {
    title: 'CIVIQ Security ',
    body: (name) => `Hello ${name}, biometric unlock has been enabled on your device.`,
  },
  account_deletion_requested: {
    title: 'Account deletion requested',
    body: (name) => `Hello ${name}, your account deletion request is now in the 30-day recovery period.`,
  },
  account_deletion_cancelled: {
    title: 'Account deletion cancelled',
    body: (name) => `Hello ${name}, your account deletion request was cancelled.`,
  },
  password_reauthentication: {
    title: 'Password reauthentication',
    body: (name) => `Hello ${name}, your password was used to confirm a sensitive action.`,
  },
  data_export_requested: {
    title: 'Data export requested',
    body: (name) => `Hello ${name}, your account data export was requested.`,
  },
  new_device_session: {
    title: 'New device session',
    body: (name) => `Hello ${name}, a device session was registered for your account.`,
  },
  password_changed: {
    title: 'Password changed',
    body: (name) => `Hello ${name}, your account password was changed.`,
  },
  email_changed: {
    title: 'Email changed',
    body: (name) => `Hello ${name}, your account email was changed.`,
  },
  session_revoked: {
    title: 'Session revoked',
    body: (name) => `Hello ${name}, one of your account sessions was revoked.`,
  },
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const authHeader = req.headers.get('Authorization') ?? '';

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const admin = createClient(supabaseUrl, serviceKey);

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) return json({ error: 'Unauthorized' }, 401);

    const body = await req.json().catch(() => ({}));
    const eventType = String(body.event_type ?? '');
    const copy = alertCopy[eventType];
    if (!copy) return json({ error: 'Unsupported security event.' }, 400);

    const userId = userData.user.id;
    const { data: profile } = await admin
      .from('profiles')
      .select('username,email')
      .eq('id', userId)
      .maybeSingle();
    const name = profile?.username || profile?.email || 'there';
    const metadata = body.metadata && typeof body.metadata === 'object'
      ? body.metadata
      : {};

    const { data: eventRow, error: eventError } = await admin
      .from('security_events')
      .insert({ user_id: userId, event_type: eventType, metadata })
      .select('id')
      .single();
    if (eventError) throw eventError;

    const { error: notificationError } = await admin.from('notifications').insert({
      user_id: userId,
      title: copy.title,
      body: copy.body(name),
      category: 'security',
      is_read: false,
    });
    if (notificationError) throw notificationError;

    return json({ event_id: eventRow.id });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
