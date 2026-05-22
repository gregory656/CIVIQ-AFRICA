import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
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

    const { data: userData, error: userError } =
      await userClient.auth.getUser();
    if (userError || !userData.user) {
      return json({ error: 'Unauthorized' }, 401);
    }

    const userId = userData.user.id;
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { data: recent, error: recentError } = await admin
      .from('data_export_requests')
      .select('id, requested_at')
      .eq('user_id', userId)
      .gte('requested_at', since)
      .order('requested_at', { ascending: false })
      .limit(1);

    if (recentError) throw recentError;
    if (recent && recent.length > 0) {
      return json({ error: 'Only one export is allowed every 24 hours.' }, 429);
    }

    const { data: requestRow, error: requestError } = await admin
      .from('data_export_requests')
      .insert({ user_id: userId, status: 'pending' })
      .select('id')
      .single();
    if (requestError) throw requestError;

    const [
      profile,
      notifications,
      legalAcceptances,
      securityEvents,
      auditLogs,
      sessions,
      notificationSettings,
      posts,
    ] = await Promise.all([
      selectMaybeSingle(admin, 'profiles', userId),
      selectManySafe(admin, 'notifications', userId, 'created_at'),
      selectManySafe(admin, 'legal_acceptance_logs', userId, 'accepted_at'),
      selectManySafe(admin, 'security_events', userId, 'created_at'),
      selectManySafe(admin, 'audit_logs', userId, 'timestamp'),
      selectManySafe(admin, 'sessions', userId, 'created_at'),
      selectMaybeByUserId(admin, 'notification_settings', userId),
      selectManySafe(admin, 'posts', userId, 'created_at'),
    ]);

    const files = {
      'profile.json': JSON.stringify(profile ?? {}, null, 2),
      'notifications.json': JSON.stringify(notifications, null, 2),
      'legal_acceptance_logs.json': JSON.stringify(legalAcceptances, null, 2),
      'security_events.json': JSON.stringify(securityEvents, null, 2),
      'audit_logs.json': JSON.stringify(auditLogs, null, 2),
      'sessions.json': JSON.stringify(sessions, null, 2),
      'notification_settings.json': JSON.stringify(
        notificationSettings ?? {},
        null,
        2,
      ),
      'posts.json': JSON.stringify(posts, null, 2),
    };
    const archive = createZip(files);
    const storagePath = `${userId}/${requestRow.id}.zip`;

    const { error: uploadError } = await admin.storage
      .from('user-exports')
      .upload(storagePath, new Blob([archive], { type: 'application/zip' }), {
        contentType: 'application/zip',
        upsert: true,
      });
    if (uploadError) throw uploadError;

    const { data: signed, error: signedError } = await admin.storage
      .from('user-exports')
      .createSignedUrl(storagePath, 60 * 60);
    if (signedError) throw signedError;

    await admin
      .from('data_export_requests')
      .update({
        storage_path: storagePath,
        completed_at: new Date().toISOString(),
        expires_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        status: 'completed',
      })
      .eq('id', requestRow.id);

    await admin.from('security_events').insert({
      user_id: userId,
      event_type: 'data_export_requested',
      metadata: { request_id: requestRow.id },
    });

    await admin.from('notifications').insert({
      user_id: userId,
      title: 'Data export requested',
      body: 'Your CIVIQ Africa data export is ready. The download link expires in 1 hour.',
      category: 'security',
      is_read: false,
    });

    return json({ download_url: signed.signedUrl });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});

async function selectMaybeSingle(admin: any, table: string, userId: string) {
  const { data, error } = await admin.from(table).select('*').eq('id', userId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function selectMaybeByUserId(admin: any, table: string, userId: string) {
  const { data, error } = await admin.from(table).select('*').eq(
    'user_id',
    userId,
  ).maybeSingle();
  if (isMissingTable(error)) return null;
  if (error) throw error;
  return data;
}

async function selectManySafe(
  admin: any,
  table: string,
  userId: string,
  orderColumn: string,
) {
  const ordered = await admin.from(table).select('*').eq(
    'user_id',
    userId,
  ).order(orderColumn, { ascending: false });
  if (!ordered.error) return ordered.data ?? [];
  if (isMissingTable(ordered.error)) return [];

  const fallback = await admin.from(table).select('*').eq('user_id', userId);
  if (isMissingTable(fallback.error)) return [];
  if (fallback.error) throw fallback.error;
  return fallback.data ?? [];
}

function isMissingTable(error: any) {
  if (!error) return false;
  return error.code === '42P01' || String(error.message).includes('does not exist');
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function createZip(files: Record<string, string>) {
  const encoder = new TextEncoder();
  const localParts: Uint8Array[] = [];
  const centralParts: Uint8Array[] = [];
  let offset = 0;

  for (const [name, content] of Object.entries(files)) {
    const nameBytes = encoder.encode(name);
    const contentBytes = encoder.encode(content);
    const crc = crc32(contentBytes);
    const local = localHeader(nameBytes, contentBytes.length, crc);
    localParts.push(local, nameBytes, contentBytes);
    centralParts.push(
      centralHeader(nameBytes, contentBytes.length, crc, offset),
    );
    offset += local.length + nameBytes.length + contentBytes.length;
  }

  const centralSize = centralParts.reduce((sum, part) => sum + part.length, 0);
  const end = endRecord(Object.keys(files).length, centralSize, offset);
  return concat([...localParts, ...centralParts, end]);
}

function localHeader(name: Uint8Array, size: number, crc: number) {
  const header = new Uint8Array(30);
  const view = new DataView(header.buffer);
  view.setUint32(0, 0x04034b50, true);
  view.setUint16(4, 20, true);
  view.setUint32(14, crc, true);
  view.setUint32(18, size, true);
  view.setUint32(22, size, true);
  view.setUint16(26, name.length, true);
  return header;
}

function centralHeader(
  name: Uint8Array,
  size: number,
  crc: number,
  offset: number,
) {
  const header = new Uint8Array(46 + name.length);
  const view = new DataView(header.buffer);
  view.setUint32(0, 0x02014b50, true);
  view.setUint16(4, 20, true);
  view.setUint16(6, 20, true);
  view.setUint32(16, crc, true);
  view.setUint32(20, size, true);
  view.setUint32(24, size, true);
  view.setUint16(28, name.length, true);
  view.setUint32(42, offset, true);
  header.set(name, 46);
  return header;
}

function endRecord(count: number, centralSize: number, centralOffset: number) {
  const header = new Uint8Array(22);
  const view = new DataView(header.buffer);
  view.setUint32(0, 0x06054b50, true);
  view.setUint16(8, count, true);
  view.setUint16(10, count, true);
  view.setUint32(12, centralSize, true);
  view.setUint32(16, centralOffset, true);
  return header;
}

function concat(parts: Uint8Array[]) {
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const output = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

function crc32(bytes: Uint8Array) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}
