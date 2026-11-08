import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

// ---------------------------------------------------------------------------
// Google 日曆通行證換新（L4 再次發生，設計見全景地圖 4-P）
// Google 給的通行證（access token）約 1 小時就過期。App 帶登入憑證呼叫這支函式：
//   1. 用登入憑證查出是誰（不接受 App 傳使用者編號）
//   2. 讀這個人存在資料庫的換證單（refresh token；App 本身讀不到）
//   3. 用 Google 金鑰跟 Google 換一張新的通行證，只把通行證回傳給 App
//   4. 換證單失效（例如使用者在 Google 帳號撤銷授權）→ 刪掉，請他重新用 Google 登入
// Google 金鑰放在函式 Secrets：GOOGLE_CLIENT_ID、GOOGLE_CLIENT_SECRET（和 Supabase 登入用的 Google 設定同一組）
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const GOOGLE_CLIENT_ID = Deno.env.get('GOOGLE_CLIENT_ID') ?? '';
const GOOGLE_CLIENT_SECRET = Deno.env.get('GOOGLE_CLIENT_SECRET') ?? '';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return jsonResponse({ error: '只接受 POST' }, 405);

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
    return jsonResponse({ error: '換證服務尚未設定（缺少 Google 金鑰），請聯絡管理員' }, 500);
  }

  try {
    // 1. 確認是誰
    const accessToken = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
    if (!accessToken) return jsonResponse({ error: '請先登入' }, 401);
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: userData, error: userError } = await adminClient.auth.getUser(accessToken);
    const userId = userData?.user?.id;
    if (userError || !userId) return jsonResponse({ error: '請先登入' }, 401);

    // 2. 讀換證單
    const { data: credential, error: readError } = await adminClient
      .from('google_calendar_credentials')
      .select('refresh_token')
      .eq('profile_id', userId)
      .maybeSingle();
    if (readError) return jsonResponse({ error: `讀取換證單失敗：${readError.message}` }, 500);
    if (!credential?.refresh_token) {
      return jsonResponse({ error: 'Google 授權已過期，請登出後再用 Google 登入一次', code: 'no_refresh_token' }, 404);
    }

    // 3. 跟 Google 換新的通行證
    const googleResponse = await fetch(GOOGLE_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: GOOGLE_CLIENT_ID,
        client_secret: GOOGLE_CLIENT_SECRET,
        refresh_token: credential.refresh_token,
        grant_type: 'refresh_token',
      }),
    });
    const googleResult = await googleResponse.json();

    if (!googleResponse.ok || !googleResult.access_token) {
      // 4. 換證單失效：刪掉，避免之後每次都白跑
      if (googleResult.error === 'invalid_grant') {
        await adminClient.from('google_calendar_credentials').delete().eq('profile_id', userId);
        return jsonResponse({ error: 'Google 授權已失效，請登出後再用 Google 登入一次', code: 'invalid_grant' }, 401);
      }
      console.error('[refresh-google-token] Google 換證失敗：', googleResult.error, googleResult.error_description);
      return jsonResponse({ error: `Google 換證失敗：${googleResult.error ?? googleResponse.status}` }, 502);
    }

    return jsonResponse({
      access_token: googleResult.access_token,
      expires_in: googleResult.expires_in ?? 3600,
    }, 200);
  } catch (error) {
    console.error('[refresh-google-token] 執行失敗：', error);
    return jsonResponse({ error: '換證服務暫時無法使用，請稍後再試' }, 500);
  }
});
