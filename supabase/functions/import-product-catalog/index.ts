// ============================================================================
// import-product-catalog：把抓取程式整理好的商品目錄寫進資料庫（5-2a，設計見全景地圖 4-H）
//
// 流程：GitHub 排程跑 tool/product_catalog/crawl_products.py → 每家公司 POST 一次到這裡
//   1. 比對排程密碼（x-product-catalog-secret），對不上就拒絕
//   2. 檢查資料格式：公司只能是允許的三家、網址只能是該公司官網、欄位長度與種類
//   3. 用 service role 依「公司＋商品名稱」新增或更新 insurance_products（只增不刪）
//   4. 在 product_crawl_runs 記一筆成功／失敗紀錄
// 這支函式只給伺服器對伺服器呼叫：不開放瀏覽器（沒有 CORS），也不檢查登入（Verify JWT 關閉）。
// 需要的 Secrets：PRODUCT_CATALOG_SECRET、SUPABASE_URL、SUPABASE_SERVICE_ROLE_KEY
// ============================================================================

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const PRODUCT_CATALOG_SECRET = Deno.env.get('PRODUCT_CATALOG_SECRET') ?? '';

// 允許的公司與各自官網網域：條款連結、來源網址只能指向這些網域
const ALLOWED_COMPANIES: Record<string, { companyName: string; allowedHosts: string[] }> = {
  cathay: { companyName: '國泰人壽', allowedHosts: ['www.cathaylife.com.tw'] },
  fubon: { companyName: '富邦人壽', allowedHosts: ['www.fubon.com'] },
  nanshan: { companyName: '南山人壽', allowedHosts: ['www.nanshanlife.com.tw'] },
};

const PRODUCT_KINDS = ['main', 'rider', 'endorsement'];
const INSURANCE_TYPES = [
  'medical', 'cancer', 'critical_illness', 'long_term_care',
  'accident', 'life', 'annuity', 'investment', 'other',
];
const MAXIMUM_REQUEST_BYTES = 5 * 1024 * 1024;
const MAXIMUM_PRODUCT_COUNT = 3000;
const UPSERT_BATCH_SIZE = 200;

interface ProductRow {
  company_code: string;
  company_name: string;
  product_code: string | null;
  product_name: string;
  product_kind: string;
  insurance_type: string | null;
  source_category: string;
  approval_date: string | null;
  approval_number: string | null;
  approval_history: string | null;
  clause_url: string | null;
  source_url: string;
  last_seen_at: string;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// 比對密碼時花的時間固定，避免被人用回應快慢一個字一個字猜出密碼
function isSameSecret(received: string, expected: string): boolean {
  const encoder = new TextEncoder();
  const receivedBytes = encoder.encode(received);
  const expectedBytes = encoder.encode(expected);
  let difference = receivedBytes.length ^ expectedBytes.length;
  for (let index = 0; index < expectedBytes.length; index++) {
    difference |= (receivedBytes[index] ?? 0) ^ expectedBytes[index];
  }
  return difference === 0;
}

// 選填文字欄位：不是文字或是空字串就當作沒有；太長就判定格式錯誤
function optionalText(value: unknown, maximumLength: number, fieldName: string): string | null {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value !== 'string' || value.length > maximumLength) {
    throw new Error(`${fieldName} 格式錯誤`);
  }
  return value.trim() || null;
}

// 網址必須是 https，而且網域在該公司的官網清單裡
function optionalOfficialUrl(value: unknown, allowedHosts: string[], fieldName: string): string | null {
  const urlText = optionalText(value, 1000, fieldName);
  if (urlText === null) return null;
  let parsedUrl: URL;
  try {
    parsedUrl = new URL(urlText);
  } catch {
    throw new Error(`${fieldName} 不是網址`);
  }
  if (parsedUrl.protocol !== 'https:' || !allowedHosts.includes(parsedUrl.hostname)) {
    throw new Error(`${fieldName} 不是該公司官網的 https 網址`);
  }
  return urlText;
}

// 把一筆商品檢查並轉成資料表的一列；任何欄位不對就丟出錯誤
function toProductRow(
  rawProduct: Record<string, unknown>,
  companyCode: string,
  seenAt: string,
): ProductRow {
  const company = ALLOWED_COMPANIES[companyCode];

  const productName = optionalText(rawProduct.product_name, 200, 'product_name');
  if (productName === null) throw new Error('product_name 不可空白');

  const productKind = String(rawProduct.product_kind ?? 'main');
  if (!PRODUCT_KINDS.includes(productKind)) throw new Error(`product_kind 不正確：${productKind}`);

  const insuranceType = optionalText(rawProduct.insurance_type, 30, 'insurance_type');
  if (insuranceType !== null && !INSURANCE_TYPES.includes(insuranceType)) {
    throw new Error(`insurance_type 不正確：${insuranceType}`);
  }

  const approvalDate = optionalText(rawProduct.approval_date, 10, 'approval_date');
  if (approvalDate !== null && !/^\d{4}-\d{2}-\d{2}$/.test(approvalDate)) {
    throw new Error(`approval_date 格式錯誤：${approvalDate}`);
  }

  const sourceUrl = optionalOfficialUrl(rawProduct.source_url, company.allowedHosts, 'source_url');
  if (sourceUrl === null) throw new Error('source_url 不可空白');

  const productCode = optionalText(rawProduct.product_code, 20, 'product_code');
  if (productCode !== null && !/^[A-Z0-9]+$/.test(productCode)) {
    throw new Error(`product_code 格式錯誤：${productCode}`);
  }

  return {
    company_code: companyCode,
    company_name: company.companyName,
    product_code: productCode,
    product_name: productName,
    product_kind: productKind,
    insurance_type: insuranceType,
    source_category: optionalText(rawProduct.source_category, 100, 'source_category') ?? '',
    approval_date: approvalDate,
    approval_number: optionalText(rawProduct.approval_number, 100, 'approval_number'),
    approval_history: optionalText(rawProduct.approval_history, 2000, 'approval_history'),
    clause_url: optionalOfficialUrl(rawProduct.clause_url, company.allowedHosts, 'clause_url'),
    source_url: sourceUrl,
    last_seen_at: seenAt,
  };
}

