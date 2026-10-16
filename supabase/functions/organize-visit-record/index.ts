import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

// ---------------------------------------------------------------------------
// 拜訪紀錄 AI 整理（第 4 階段 4-E1，問題 R2、R8、R11）
// App 只帶「紀錄編號」呼叫這支函式：
//   1. 用登入者本人的身分讀這篇（資料庫權限保證只能讀自己的）
//   2. 狀態改成「整理中」，立刻回覆 App
//   3. 在背景呼叫 n8n（附 Header Secret），等它回傳整理後的文字
//   4. 成功：寫入 organized_content、狀態「完成」；失敗或逾時：狀態「失敗」並寫原因
// n8n 的網址與密碼只放在 Supabase Secrets（N8N_VISIT_WEBHOOK_URL、N8N_VISIT_SECRET），App 拿不到。
// 不使用伺服器萬用金鑰：讀寫都用登入者的身分，別人的紀錄一律碰不到。
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const N8N_VISIT_WEBHOOK_URL = Deno.env.get('N8N_VISIT_WEBHOOK_URL') ?? '';
const N8N_VISIT_SECRET = Deno.env.get('N8N_VISIT_SECRET') ?? '';

// 等 n8n 最多 60 秒；超過就當作失敗，使用者可以按「重新整理」
const N8N_TIMEOUT_MS = 60000;
const MAX_CONTENT_LENGTH = 20000;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Supabase 雲端函式提供的「回覆後繼續在背景工作」；本機測試環境可能沒有
declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function looksLikeUuid(text: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(text);
}

// 寫入失敗狀態與原因（原因最多 500 字，資料庫有限制）
async function markFailed(supabase: SupabaseClient, recordId: string, reason: string): Promise<void> {
  const { error } = await supabase
    .from('visit_records')
    .update({ status: 'failed', failure_reason: reason.slice(0, 500) })
    .eq('id', recordId);
  if (error) console.error('[organize-visit-record] 寫入失敗狀態失敗:', error);
}

// 呼叫 n8n 並把結果寫回
async function organizeRecord(supabase: SupabaseClient, recordId: string, rawText: string): Promise<void> {
  try {
    const response = await fetch(N8N_VISIT_WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-visit-secret': N8N_VISIT_SECRET },
      body: JSON.stringify({ raw_text: rawText }),
      signal: AbortSignal.timeout(N8N_TIMEOUT_MS),
    });

    if (!response.ok) {
      await markFailed(supabase, recordId, `整理服務回應錯誤（${response.status}）`);
      return;
    }

    const result = await response.json().catch(() => null);
    const refinedText = typeof result?.data?.refined_text === 'string' ? result.data.refined_text.trim() : '';
    if (result?.status !== 'success' || refinedText.length === 0) {
      const message = typeof result?.message === 'string' ? result.message : '整理結果是空的或格式不正確';
      await markFailed(supabase, recordId, message);
      return;
    }

    const { error } = await supabase
      .from('visit_records')
      .update({
        organized_content: refinedText.slice(0, MAX_CONTENT_LENGTH),
        status: 'done',
        failure_reason: null,
      })
      .eq('id', recordId);
    if (error) {
      console.error('[organize-visit-record] 寫回整理結果失敗:', error);
      await markFailed(supabase, recordId, '整理完成但存檔失敗，請重新整理');
    }
  } catch (err) {
    const isTimeout = err instanceof DOMException && err.name === 'TimeoutError';
    const reason = isTimeout ? '整理逾時（超過 60 秒沒有回應）' : '連不上整理服務';
    console.error('[organize-visit-record] 呼叫 n8n 失敗:', err);
    await markFailed(supabase, recordId, reason);
  }
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return jsonResponse({ success: false, message: '只接受 POST' }, 405);

  if (!N8N_VISIT_WEBHOOK_URL || !N8N_VISIT_SECRET) {
    return jsonResponse({ success: false, message: '整理服務尚未設定（缺少 Secrets）' }, 500);
  }

  // 1. 一定要是登入的人
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) return jsonResponse({ success: false, message: '請先登入' }, 401);
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  // 伺服器上沒有登入狀態，要把使用者的登入憑證傳進去才查得到是誰
  const accessToken = authHeader.replace('Bearer ', '');
  const { data: userData, error: userError } = await supabase.auth.getUser(accessToken);
  const userId = userData?.user?.id;
  if (userError || !userId) return jsonResponse({ success: false, message: '登入已過期，請重新登入' }, 401);

  // 2. 讀這篇（只能讀自己的、不在垃圾桶的）
  const body = await req.json().catch(() => ({}));
  const recordId = typeof body?.recordId === 'string' ? body.recordId : '';
  if (!looksLikeUuid(recordId)) return jsonResponse({ success: false, message: '紀錄編號不正確' }, 400);

  const { data: record, error: readError } = await supabase
    .from('visit_records')
    .select('id, raw_transcript, deleted_at')
    .eq('id', recordId)
    .eq('profile_id', userId)
    .maybeSingle();
  if (readError) return jsonResponse({ success: false, message: '讀取紀錄失敗' }, 500);
  if (!record || record.deleted_at) return jsonResponse({ success: false, message: '找不到這篇紀錄' }, 404);

  const rawText = String(record.raw_transcript ?? '').trim();
  if (rawText.length === 0) {
    await markFailed(supabase, recordId, '原始轉錄是空的，沒有內容可以整理');
    return jsonResponse({ success: false, message: '原始轉錄是空的' }, 400);
  }

  // 3. 狀態改成「整理中」
  const { error: updateError } = await supabase
    .from('visit_records')
    .update({ status: 'processing', processing_started_at: new Date().toISOString(), failure_reason: null })
    .eq('id', recordId);
  if (updateError) return jsonResponse({ success: false, message: '無法開始整理' }, 500);

  // 4. 背景整理：先回覆 App，使用者關掉網頁也會繼續
  const work = organizeRecord(supabase, recordId, rawText);
  if (typeof EdgeRuntime !== 'undefined') {
    EdgeRuntime.waitUntil(work);
  } else {
    await work;
  }
  return jsonResponse({ success: true, status: 'processing' }, 202);
});
