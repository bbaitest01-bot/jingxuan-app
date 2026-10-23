// ============================================================================
// 掃描保單（第 5 階段 E：D6、D7；設計見全景地圖 4-J）
//
// 流程分兩段，之後升級 ③ 版（手機端 OCR 刪個資、只送文字）時只換第一段：
//   第一段「取得內容」：現在收保單照片（base64），之後可改收 OCR 文字
//   第二段「整理成欄位」：請 AI 只回傳商品欄位，再用白名單把其他東西全部丟掉
//
// 隱私（④ 版，2026-10-24 沛沛確認）：
//   - 照片只在這次請求的記憶體裡，不存檔、不寫資料庫、不寫 log
//   - 使用 GROQ_SCAN_API_KEY（帳號已開啟 Inference APIs 零資料保留，Groq 不保存輸入輸出）
//   - 回傳內容只有商品欄位，不含要保人、被保險人、身分證字號、地址、電話
// 這個函式不寫資料庫：業務員在確認畫面修正後，由 app 依 RLS 寫入 customer_policies
// ============================================================================
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const GROQ_SCAN_API_KEY = Deno.env.get('GROQ_SCAN_API_KEY') ?? '';
const GROQ_SCAN_MODEL = Deno.env.get('GROQ_SCAN_MODEL') ?? 'qwen/qwen3.8-27b';

// Groq 一次最多 3 張圖；base64 總長度上限約 4MB（app 端會先縮圖）
const MAXIMUM_IMAGE_COUNT = 3;
const MAXIMUM_TOTAL_BASE64_LENGTH = 4_000_000;
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

interface PolicyImage {
  base64: string;
  mimeType: string;
}

interface ScannedItem {
  product_name: string;
  coverage_role: 'main' | 'rider' | null;
  plan_or_amount: string | null;
  premium: number | null;
}

interface ScanResult {
  company_name: string | null;
  policy_number: string | null;
  effective_date: string | null;
  items: ScannedItem[];
}

// 給 AI 的指示：只要商品欄位，明確禁止回傳個資
const EXTRACTION_PROMPT = `你是台灣保險保單的資料整理助手。請閱讀保單影像，只回傳下列 JSON，不要有其他文字：
{
  "company_name": "保險公司全名，例如 國泰人壽保險股份有限公司；看不到填 null",
  "policy_number": "保單號碼或契約號碼；看不到填 null",
  "effective_date": "契約生效日，一律換成西元 YYYY-MM-DD（民國年加 1911）；看不到填 null",
  "items": [
    {
      "product_name": "商品完整名稱，照保單上的字抄寫，不要簡化",
      "coverage_role": "主約填 main，附約或附加契約填 rider，看不出來填 null",
      "plan_or_amount": "計畫別或保險金額，照保單上的字抄寫，例如 計畫三、50 萬元；沒有填 null",
      "premium": 保費數字（整數，新臺幣元，去掉逗號與單位；沒有填 null）
    }
  ]
}
規則：
1. 保單上每一個商品（主約、附約）都要列成 items 裡的一筆，順序照保單。
2. 絕對不要回傳要保人、被保險人、受益人姓名、身分證字號、出生日期、地址、電話、帳號等個人資料。
3. 不要回傳合計保費；看不清楚的欄位填 null，不要猜。
4. 全部使用繁體中文。`;

// ---------------------------------------------------------------------------
// 第一段：檢查並整理照片
// ---------------------------------------------------------------------------
function readImages(rawImages: unknown): { images: PolicyImage[]; error?: string } {
  if (!Array.isArray(rawImages) || rawImages.length === 0) {
    return { images: [], error: '沒有收到保單照片' };
  }
  if (rawImages.length > MAXIMUM_IMAGE_COUNT) {
    return { images: [], error: `一次最多 ${MAXIMUM_IMAGE_COUNT} 張照片` };
  }

  const images: PolicyImage[] = [];
  let totalLength = 0;
  for (const rawImage of rawImages) {
    const base64 = typeof rawImage?.base64 === 'string' ? rawImage.base64 : '';
    const mimeType = typeof rawImage?.mimeType === 'string' ? rawImage.mimeType : '';
    if (!base64 || !ALLOWED_IMAGE_TYPES.includes(mimeType)) {
      return { images: [], error: '照片格式不支援，請用 JPG 或 PNG' };
    }
    totalLength += base64.length;
    images.push({ base64, mimeType });
  }
  if (totalLength > MAXIMUM_TOTAL_BASE64_LENGTH) {
    return { images: [], error: '照片太大，請少拍幾張或重新拍攝' };
  }
  return { images };
}

