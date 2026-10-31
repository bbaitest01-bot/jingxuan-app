import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

// ---------------------------------------------------------------------------
// 刪除帳號（業務員自己刪除自己的帳號，規劃見全景地圖 4-N）
// App 帶登入憑證與確認文字「刪除帳號」呼叫這支函式：
//   1. 用登入憑證查出是誰；只刪這個人，不接受 App 傳使用者編號
//   2. 只有業務員（agent）可以刪；管理者、開發者、示範帳號（@jingxuan.test）一律拒絕
//   3. 刪除登入帳號；資料庫設定了連帶刪除，客戶、保單、行程、拜訪紀錄等會一起刪掉
//   4. 清掉儲存空間裡這個人的檔案（大頭貼、名片 QR Code、客戶照片）
// 刪除登入帳號需要伺服器萬用金鑰（SUPABASE_SERVICE_ROLE_KEY），只放在 Supabase，App 拿不到。
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const CONFIRM_TEXT = '刪除帳號';
const DEMO_EMAIL_SUFFIX = '@jingxuan.test';
// 這兩個儲存空間的檔案都放在「使用者編號/」資料夾底下
const USER_FILE_BUCKETS = ['avatars', 'customer-photos'];
const LIST_PAGE_SIZE = 1000;

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

// 刪掉某個儲存空間裡「使用者編號/」資料夾的所有檔案；回傳刪了幾個
async function removeUserFolder(adminClient: SupabaseClient, bucket: string, userId: string): Promise<number> {
  let removedCount = 0;
  // 每次列一頁、刪一頁，直到資料夾空了為止
  while (true) {
    const { data: files, error: listError } = await adminClient.storage
      .from(bucket)
      .list(userId, { limit: LIST_PAGE_SIZE });
    if (listError) throw new Error(`列出 ${bucket} 檔案失敗：${listError.message}`);
    if (!files || files.length === 0) return removedCount;

    const filePaths: string[] = files.map((file) => `${userId}/${file.name}`);
    const { error: removeError } = await adminClient.storage.from(bucket).remove(filePaths);
    if (removeError) throw new Error(`刪除 ${bucket} 檔案失敗：${removeError.message}`);
    removedCount += filePaths.length;
  }
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return jsonResponse({ success: false, error: '只接受 POST' }, 405);

  if (!SUPABASE_SERVICE_ROLE_KEY) {
    return jsonResponse({ success: false, error: '刪除服務尚未設定，請聯絡管理員' }, 500);
  }

  // 1. 一定要是登入的人，並查出是誰
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) return jsonResponse({ success: false, error: '請先登入' }, 401);
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const accessToken = authHeader.replace('Bearer ', '');
  const { data: userData, error: userError } = await userClient.auth.getUser(accessToken);
  const user = userData?.user;
  if (userError || !user) return jsonResponse({ success: false, error: '登入已過期，請重新登入' }, 401);

  // 2. 確認文字要完全一樣，避免誤觸
  const body = await req.json().catch(() => ({}));
  if (body?.confirmText !== CONFIRM_TEXT) {
    return jsonResponse({ success: false, error: `請輸入「${CONFIRM_TEXT}」確認` }, 400);
  }

  const email = (user.email ?? '').toLowerCase();
  if (email.endsWith(DEMO_EMAIL_SUFFIX)) {
    return jsonResponse({ success: false, error: '示範帳號不能刪除' }, 403);
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: profile, error: profileError } = await adminClient
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .maybeSingle();
  if (profileError) return jsonResponse({ success: false, error: '讀取帳號資料失敗，請稍後再試' }, 500);
  const role = String(profile?.role ?? 'agent');
  if (role !== 'agent') {
    return jsonResponse({ success: false, error: '管理者與開發者帳號不能從這裡刪除' }, 403);
  }

  // 3. 先刪登入帳號；資料庫連帶刪除其餘資料（同一個交易，失敗就全部不刪）
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error('[delete-account] 刪除帳號失敗:', deleteError);
    return jsonResponse({ success: false, error: '刪除帳號失敗，資料沒有被刪除，請稍後再試' }, 500);
  }

  // 4. 再清檔案：資料夾名稱就是使用者編號，帳號刪掉後仍找得到
  // 帳號已經刪了，清檔案失敗也回報成功，只記錄下來讓管理員手動清
  let removedFileCount = 0;
  let filesCleaned = true;
  try {
    for (const bucket of USER_FILE_BUCKETS) {
      removedFileCount += await removeUserFolder(adminClient, bucket, user.id);
    }
  } catch (error) {
    filesCleaned = false;
    console.error(`[delete-account] 帳號 ${user.id} 已刪除，但清除檔案失敗:`, error);
  }

  console.log(`[delete-account] 已刪除帳號 ${user.id}，清除檔案 ${removedFileCount} 個`);
  return jsonResponse({ success: true, removedFileCount, filesCleaned }, 200);
});
