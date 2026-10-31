import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
// 排程專用密碼：只有帶著這把密碼的請求（GitHub Actions 每日排程）才能觸發新聞更新
const NEWS_CRON_SECRET = Deno.env.get('NEWS_CRON_SECRET') ?? '';
// AI 插圖（2026-10-31）：Cloudflare Workers AI 免費額度（每天約 10,000 點，一張圖約 58 點）
const CLOUDFLARE_ACCOUNT_ID = Deno.env.get('CLOUDFLARE_ACCOUNT_ID') ?? '';
const CLOUDFLARE_AI_TOKEN = Deno.env.get('CLOUDFLARE_AI_TOKEN') ?? '';
const NEWS_IMAGE_BUCKET = 'news-images';
// 插畫風格（2026-10-31 沛沛：要像第一張西洋棋那樣精緻）：整張畫滿、有光影與景深、深藍灰色調、
// 背景用和報紙一樣的淺灰，圖像印在報紙上；只寫想要的東西（FLUX 看到「不要有字」反而會畫字）
const NEWS_IMAGE_STYLE =
  'refined editorial illustration, full-frame composition with depth and soft dramatic lighting, ' +
  'rich deep navy blue and cool gray tones, light cool gray background like newsprint, fine paper grain, ' +
  'elegant and calm, stylized silhouettes without facial detail, wordless';

// 插畫畫面只從這份清單挑：都是不會帶字的完整場景（自由描述時盾牌、報紙、車子上會長出亂碼字）
// 由 Groq 依主題挑最貼切的一個編號
const NEWS_IMAGE_SCENES: string[] = [
  'a giant umbrella sheltering a row of small houses during heavy rain',
  'a paper airplane gliding above layers of soft clouds toward a distant sunrise',
  'a heavy padlock resting on a smooth stone in a quiet garden',
  'a chessboard in perspective with a lone king standing among fallen pieces',
  'a large magnifying glass hovering over a miniature town at dusk',
  'a lighthouse beam cutting through a stormy night sea',
  'two cupped hands holding a young green sprout in warm light',
  'an antique compass on a wooden table beside a folded blank map',
  'a stone arch bridge connecting two cliffs above misty water',
  'stacks of round coins growing like steps toward a small tree',
  'a glowing heart shape cradled by a coiled stethoscope',
  'a ship anchor resting on rippled sand under calm shallow water',
  'a golden key floating before an open door filled with light',
  'hot air balloons drifting over rolling hills at golden hour',
  'paper airplanes circling a large globe in a soft sky',
  'a small car parked safely under a huge umbrella in a rainstorm',
  'dark storm clouds gathering over a farm field with a lone barn',
  'a long ladder leaning against the night sky reaching toward a bright star',
  'two large puzzle pieces sliding together in soft light',
  'a brass balance scale holding two smooth spheres in equilibrium',
];

// 編號（1 開始）換成畫面；編號不對時用標題算一個固定的編號，同一個話題每次都一樣
function sceneFor(sceneNumber: unknown, title: string): string {
  const parsed = parseInt(String(sceneNumber ?? ''), 10);
  if (!isNaN(parsed) && parsed >= 1 && parsed <= NEWS_IMAGE_SCENES.length) return NEWS_IMAGE_SCENES[parsed - 1];
  let hash = 0;
  for (const char of title) hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  return NEWS_IMAGE_SCENES[hash % NEWS_IMAGE_SCENES.length];
}

const NEWS_IMAGE_SCENE_LIST_TEXT = NEWS_IMAGE_SCENES.map((scene, index) => `${index + 1}. ${scene}`).join('\n');

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-news-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
};

interface RSSItem {
  title: string;
  link: string;
  source: string;
  pubDate: string;
}

