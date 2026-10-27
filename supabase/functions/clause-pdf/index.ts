// ============================================================================
// 官方條款 PDF 轉送（D5 再次發生，2026-10-28）
//
// 問題：iPhone（Safari 與主畫面 App）從我們網站點富邦條款連結，會被富邦網站轉到金控首頁；
//       電腦與國泰、南山正常，富邦伺服器直接要也回傳 PDF。
// 做法：app 改開這個函式，由這裡向富邦拿 PDF 再原樣回傳，手機看到的就是 PDF 檔。
//
// 安全：
//   - 只轉送富邦條款檔（https://www.fubon.com/life/api/v1/files/…），其他網址一律拒絕，避免被當成任意代理
//   - 只回傳 PDF（富邦回的不是 PDF 就拒絕）、最大 20MB、20 秒逾時
//   - 條款是官網公開文件，不含個資；Verify JWT 關閉（瀏覽器開新分頁無法帶登入憑證）
// ============================================================================
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const ALLOWED_HOST = 'www.fubon.com';
const ALLOWED_PATH_PREFIX = '/life/api/v1/files/';
const MAXIMUM_PDF_BYTES = 20 * 1024 * 1024;
const FETCH_TIMEOUT_MILLISECONDS = 20_000;

function errorResponse(status: number, message: string): Response {
  return new Response(message, { status, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
}

// 檢查網址：一定要是富邦條款檔的 https 網址
function parseAllowedClauseUrl(rawUrl: string | null): URL | null {
  if (!rawUrl) return null;
  let clauseUrl: URL;
  try {
    clauseUrl = new URL(rawUrl);
  } catch {
    return null;
  }
  if (clauseUrl.protocol !== 'https:' || clauseUrl.hostname !== ALLOWED_HOST) return null;
  if (!clauseUrl.pathname.startsWith(ALLOWED_PATH_PREFIX)) return null;
  return clauseUrl;
}

serve(async (request: Request) => {
  if (request.method !== 'GET') {
    return errorResponse(405, '只接受 GET');
  }
  const clauseUrl = parseAllowedClauseUrl(new URL(request.url).searchParams.get('url'));
  if (!clauseUrl) {
    return errorResponse(400, '只能開啟富邦人壽官方條款檔');
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MILLISECONDS);
  try {
    const upstream = await fetch(clauseUrl.toString(), {
      headers: { 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', 'Accept': 'application/pdf' },
      redirect: 'follow',
      signal: controller.signal,
    });
    const contentType = upstream.headers.get('content-type') ?? '';
    if (!upstream.ok || !contentType.includes('application/pdf')) {
      return errorResponse(502, '富邦官網沒有回傳條款 PDF，請稍後再試');
    }
    const pdfBytes = new Uint8Array(await upstream.arrayBuffer());
    if (pdfBytes.byteLength > MAXIMUM_PDF_BYTES) {
      return errorResponse(502, '條款檔太大');
    }
    return new Response(pdfBytes, {
      status: 200,
      headers: {
        'Content-Type': 'application/pdf',
        // inline：在瀏覽器直接顯示，不是下載
        'Content-Disposition': 'inline',
        // 條款很少改，瀏覽器快取一天
        'Cache-Control': 'public, max-age=86400',
      },
    });
  } catch (_error) {
    return errorResponse(504, '連不到富邦官網，請稍後再試');
  } finally {
    clearTimeout(timer);
  }
});
