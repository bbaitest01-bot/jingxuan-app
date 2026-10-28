// ============================================================================
// 掃描保單（第 5 階段 E：D6、D7；設計見全景地圖 4-J）
//
// 流程分兩段：
//   第一段「取得內容」：三種來源
//     - 電子保單 PDF 的文字（2026-10-25 起，③ 版的 PDF 部分：瀏覽器取出文字、個資先遮蔽，只送文字）
//     - 一張照片切成上下兩半（2026-10-25 起，字放大一倍，密的表格比較不會漏列）
//     - 照片、截圖原樣（多頁時）
//   第二段「整理成欄位」：請 AI 只回傳商品欄位，再用白名單把其他東西全部丟掉
//
// 隱私（④ 版，2026-10-24 沛沛確認）：
//   - 照片、文字只在這次請求的記憶體裡，不存檔、不寫資料庫、不寫 log
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
// 文字版最多收 15,000 字（3 頁保單約 1,500～3,000 字）
const MAXIMUM_TEXT_LENGTH = 15_000;

// 這次送來的內容：文字、切兩半的照片、或一般照片
interface PolicyContent {
  text: string | null;
  images: PolicyImage[];
  isSplitImage: boolean;
  // App 沒切成兩半的原因（只有技術代碼，不含保單內容）；有切或文字版是空字串
  splitFailedReason?: string;
}

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
  premium_currency: string | null;
}

interface ScanResult {
  company_name: string | null;
  policy_number: string | null;
  effective_date: string | null;
  // AI 數出來保單上一共幾項；app 用它提醒「保單上有 9 項，只讀到 7 項」
  item_count: number | null;
  items: ScannedItem[];
}

// 認得的幣別代碼；其他的一律當成看不懂（null）
const KNOWN_CURRENCIES = ['TWD', 'USD', 'AUD', 'CNY', 'EUR', 'JPY', 'GBP', 'NZD', 'HKD'];

// 給 AI 的指示：只要商品欄位，明確禁止回傳個資
// 2026-10-24 沛沛手機實測：9 項只讀到 7 項（回答太長被截斷）→ 改成精簡格式：
//   每個商品用一個陣列表示、欄位名稱縮短，同樣內容大約省 4 成 token；先回報總項數，方便 app 檢查有沒有漏
const EXTRACTION_PROMPT = `只回傳一行精簡 JSON（不要換行、不要多餘空白、不要其他文字）：
{"co":公司全名,"no":保單號碼,"d":契約生效日,"n":商品總項數,"i":[[商品名稱,主附約,計畫或保額,保費,幣別]]}
欄位說明：
- co：保險公司全名，例如 國泰人壽保險股份有限公司
- no：保單號碼或契約號碼
- d：契約生效日，一律換成西元 YYYY-MM-DD（民國年加 1911）
- n：保單上主約加附約一共幾項（整數），先數清楚再填
- i：每個商品一個陣列，順序照保單：
  1. 商品名稱：照保單上的字逐字抄寫，不要簡化、不要改字
  2. 主附約："m" 是主約／主契約，"r" 是附約／附加契約，看不出來填 null
  3. 計畫或保額：照保單上的字抄寫，例如 計畫三、50 萬元、USD 100,000；沒有填 null
  4. 保費：該商品的每期保費數字（整數，去掉逗號、單位與幣別符號）；沒有填 null
  5. 幣別：保費的幣別代碼，新臺幣填 "TWD"、美元填 "USD"、澳幣 "AUD"、人民幣 "CNY"；看不出來填 null
看不到或看不清楚的欄位填 null，不要猜。
規則：
1. 保單上每一個主約、附約都要列出，一項都不能漏；批註條款、保費合計不要列。
2. 絕對不要回傳要保人、被保險人、受益人姓名、身分證字號、出生日期、地址、電話、帳號等個人資料。
3. 全部使用繁體中文。`;

// 依內容來源換開頭的說明
function buildPrompt(content: PolicyContent): string {
  if (content.text) {
    return '你是台灣保險保單的資料整理助手。以下是從電子保單 PDF 取出的文字，同一行的不同欄位用「 | 」隔開，'
      + '表格太窄時一個格子可能被拆成上下兩行，請合併回來；個資已被遮蔽。請閱讀後'
      + EXTRACTION_PROMPT + '\n\n保單文字：\n' + content.text;
  }
  if (content.isSplitImage) {
    return '你是台灣保險保單的資料整理助手。這兩張影像是同一頁保單的上半部與下半部，中間有一段重疊；'
      + '重疊處出現兩次的同一列只算一次。請逐列閱讀，每一列的計畫、保費只能取自同一列，不可跨列。請閱讀後'
      + EXTRACTION_PROMPT;
  }
  return '你是台灣保險保單的資料整理助手。請閱讀保單影像，逐列閱讀，每一列的計畫、保費只能取自同一列，不可跨列。'
    + EXTRACTION_PROMPT;
}

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

// 文字優先；沒有文字才看照片
function readContent(body: Record<string, unknown>): { content?: PolicyContent; error?: string } {
  const rawText = body?.text;
  if (typeof rawText === 'string') {
    const text = rawText.trim();
    if (!text) return { error: '沒有收到保單內容' };
    if (text.length > MAXIMUM_TEXT_LENGTH) return { error: '保單文字太長，請只上傳保單首頁' };
    return { content: { text, images: [], isSplitImage: false } };
  }
  const { images, error } = readImages(body?.images);
  if (error) return { error };
  // App 沒能把照片切成兩半時帶來的原因（2026-10-28 D7 再次發生：iPhone 都是 image）；只留英數與少數符號，最多 120 字
  const rawSplitFailed = typeof body?.split_failed === 'string' ? body.split_failed : '';
  const splitFailedReason = rawSplitFailed.replace(/[^A-Za-z0-9_ =.:x-]/g, '').slice(0, 120);
  if (splitFailedReason) console.warn(`split skipped: ${splitFailedReason}`);
  return { content: { text: null, images, isSplitImage: body?.layout === 'split' && images.length === 2, splitFailedReason } };
}