// 1. 解析 Google News / 金管會 / 各大金融媒體 RSS XML
function parseRSSXml(xmlText: string): RSSItem[] {
  const items: RSSItem[] = [];
  const itemMatches = xmlText.match(/<item>[\s\S]*?<\/item>/gi) || [];

  for (const itemXml of itemMatches) {
    const titleMatch = itemXml.match(/<title>([\s\S]*?)<\/title>/i);
    const linkMatch = itemXml.match(/<link>([\s\S]*?)<\/link>/i);
    const pubDateMatch = itemXml.match(/<pubDate>([\s\S]*?)<\/pubDate>/i);
    const sourceMatch = itemXml.match(/<source[^>]*>([\s\S]*?)<\/source>/i);

    let rawTitle = titleMatch ? titleMatch[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim() : '';
    const link = linkMatch ? linkMatch[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim() : '';
    const pubDate = pubDateMatch ? pubDateMatch[1].trim() : '';
    let source = sourceMatch ? sourceMatch[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim() : '';

    if (!source && rawTitle.includes(' - ')) {
      const parts = rawTitle.split(' - ');
      source = parts.pop()?.trim() || '新聞媒體';
      rawTitle = parts.join(' - ').trim();
    }

    // 嚴格比對文章實體發布時間 (pubDate)，強制過濾早於 36 小時前之過期歷史新聞
    if (pubDate) {
      const pubTime = Date.parse(pubDate);
      if (!isNaN(pubTime)) {
        const now = Date.now();
        const maxAgeMs = 36 * 60 * 60 * 1000; // 36 小時 (精準過濾舊聞，並兼顧週末新聞空窗期)
        if ((now - pubTime) > maxAgeMs) {
          continue; // 直接徹底排除過期歷史舊聞！
        }
      }
    }

    if (rawTitle && link) {
      items.push({
        title: rawTitle,
        link: link,
        source: source || '金融權威',
        pubDate: pubDate,
      });
    }
  }

  return items;
}

// 空字串、只有空白都當成沒有
function cleanText(value: unknown): string | null {
  const text = typeof value === 'string' ? value.trim() : '';
  return text.length > 0 ? text : null;
}

// 3. 用 Cloudflare Workers AI（FLUX schnell）畫一張插圖，存到 Storage，再把網址寫回話題
//    沒設定 Cloudflare 金鑰或任何一步失敗都只記錄、回傳 false，不讓整個新聞更新失敗
async function generateTopicImage(
  supabaseClient: any,
  topicId: string,
  todayDate: string,
  imagePrompt: string,
): Promise<boolean> {
  if (!CLOUDFLARE_ACCOUNT_ID || !CLOUDFLARE_AI_TOKEN) {
    console.log('[news image] 沒有設定 Cloudflare 金鑰，跳過插圖');
    return false;
  }
  try {
    const res = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID.trim()}/ai/run/@cf/black-forest-labs/flux-1-schnell`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${CLOUDFLARE_AI_TOKEN.trim()}`,
        },
        body: JSON.stringify({ prompt: `${imagePrompt}. ${NEWS_IMAGE_STYLE}`, steps: 4 }),
      },
    );
    if (!res.ok) {
      console.error('[news image] Cloudflare 畫圖失敗:', res.status, await res.text());
      return false;
    }
    const data = await res.json();
    const base64Image: string = data?.result?.image ?? '';
    if (!base64Image) {
      console.error('[news image] Cloudflare 沒有回傳圖片');
      return false;
    }
    // base64 文字轉回圖片的位元組
    const binary = atob(base64Image);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

    // 每次畫都用新檔名，瀏覽器和 CDN 才不會一直顯示舊圖
    const path = `${todayDate}/${topicId}-${Date.now()}.jpg`;
    const { error: uploadError } = await supabaseClient.storage
      .from(NEWS_IMAGE_BUCKET)
      .upload(path, bytes, { contentType: 'image/jpeg', upsert: true });
    if (uploadError) {
      console.error('[news image] 上傳 Storage 失敗:', uploadError);
      return false;
    }
    const { data: publicUrlData } = supabaseClient.storage.from(NEWS_IMAGE_BUCKET).getPublicUrl(path);
    const { error: updateError } = await supabaseClient
      .from('insurance_news_topics')
      .update({ main_image_url: publicUrlData.publicUrl })
      .eq('id', topicId);
    if (updateError) {
      console.error('[news image] 寫回圖片網址失敗:', updateError);
      return false;
    }
    return true;
  } catch (err) {
    console.error('[news image] 例外:', err);
    return false;
  }
}