// ---------------------------------------------------------------------------
// 第二段：請 AI 整理成欄位
// ---------------------------------------------------------------------------
async function callGroqVision(images: PolicyImage[], useJsonMode: boolean): Promise<Response> {
  const content: unknown[] = [{ type: 'text', text: EXTRACTION_PROMPT }];
  for (const image of images) {
    content.push({
      type: 'image_url',
      image_url: { url: `data:${image.mimeType};base64,${image.base64}` },
    });
  }

  // 2026-10-24 Logs 查到失敗原因是 429：免費方案「每分鐘輸出 token（OTPM）」上限只有 1000，
  // Groq 會先用 max_completion_tokens 預留額度，預留超過 1000 就直接拒絕。
  //   reasoning_effort 'none'：照抄保單不需要 AI 先「思考」，關掉可省下大量 token，也比較快
  //   max_completion_tokens 600：一份保單的 JSON 約 200～400 token，600 夠用又不會超過上限
  const requestBody: Record<string, unknown> = {
    model: GROQ_SCAN_MODEL,
    temperature: 0.1,
    reasoning_effort: 'none',
    max_completion_tokens: 600,
    messages: [{ role: 'user', content }],
  };
  if (useJsonMode) {
    requestBody.response_format = { type: 'json_object' };
  }

  return await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${GROQ_SCAN_API_KEY.trim()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody),
  });
}

// 最多試 3 次：第 1 次用 JSON 模式；失敗（Groq 忙碌、JSON 格式檢查沒過、回傳看不懂）就換一般模式再試
// 2026-10-24 沛沛實測：第一次常失敗、第二次就成功，展示時不能讓業務員看到錯誤，所以在這裡自動重試
const MAXIMUM_ATTEMPTS = 3;

async function extractFieldsWithAi(images: PolicyImage[]): Promise<{ result?: ScanResult; error?: string }> {
  if (!GROQ_SCAN_API_KEY) {
    return { error: 'GROQ_SCAN_API_KEY 未在 Supabase Secrets 中設定' };
  }

  for (let attempt = 1; attempt <= MAXIMUM_ATTEMPTS; attempt++) {
    const useJsonMode = attempt === 1;
    const startedAt = Date.now();
    const response = await callGroqVision(images, useJsonMode);
    const elapsedMilliseconds = Date.now() - startedAt;

    if (!response.ok) {
      // 只記錄 Groq 的錯誤代碼與說明（說明是關於請求本身，不含保單內容）
      const errorDetail = await readGroqError(response);
      console.error(`Groq scan attempt ${attempt} failed: status=${response.status} ${errorDetail} (${elapsedMilliseconds}ms)`);
      // 金鑰錯誤、沒有權限：重試也沒用
      if (response.status === 401 || response.status === 403) break;
      await waitBeforeRetry(response);
      continue;
    }

    const data = await response.json();
    const aiText: string = data?.choices?.[0]?.message?.content ?? '';
    const parsed = parseJsonFromText(aiText);
    if (!parsed) {
      console.error(`Groq scan attempt ${attempt}: reply was not JSON (length=${aiText.length}, ${elapsedMilliseconds}ms)`);
      continue;
    }
    console.log(`Groq scan attempt ${attempt} ok (${elapsedMilliseconds}ms)`);
    return { result: keepAllowedFields(parsed) };
  }
  return { error: 'AI 辨識暫時無法使用，請稍後再試或改用手動輸入' };
}