// ---------------------------------------------------------------------------
// 第二段：請 AI 整理成欄位
// ---------------------------------------------------------------------------
async function callGroqVision(policyContent: PolicyContent, useJsonMode: boolean): Promise<Response> {
  const content: unknown[] = [{ type: 'text', text: buildPrompt(policyContent) }];
  for (const image of policyContent.images) {
    content.push({
      type: 'image_url',
      image_url: { url: `data:${image.mimeType};base64,${image.base64}` },
    });
  }

  // 2026-10-24 Logs 查到失敗原因是 429：免費方案「每分鐘輸出 token（OTPM）」上限只有 1000，
  // Groq 會先用 max_completion_tokens 預留額度，預留超過 1000 就直接拒絕。
  //   reasoning_effort 'none'：照抄保單不需要 AI 先「思考」，關掉可省下大量 token，也比較快
  //   max_completion_tokens 900：精簡格式下 11 項約 450～550 token，留一些餘裕又不超過 1000
  const requestBody: Record<string, unknown> = {
    model: GROQ_SCAN_MODEL,
    temperature: 0.1,
    reasoning_effort: 'none',
    max_completion_tokens: 900,
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

async function extractFieldsWithAi(policyContent: PolicyContent): Promise<{ result?: ScanResult; error?: string }> {
  if (!GROQ_SCAN_API_KEY) {
    return { error: 'GROQ_SCAN_API_KEY 未在 Supabase Secrets 中設定' };
  }

  for (let attempt = 1; attempt <= MAXIMUM_ATTEMPTS; attempt++) {
    const useJsonMode = attempt === 1;
    const startedAt = Date.now();
    const response = await callGroqVision(policyContent, useJsonMode);
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
    // 回答被長度上限截斷：記下來，方便從 Logs 判斷是不是又要調高上限
    if (data?.choices?.[0]?.finish_reason === 'length') {
      console.error(`Groq scan attempt ${attempt}: reply cut off by max_completion_tokens`);
    }
    const parsed = parseJsonFromText(aiText);
    if (!parsed) {
      console.error(`Groq scan attempt ${attempt}: reply was not JSON (length=${aiText.length}, ${elapsedMilliseconds}ms)`);
      continue;
    }
    let source = 'image';
    if (policyContent.text) source = 'text';
    else if (policyContent.isSplitImage) source = 'split';
    else if (policyContent.splitFailedReason) source = `image, split_failed=${policyContent.splitFailedReason}`;
    console.log(`Groq scan attempt ${attempt} ok (${source}, ${elapsedMilliseconds}ms)`);
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
// 精簡格式（co／no／d／n／i 陣列）轉回 app 用的完整欄位名稱；舊格式（物件）也看得懂
function keepAllowedFields(parsed: Record<string, unknown>): ScanResult {
  const rawItems = Array.isArray(parsed.i) ? parsed.i : (Array.isArray(parsed.items) ? parsed.items : []);
  const items: ScannedItem[] = [];
  for (const rawItem of rawItems) {
    const item = readOneItem(rawItem);
    if (item) items.push(item);
  }
  return {
    company_name: cleanText(parsed.co ?? parsed.company_name),
    policy_number: cleanText(parsed.no ?? parsed.policy_number),
    effective_date: cleanDate(parsed.d ?? parsed.effective_date),
    item_count: cleanCount(parsed.n ?? parsed.item_count),
    items,
  };
}

// 一個商品：[名稱, 主附約, 計畫或保額, 保費, 幣別]
function readOneItem(rawItem: unknown): ScannedItem | null {
  let values: unknown[] = [];
  if (Array.isArray(rawItem)) {
    values = rawItem;
  } else if (rawItem && typeof rawItem === 'object') {
    const item = rawItem as Record<string, unknown>;
    values = [item.product_name, item.coverage_role, item.plan_or_amount, item.premium, item.premium_currency];
  }
  const productName = cleanText(values[0]);
  if (!productName) return null;
  return {
    product_name: productName,
    coverage_role: cleanRole(values[1]),
    plan_or_amount: cleanText(values[2]),
    premium: cleanPremium(values[3]),
    premium_currency: cleanCurrency(values[4]),
  };
}

function cleanCount(value: unknown): number | null {
  if (typeof value === 'number' && Number.isInteger(value) && value > 0 && value < 100) return value;
  return null;
}

function cleanCurrency(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const code = value.trim().toUpperCase();
  if (KNOWN_CURRENCIES.includes(code)) return code;
  return null;
}

function cleanText(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed.toLowerCase() === 'null') return null;
  return trimmed.slice(0, 200);
}

function cleanRole(value: unknown): 'main' | 'rider' | null {
  if (value === 'main' || value === 'm') return 'main';
  if (value === 'rider' || value === 'r') return 'rider';
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
    const { content, error: contentError } = readContent(body);
    if (contentError || !content) {
      return jsonResponse({ error: contentError ?? '沒有收到保單內容' }, 400);
    }

    const { result, error: aiError } = await extractFieldsWithAi(content);
    if (aiError || !result) {
      return jsonResponse({ error: aiError ?? 'AI 辨識失敗' }, 502);
    }
    return jsonResponse(result);
  } catch (_error) {
    console.error('scan-policy internal error');
    return jsonResponse({ error: '伺服器處理失敗，請稍後再試' }, 500);
  }
});