// 4. 補畫插圖：今天和昨天還沒有圖的話題（例如插圖功能上線前抓的、或上次畫圖失敗的），每次最多補 8 張
//    舊話題沒有存畫面編號，先請 Groq 依標題與重點從清單挑一個，再交給 Cloudflare 畫
const MAX_BACKFILL_IMAGES = 8;

async function chooseSceneNumber(title: string, summary: string): Promise<number | null> {
  if (!GROQ_API_KEY) return null;
  for (const model of ['openai/gpt-oss-20b', 'llama-3.3-70b-versatile']) {
    try {
      const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${GROQ_API_KEY.trim()}` },
        body: JSON.stringify({
          model,
          temperature: 0.2,
          max_tokens: 20,
          messages: [
            {
              role: 'system',
              content: 'Pick the ONE illustration scene number that best symbolizes this insurance news topic. ' +
                `Reply with the number only.\n${NEWS_IMAGE_SCENE_LIST_TEXT}`,
            },
            { role: 'user', content: `Topic: ${title}\nSummary: ${summary}` },
          ],
        }),
      });
      if (!res.ok) continue;
      const data = await res.json();
      const number = parseInt(String(data.choices?.[0]?.message?.content ?? '').replace(/[^0-9]/g, ''), 10);
      if (!isNaN(number)) return number;
    } catch (_) {
      // 換下一個模型
    }
  }
  return null;
}

async function backfillMissingImages(supabaseClient: any): Promise<number> {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Taipei' });
  const today = formatter.format(now);
  const yesterday = formatter.format(new Date(now.getTime() - 24 * 60 * 60 * 1000));
  const { data: topics, error } = await supabaseClient
    .from('insurance_news_topics')
    .select('id, topic_title, ai_summary, publish_date, insurance_news_articles(count)')
    .is('main_image_url', null)
    .in('publish_date', [today, yesterday])
    .order('created_at', { ascending: false })
    .limit(30);
  if (error || !topics) {
    console.error('[news image] 讀取缺圖的話題失敗:', error);
    return 0;
  }
  let count = 0;
  for (const topic of topics) {
    if (count >= MAX_BACKFILL_IMAGES) break;
    // 沒有任何報導的話題畫面上不會出現，不幫它畫
    const articleCount = topic.insurance_news_articles?.[0]?.count ?? 0;
    if (articleCount === 0) continue;
    const sceneNumber = await chooseSceneNumber(topic.topic_title, topic.ai_summary || '');
    const scene = sceneFor(sceneNumber, topic.topic_title);
    if (await generateTopicImage(supabaseClient, topic.id, topic.publish_date, scene)) count++;
  }
  return count;
}

interface ClusteringOutput {
  daily_trend: string;      // 今日新聞展現的第一句總體產業趨勢
  daily_overview: string;   // 今日新聞整合摘要文章
  topics: {
    topic_title: string;
    ai_summary: string;
    short_summary?: string;    // 一句 35 字以內的重點
    key_number?: string;       // 關鍵數字（含單位）
    key_number_label?: string; // 這個數字代表什麼
    image_scene?: number;      // 插畫畫面編號（NEWS_IMAGE_SCENES）
    articles: {
      rss_index?: number;    // 對應原始 RSS 列表編號
      title: string;
      source_name: string;
      source_url: string;
      article_summary: string; // 單篇新聞重點摘要
      is_primary: boolean;
    }[];
  }[];
}

// 2. Groq AI 主題聚類、產業大勢趨勢與單篇摘要生成
async function clusterNewsWithGroq(rssItems: RSSItem[]): Promise<ClusteringOutput> {
  if (!GROQ_API_KEY) throw new Error('GROQ_API_KEY 未在 Supabase Secrets 設定');

  // 控管 Prompt Token 數量，精選當日前 30 條權威 RSS 保險新聞 (精準控管在 ~5,000 Tokens, 達 Groq 6000 TPM 限額之 80%)
  const formattedItems = rssItems
    .slice(0, 30)
    .map((item, idx) => `[${idx + 1}] ${item.title} (來源: ${item.source})`)
    .join('\n');

  const systemPrompt = `你是一位頂尖的台灣金融保險產業總編輯。
請審視今日從各大權威新聞、金管會保險局公告及金融頻道抓取的 RSS 新聞列表，完成以下三項工作：

1. daily_trend: 請用【第一句】明確總結從今天所有新聞看出來的「宏觀產業趨勢」（例如：「從今日焦點新聞可看出，主管機關正加速推動實支實付醫療險損害防阻新制與長照險商品結構調整。」）。
2. daily_overview: 撰寫一整篇約 200~350 字、結構通順完整的「今日保險產業新聞大勢總覽文章」。
3. topics: 篩選出 3 至 5 個當日最核心的『保險主題/事件』。
   - 每個主題底下包含 2~4 篇報導（標示 1 篇主要主頭條 is_primary=true，其餘為次要媒體報導 is_primary=false）。
   - ai_summary: 為該主題撰寫一段約 80~150 字的單一段落重點摘要。
   - short_summary: 用【一句話、35 字以內】寫出業務員可以直接跟客戶聊的重點（不要寫「此趨勢凸顯」這類空話）。
   - key_number: 新聞裡最關鍵的一個數字，連單位一起寫（例如「8,100 萬」「3.19 億」「2 倍」「15%」）；沒有明確數字就填空字串，不可自己編。
   - key_number_label: 這個數字代表什麼，10 字以內（例如「農業保險理賠」）；沒有數字就填空字串。
   - image_scene: 從下面的「插畫畫面清單」挑一個最能象徵這個主題的編號（數字）；同一批話題盡量不要重複。
   - 針對其中的每一篇新聞報導 (article)，皆撰寫 2~3 句的「單篇新聞重點摘要 (article_summary)」。
   - rss_index: 請務必填入該篇新聞在「今日熱門保險 RSS 新聞列表」中對應的 [ID] 數字（例如: 1, 2, 3）。

插畫畫面清單（image_scene 填編號）：
${NEWS_IMAGE_SCENE_LIST_TEXT}

請務必輸出嚴格 JSON 格式：
{
  "daily_trend": "從今日新聞可看出...",
  "daily_overview": "今日台灣保險市場受政策法規與市場需求影響...",
  "topics": [
    {
      "topic_title": "主題名稱",
      "ai_summary": "主題單段摘要",
      "short_summary": "一句 35 字以內的重點",
      "key_number": "8,100 萬",
      "key_number_label": "農業保險理賠",
      "image_scene": 3,
      "articles": [
        {
          "rss_index": 1,
          "title": "新聞標題",
          "source_name": "媒體名稱",
          "source_url": "連結",
          "article_summary": "單篇新聞 2~3 句摘要內容",
          "is_primary": true
        }
      ]
    }
  ]
}`;

  const staticCandidateModels = [
    'groq/compound',
    'groq/compound-mini',
    'qwen/qwen3.6-27b',
    'openai/gpt-oss-20b',
    'llama-3.3-70b-versatile',
  ];
  const modelErrors: string[] = [];
  const triedModels = new Set<string>();

  // 輔助函式：對指定 Groq 模型發起 Completion 請求
  async function tryModel(modelName: string): Promise<ClusteringOutput | null> {
    triedModels.add(modelName);
    try {
      console.log(`[Groq News Clustering] 嘗試使用模型: ${modelName}...`);
      const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${GROQ_API_KEY.trim()}`,
        },
        body: JSON.stringify({
          model: modelName,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: `今日熱門保險 RSS 新聞列表：\n${formattedItems}` }
          ],
          temperature: 0.2,
          max_tokens: 4096,
        }),
      });

      if (!res.ok) {
        const errText = await res.text();
        console.error(`[Groq ${modelName} Error]:`, res.status, errText);
        modelErrors.push(`[${modelName} HTTP ${res.status}] ${errText}`);
        return null;
      }

      const resData = await res.json();
      const content = resData.choices?.[0]?.message?.content || '';

      let parsed: any;
      try {
        parsed = JSON.parse(content);
      } catch {
        const jsonMatch = content.match(/\{[\s\S]*\}/);
        if (jsonMatch) parsed = JSON.parse(jsonMatch[0]);
      }

      if (parsed && (parsed.topics || parsed.items || parsed.news)) {
        const rawTopics = parsed.topics || parsed.items || parsed.news || [];
        if (Array.isArray(rawTopics) && rawTopics.length > 0) {
          return {
            daily_trend: parsed.daily_trend || '從今日新聞可看出保險市場法規與產品結構正積極調整。',
            daily_overview: parsed.daily_overview || '今日保險產業新聞涵蓋主管機關政策宣導、商品轉型與社會熱點。',
            topics: rawTopics,
          };
        }
      }
    } catch (err: any) {
      console.error(`[Groq Catch Error ${modelName}]:`, err);
      modelErrors.push(`[${modelName} Exception] ${err.message || String(err)}`);
    }
    return null;
  }

  // 第一階段：優先嘗試預設靜態候選模型清單
  for (const model of staticCandidateModels) {
    const output = await tryModel(model);
    if (output) return output;
  }

  // 第二階段：【緊急自我修復動態巡檢】
  // 當預設模型皆廢棄/失效時，自動打 API 取得 Groq 在線可用模型清單
  console.warn('⚠️ [Groq Auto-Discovery] 所有靜態候選模型皆無回應或被廢棄，啟動動態 Groq 模型自我修復搜尋...');
  try {
    const modelsRes = await fetch('https://api.groq.com/openai/v1/models', {
      headers: { 'Authorization': `Bearer ${GROQ_API_KEY.trim()}` },
    });

    if (modelsRes.ok) {
      const modelsData = await modelsRes.json();
      const liveModels: any[] = modelsData.data || [];

      // 自動過濾語音(whisper)、安全防護(safeguard/prompt-guard)及特定微調模型，保留文本生成模型
      const discoveredModels = liveModels
        .map((m: any) => m.id as string)
        .filter((id: string) => {
          if (!id) return false;
          if (triedModels.has(id)) return false; // 跳過先前已試過的模型
          const lower = id.toLowerCase();
          const isNonTextModel = lower.includes('whisper') ||
                                 lower.includes('prompt-guard') ||
                                 lower.includes('safeguard') ||
                                 lower.includes('orpheus') ||
                                 lower.includes('vision');
          return !isNonTextModel;
        });

      console.log(`[Groq Dynamic Auto-Discovery] 自動發現 ${discoveredModels.length} 個在線文字模型:`, discoveredModels);

      for (const discoveredModel of discoveredModels) {
        const output = await tryModel(discoveredModel);
        if (output) {
          console.log(`🎉 [Groq Dynamic Auto-Discovery Success] 成功找到最新可替代模型: ${discoveredModel}`);
          return output;
        }
      }
    }
  } catch (discoveryErr: any) {
    console.error('[Groq Auto-Discovery Exception]:', discoveryErr);
    modelErrors.push(`[Auto-Discovery Exception] ${discoveryErr.message || String(discoveryErr)}`);
  }

  throw new Error(`Groq 新聞聚類與模型自我修復解析失敗 (共嘗試 ${triedModels.size} 個模型): ${modelErrors.join(' | ')}`);
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // 伺服器設定不完整時直接停止，避免用錯誤的權限寫入資料庫
  if (!NEWS_CRON_SECRET || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error('[fetch-insurance-news] 缺少 NEWS_CRON_SECRET 或 SUPABASE_SERVICE_ROLE_KEY 環境變數');
    return new Response(
      JSON.stringify({ success: false, error: 'Server configuration error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    );
  }

  // 檢查呼叫者身分：密碼對不上就拒絕，防止任何人用網站公開的金鑰重複觸發、消耗 Groq 額度
  const requestSecret: string = req.headers.get('x-news-cron-secret') ?? '';
  if (requestSecret !== NEWS_CRON_SECRET) {
    return new Response(
      JSON.stringify({ success: false, error: 'Unauthorized' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401 }
    );
  }

  try {
    console.log('[fetch-insurance-news] 開始抓取多源 RSS 新聞 (包含 Google News, 金管會, 金融新聞)...');

    // 多源 RSS 抓取頻道 (3 大關鍵字軌道 + 7 大國內權威媒體頻道，強制限縮在 24h 內 when:1d)
    const rssUrls = [
      // 軌道一：全網保險焦點、壽險、產險與金管會保險局新聞
      'https://news.google.com/rss/search?q=%E4%BF%9D%E9%9A%AA+OR+%E5%A3%BD%E4%BF%9D+OR+%E7%94%A2%E4%BF%9D+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',
      'https://news.google.com/rss/search?q=%E9%87%91%E7%AE%A1%E6%9C%83+%E4%BF%9D%E9%9A%AA%E5%B1%80+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',

      // 軌道二：醫療理賠、實支實付與長照險熱勢議題
      'https://news.google.com/rss/search?q=%E9%86%AB%E7%99%82%E9%9A%AA+OR+%E5%AF%A6%E6%94%AF%E7%AF%A6%E4%BF%9D+OR+%E4%BF%9D%E9%9A%AA%E7%90%86%E8%B3%A0+OR+%E9%95%B7%E7%85%A7%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',

      // 軌道三：四大龍頭金控壽險巨頭動態
      'https://news.google.com/rss/search?q=%E5%9C%8B%E6%B3%B0%E4%BA%BA%E5%A3%BD+OR+%E5%AF%8C%E9%82%A6%E4%BA%BA%E5%A3%BD+OR+%E5%8D%97%E5%B1%B1%E4%BA%BA%E5%A3%BD+OR+%E6%96%B0%E5%85%89%E4%BA%BA%E5%A3%BD+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',

      // 軌道四：七大國內權威媒體專屬保險新聞頻道
      'https://news.google.com/rss/search?q=site:cna.com.tw+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',        // 中央通訊社 (CNA)
      'https://news.google.com/rss/search?q=site:cnyes.com+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',        // 鉅亨網 (cnyes)
      'https://news.google.com/rss/search?q=site:ctee.com.tw+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',       // 工商時報 (CTEE)
      'https://news.google.com/rss/search?q=site:udn.com+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',        // 聯合新聞網 (UDN)
      'https://news.google.com/rss/search?q=site:chinatimes.com+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',  // 中時新聞網 (Chinatimes)
      'https://news.google.com/rss/search?q=site:ettoday.net+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',     // ETtoday財經
      'https://news.google.com/rss/search?q=site:mirrormedia.mg+%E4%BF%9D%E9%9A%AA+when:1d&hl=zh-TW&gl=TW&ceid=TW:zh-Hant',   // 鏡週刊理財
    ];

    let allRssItems: RSSItem[] = [];
    for (const url of rssUrls) {
      try {
        const resp = await fetch(url, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
          }
        });
        if (resp.ok) {
          const xml = await resp.text();
          const items = parseRSSXml(xml);
          allRssItems = allRssItems.concat(items);
        } else {
          console.warn(`抓取 RSS 回傳非 200 (${resp.status}): ${url}`);
        }
      } catch (e) {
        console.error(`抓取 RSS 失敗 (${url}):`, e);
      }
    }

    // 依網址或標題去重
    const uniqueItems: RSSItem[] = [];
    const seenTitles = new Set<string>();
    for (const item of allRssItems) {
      const cleanTitle = item.title.replace(/\s+/g, '');
      if (!seenTitles.has(cleanTitle)) {
        seenTitles.add(cleanTitle);
        uniqueItems.push(item);
      }
    }

    console.log(`[fetch-insurance-news] 成功抓取並去重出 ${uniqueItems.length} 條 RSS 新聞`);

    if (uniqueItems.length === 0) {
      // 沒抓到新新聞時，照樣幫今天和昨天缺圖的話題補畫（2026-10-31：連續手動重跑時 RSS 可能暫時抓不到）
      const backfillClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
      const backfilledOnly = await backfillMissingImages(backfillClient);
      return new Response(
        // 沒有新新聞不算失敗（舊新聞照常顯示、插圖照常補），回 200 讓排程顯示成功
        JSON.stringify({ success: true, message: '這次沒有新的新聞，只補畫插圖', topics_count: 0, backfilled_images_count: backfilledOnly }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      );
    }

    // 呼叫 Groq 進行主題聚類、單段摘要與今日大勢趨勢提煉
    console.log('[fetch-insurance-news] 呼叫 Groq AI 聚類歸納與今日大勢趨勢...');
    const result = await clusterNewsWithGroq(uniqueItems);

    // 寫入新聞一律使用伺服器端的 service role 金鑰，不使用呼叫者帶來的 token
    const supabaseClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    // 使用台灣時間 (Asia/Taipei UTC+8) 取得當前正確日期 YYYY-MM-DD，解決 UTC 22:00 (台灣時間 06:00) 日期誤判為前一日之 Bug
    const todayDate = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Taipei' }).format(new Date());

    // 讀取當天已存在之新聞話題（夕報 18:00 追加模式：不刷掉晨報 06:00 已發布話題，而是無縫累加新話題）
    const { data: existingTodayTopics } = await supabaseClient
      .from('insurance_news_topics')
      .select('topic_title')
      .eq('publish_date', todayDate);

    const existingTitleSet = new Set(
      (existingTodayTopics || []).map((t: any) => (t.topic_title || '').replace(/\s+/g, '').toLowerCase())
    );

    let insertedTopicCount = 0;
    let insertedArticleCount = 0;
    let insertedImageCount = 0;
    let lastError = null;

    for (const topic of result.topics) {
      const cleanTopicTitle = (topic.topic_title || '').replace(/\s+/g, '').toLowerCase();
      if (existingTitleSet.has(cleanTopicTitle)) {
        console.log(`[fetch-insurance-news] 當日話題已存在，跳過重複追加: ${topic.topic_title}`);
        continue;
      }
      // 1. 寫入主題表 (包含 daily_trend 與 daily_overview)
      const { data: topicData, error: topicErr } = await supabaseClient
        .from('insurance_news_topics')
        .insert({
          topic_title: topic.topic_title,
          ai_summary: topic.ai_summary,
          short_summary: cleanText(topic.short_summary),
          key_number: cleanText(topic.key_number),
          key_number_label: cleanText(topic.key_number_label),
          daily_trend: result.daily_trend,
          daily_overview: result.daily_overview,
          publish_date: todayDate,
        })
        .select('id')
        .single();

      if (topicErr || !topicData) {
        console.error('寫入 insurance_news_topics 失敗:', topicErr);
        lastError = topicErr;
        continue;
      }

      insertedTopicCount++;
      const topicId = topicData.id;

      // 2. 寫入報導來源表 (相容多元 LLM 鍵名 articles/news/items + 精密網址對照)
      const rawArticles = topic.articles || topic.news || topic.items || topic.news_list || topic.article_list || [];

      if (Array.isArray(rawArticles) && rawArticles.length > 0) {
        const articleRows = rawArticles.map((art: any) => {
          let matchedUrl = '';

          // A) 優先依據 Groq 回傳之 rss_index (相容字串與數字，1-based 轉 0-based 索引)
          const rawIdx = parseInt(String(art.rss_index || ''), 10);
          if (!isNaN(rawIdx) && rawIdx >= 1 && rawIdx <= uniqueItems.length) {
            matchedUrl = uniqueItems[rawIdx - 1].link;
          }

          // B) 若 rss_index 未對中，以新聞標題去除空白進行語意對照
          if (!matchedUrl) {
            const cleanArtTitle = (art.title || '').replace(/\s+/g, '').toLowerCase();
            const foundItem = uniqueItems.find((item) => {
              const cleanItemTitle = (item.title || '').replace(/\s+/g, '').toLowerCase();
              return cleanItemTitle.includes(cleanArtTitle) || cleanArtTitle.includes(cleanItemTitle);
            });
            if (foundItem) {
              matchedUrl = foundItem.link;
            }
          }

          // C) 若 Groq 回傳之 source_url 存在且不為通用首頁，作為三級對照
          if (!matchedUrl && art.source_url && art.source_url.trim().length > 0) {
            const rawUrl = art.source_url.trim();
            const isGenericHome = rawUrl === 'https://news.google.com' ||
                rawUrl === 'https://news.google.com/' ||
                rawUrl === 'https://news.google.com/news';
            if (!isGenericHome) {
              matchedUrl = rawUrl;
            }
          }

          // D) 備援：若無有效文章連結，拿標題做關鍵字對照
          if (!matchedUrl) {
            matchedUrl = uniqueItems[0]?.link || '';
          }

          const articleRow: any = {
            topic_id: topicId,
            title: art.title || topic.topic_title,
            source_name: art.source_name || '權威媒體',
            source_url: matchedUrl,
            is_primary: art.is_primary ?? false,
            published_at: new Date().toISOString(),
          };

          if (art.article_summary && art.article_summary.trim().length > 0) {
            articleRow.article_summary = art.article_summary.trim();
          }

          return articleRow;
        });

        const { error: artErr } = await supabaseClient
          .from('insurance_news_articles')
          // 同一篇報導（同網址）之前抓過就跳過，不讓整個話題的報導都寫入失敗（2026-10-31 紀錄看到 23505）
          .upsert(articleRows, { onConflict: 'source_url', ignoreDuplicates: true });

        if (artErr) {
          console.error(`寫入 topic (${topicId}) 的報導失敗:`, artErr);
          lastError = artErr;
        } else {
          insertedArticleCount += articleRows.length;
        }
      }

      // 報導都是之前抓過的（全部被跳過）＝這個話題沒有新內容：刪掉，不留「0 家報導」的空話題、也不浪費畫圖額度
      const { count: articleCount } = await supabaseClient
        .from('insurance_news_articles')
        .select('id', { count: 'exact', head: true })
        .eq('topic_id', topicId);
      if (!articleCount) {
        console.log(`[fetch-insurance-news] 話題沒有新報導，刪除: ${topic.topic_title}`);
        await supabaseClient.from('insurance_news_topics').delete().eq('id', topicId);
        insertedTopicCount--;
        continue;
      }

      // 畫插圖；失敗不影響新聞本身
      if (await generateTopicImage(supabaseClient, topicId, todayDate, sceneFor(topic.image_scene, topic.topic_title))) {
        insertedImageCount++;
      }
    }

    // 新話題畫完後，補畫今天和昨天還沒有圖的話題
    const backfilledImageCount = await backfillMissingImages(supabaseClient);

    return new Response(
      JSON.stringify({
        success: true,
        message: `成功完成新聞聚類與今日大勢更新！`,
        date: todayDate,
        daily_trend: result.daily_trend,
        topics_count: insertedTopicCount,
        articles_count: insertedArticleCount,
        images_count: insertedImageCount,
        backfilled_images_count: backfilledImageCount,
        last_error: lastError,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (err: any) {
    console.error('[fetch-insurance-news Exception]:', err);
    return new Response(
      JSON.stringify({ success: false, error: err.message || String(err) }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    );
  }
});