// Groq 錯誤格式：{ error: { message, type, code } }；只取 code 與 message 前 200 字
async function readGroqError(response: Response): Promise<string> {
  try {
    const body = await response.json();
    const code = body?.error?.code ?? body?.error?.type ?? '';
    const message = String(body?.error?.message ?? '').slice(0, 200);
    return `code=${code} message=${message}`;
  } catch (_error) {
    return '';
  }
}

// 太頻繁（429）時照 Groq 給的秒數等（每分鐘額度要等它恢復），最多等 20 秒；其他錯誤等 0.5 秒
async function waitBeforeRetry(response: Response): Promise<void> {
  let waitMilliseconds = 500;
  if (response.status === 429) {
    const retryAfterSeconds = Number(response.headers.get('retry-after') ?? '2');
    waitMilliseconds = Math.min(Math.max(retryAfterSeconds, 1), 20) * 1000;
  }
  await new Promise((resolve) => setTimeout(resolve, waitMilliseconds));
}

// AI 可能在 JSON 前後多寫字（例如思考過程），只取第一個 { 到最後一個 }
function parseJsonFromText(text: string): Record<string, unknown> | null {
  const withoutThinking = text.replace(/<think>[\s\S]*?<\/think>/g, '');
  const start = withoutThinking.indexOf('{');
  const end = withoutThinking.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(withoutThinking.slice(start, end + 1));
  } catch (_error) {
    return null;
  }
}

// 白名單：就算 AI 多回傳了個資，這裡也只留下商品欄位
function keepAllowedFields(parsed: Record<string, unknown>): ScanResult {
  const rawItems = Array.isArray(parsed.items) ? parsed.items : [];
  const items: ScannedItem[] = [];
  for (const rawItem of rawItems) {
    const productName = cleanText(rawItem?.product_name);
    if (!productName) continue;
    items.push({
      product_name: productName,
      coverage_role: cleanRole(rawItem?.coverage_role),
      plan_or_amount: cleanText(rawItem?.plan_or_amount),
      premium: cleanPremium(rawItem?.premium),
    });
  }
  return {
    company_name: cleanText(parsed.company_name),
    policy_number: cleanText(parsed.policy_number),
    effective_date: cleanDate(parsed.effective_date),
    items,
  };
}

function cleanText(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed.toLowerCase() === 'null') return null;
  return trimmed.slice(0, 200);
}

function cleanRole(value: unknown): 'main' | 'rider' | null {
  if (value === 'main' || value === 'rider') return value;
  return null;
}

// 保費：接受數字或「12,350 元」這種文字，轉成整數
function cleanPremium(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value) && value >= 0) {
    return Math.round(value);
  }
  if (typeof value === 'string') {
    const digits = value.replace(/[^0-9]/g, '');
    if (digits) return parseInt(digits, 10);
  }
  return null;
}

// 生效日：只接受合理的 YYYY-MM-DD
function cleanDate(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const match = value.trim().match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return null;
  const year = parseInt(match[1], 10);
  if (year < 1950 || year > 2100) return null;
  return value.trim();
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 只有登入的業務員可以使用
    const authHeader = req.headers.get('Authorization') ?? '';
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    if (!authHeader.startsWith('Bearer ') || !supabaseUrl || !supabaseAnonKey) {
      return jsonResponse({ error: '請先登入' }, 401);
    }
    const client = createClient(supabaseUrl, supabaseAnonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: authError } = await client.auth.getUser(authHeader.replace(/^Bearer\s+/i, ''));
    if (authError || !user) {
      return jsonResponse({ error: '請先登入' }, 401);
    }

    const body = await req.json();
    const { images, error: imageError } = readImages(body?.images);
    if (imageError) {
      return jsonResponse({ error: imageError }, 400);
    }

    const { result, error: aiError } = await extractFieldsWithAi(images);
    if (aiError || !result) {
      return jsonResponse({ error: aiError ?? 'AI 辨識失敗' }, 502);
    }
    return jsonResponse(result);
  } catch (_error) {
    console.error('scan-policy internal error');
    return jsonResponse({ error: '伺服器處理失敗，請稍後再試' }, 500);
  }
});