// 記一筆抓取紀錄；記錄失敗只寫 log，不影響回應
async function recordCrawlRun(
  supabase: SupabaseClient,
  companyCode: string,
  startedAt: string,
  status: 'success' | 'failed',
  productCount: number,
  errorMessage: string | null,
): Promise<void> {
  const { error } = await supabase.from('product_crawl_runs').insert({
    company_code: companyCode,
    started_at: startedAt,
    finished_at: new Date().toISOString(),
    status,
    product_count: productCount,
    error_message: errorMessage ? errorMessage.slice(0, 1000) : null,
  });
  if (error) console.error('[import-product-catalog] 寫入抓取紀錄失敗', error.message);
}

// 依「公司＋商品名稱」新增或更新；沒送的欄位（first_seen_at）保留原值
async function upsertProducts(supabase: SupabaseClient, productRows: ProductRow[]): Promise<void> {
  for (let start = 0; start < productRows.length; start += UPSERT_BATCH_SIZE) {
    const batch = productRows.slice(start, start + UPSERT_BATCH_SIZE);
    const { error } = await supabase
      .from('insurance_products')
      .upsert(batch, { onConflict: 'company_code,product_name' });
    if (error) throw new Error(`寫入商品失敗：${error.message}`);
  }
}

// 開始時間用抓取程式送來的時間；格式不對就用現在
function parseStartedAt(value: unknown): string {
  if (typeof value === 'string' && !Number.isNaN(Date.parse(value))) {
    return new Date(value).toISOString();
  }
  return new Date().toISOString();
}

serve(async (request: Request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ success: false, error: 'Method not allowed' }, 405);
  }

  // 伺服器設定不完整時直接停止，避免用錯誤的權限寫入資料庫
  if (!PRODUCT_CATALOG_SECRET || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error('[import-product-catalog] 缺少 PRODUCT_CATALOG_SECRET 或 Supabase 環境變數');
    return jsonResponse({ success: false, error: 'Server configuration error' }, 500);
  }

  const receivedSecret = request.headers.get('x-product-catalog-secret') ?? '';
  if (!isSameSecret(receivedSecret, PRODUCT_CATALOG_SECRET)) {
    return jsonResponse({ success: false, error: 'Unauthorized' }, 401);
  }

  // 讀取並解析內容（限制大小，避免被塞超大資料）
  const requestText = await request.text();
  if (requestText.length > MAXIMUM_REQUEST_BYTES) {
    return jsonResponse({ success: false, error: '資料太大' }, 413);
  }
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(requestText);
  } catch {
    return jsonResponse({ success: false, error: '內容不是 JSON' }, 400);
  }

  const companyCode = String(payload.company_code ?? '');
  if (!(companyCode in ALLOWED_COMPANIES)) {
    return jsonResponse({ success: false, error: `不支援的公司：${companyCode}` }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const startedAt = parseStartedAt(payload.started_at);

  // 抓取程式那邊就失敗了：只記紀錄，資料庫裡這家的舊資料不動
  if (payload.status === 'failed') {
    const crawlerError = optionalText(payload.error_message, 1000, 'error_message') ?? '抓取失敗（未提供原因）';
    await recordCrawlRun(supabase, companyCode, startedAt, 'failed', 0, crawlerError);
    return jsonResponse({ success: true, recorded: 'failed' });
  }

  const rawProducts = payload.products;
  if (!Array.isArray(rawProducts) || rawProducts.length === 0 || rawProducts.length > MAXIMUM_PRODUCT_COUNT) {
    await recordCrawlRun(supabase, companyCode, startedAt, 'failed', 0, '商品清單是空的或筆數異常');
    return jsonResponse({ success: false, error: '商品清單是空的或筆數異常' }, 400);
  }

  // 全部檢查通過才寫入；同名商品只留第一筆（同一批更新不能動到同一列兩次）
  const seenAt = new Date().toISOString();
  const productRowsByName = new Map<string, ProductRow>();
  try {
    for (const rawProduct of rawProducts) {
      if (typeof rawProduct !== 'object' || rawProduct === null) throw new Error('商品資料格式錯誤');
      const productRow = toProductRow(rawProduct as Record<string, unknown>, companyCode, seenAt);
      if (!productRowsByName.has(productRow.product_name)) {
        productRowsByName.set(productRow.product_name, productRow);
      }
    }
  } catch (validationError) {
    const message = `資料格式錯誤：${(validationError as Error).message}`;
    await recordCrawlRun(supabase, companyCode, startedAt, 'failed', 0, message);
    return jsonResponse({ success: false, error: message }, 400);
  }

  const productRows = [...productRowsByName.values()];
  try {
    await upsertProducts(supabase, productRows);
  } catch (writeError) {
    const message = (writeError as Error).message;
    console.error('[import-product-catalog]', message);
    await recordCrawlRun(supabase, companyCode, startedAt, 'failed', 0, message);
    return jsonResponse({ success: false, error: '寫入資料庫失敗' }, 500);
  }

  await recordCrawlRun(supabase, companyCode, startedAt, 'success', productRows.length, null);
  return jsonResponse({ success: true, company_code: companyCode, product_count: productRows.length });
});
