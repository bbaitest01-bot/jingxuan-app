import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ---------------------------------------------------------------------------
// 繁體中文保險（問題 S5，2026-10-14）
// Whisper 已用 prompt 引導輸出繁體，這裡再用固定對照表把漏網的簡體字轉成繁體（不經過 AI）。
// 只收「不會出現在正常繁體文字裡」的簡體字；一字多義的（例如 钟、周、里、发型）用詞組處理或不轉。
// transcribe-voice 與 voice-scheduler 各有一份相同的表（後台貼程式部署，不共用檔案）。
// ---------------------------------------------------------------------------
const S2T_PHRASES: [string, string][] = [
  ['点钟', '點鐘'], ['钟头', '鐘頭'], ['几点', '幾點'],
  ['周一', '週一'], ['周二', '週二'], ['周三', '週三'], ['周四', '週四'],
  ['周五', '週五'], ['周六', '週六'], ['周日', '週日'], ['周末', '週末'], ['下周', '下週'], ['这周', '這週'],
  ['头发', '頭髮'], ['理发', '理髮'],
];
const S2T_CHAR_PAIRS = '个個们們来來时時点點会會后後见見与與为為这這么麼说說话話门門问問间間开開关關车車东東长長张張陈陳刘劉杨楊黄黃赵趙吴吳郑鄭谢謝许許邓鄧冯馮韩韓叶葉苏蘇卢盧蒋蔣罗羅邹鄒萧蕭简簡钱錢孙孫汤湯庄莊齐齊龙龍经經总總协協专專员員务務业業险險单單寿壽医醫疗療费費赔賠偿償项項规規划劃财財产產资資银銀帐帳账賬签簽约約续續缴繳办辦讨討论論谈談联聯络絡电電讯訊邮郵处處户戶访訪饭飯厅廳楼樓馆館场場区區号號县縣乡鄉镇鎮机機铁鐵动動运運过過还還进進远遠边邊礼禮节節给給让讓请請认認识識记記带帶备備计計学學习習买買卖賣换換报報写寫读讀听聽觉覺应應该該样樣对對错錯实實际際现現发發头頭题題难難欢歡爱愛亲親爷爺妈媽儿兒岁歲体體检檢药藥伤傷护護养養师師诊診马馬鱼魚气氣汇匯网網线線纪紀级級红紅绿綠蓝藍结結统統织織终終细細绍紹绩績劳勞励勵势勢华華卫衛压壓厂廠广廣庆慶闻聞阅閱闭閉贵貴贷貸赚賺购購货貨质質贴貼语語调調谁誰课課设設试試详詳证證评評译譯议議讲講诉訴铺鋪锁鎖镜鏡销銷页頁顺順须須领領预預顾顧颜顏饮飲驾駕验驗鸡雞龄齡农農达達迟遲适適选選递遞陆陸阳陽随隨状狀纸紙众眾从從仅僅传傳优優价價侧側储儲兴興军軍决決况況净淨减減则則刚剛别別劝勸参參双雙变變叹嘆启啟响響围圍团團园園图圖块塊坏壞声聲夺奪奖獎妇婦宝寶宠寵审審宽寬导導尔爾层層属屬岛島帮幫库庫异異弹彈强強归歸当當录錄忆憶怀懷态態恋戀恶惡悦悅惊驚惯慣愿願戏戲战戰扩擴扫掃抢搶担擔拥擁择擇挂掛据據携攜摄攝数數断斷无無旧舊显顯晒曬暂暫术術权權条條极極构構标標树樹桥橋毕畢汉漢没沒沟溝济濟浅淺测測满滿灯燈灵靈热熱独獨环環画畫畅暢盖蓋盘盤码碼确確种種积積称稱稳穩竞競笔筆类類紧緊纳納练練组組继繼维維综綜缘緣罚罰职職聪聰肠腸肤膚肿腫胜勝胆膽脑腦脚腳脸臉艺藝荐薦获獲营營虑慮虽雖补補装裝观觀视視览覽订訂训訓词詞诚誠询詢误誤谱譜贝貝负負责責败敗赛賽赶趕趋趨轮輪软軟轻輕载載较較辅輔辆輛输輸违違连連邻鄰释釋针針钢鋼链鏈锅鍋键鍵闪閃闲閒闹鬧队隊阶階隐隱雾霧顶頂顿頓颗顆风風飞飛饱飽饿餓骑騎骗騙鲜鮮鸟鳥麦麥湾灣云雲灾災宁寧盐鹽烦煩烧燒弃棄废廢庙廟厕廁厦廈侨僑挤擠尝嘗扬揚';
const S2T_CHAR_MAP: Map<string, string> = new Map();
for (let i = 0; i + 1 < S2T_CHAR_PAIRS.length; i += 2) {
  S2T_CHAR_MAP.set(S2T_CHAR_PAIRS[i], S2T_CHAR_PAIRS[i + 1]);
}

function toTraditional(text: string): string {
  let result = text;
  for (const [simplified, traditional] of S2T_PHRASES) {
    result = result.split(simplified).join(traditional);
  }
  let converted = '';
  for (const char of result) {
    converted += S2T_CHAR_MAP.get(char) ?? char;
  }
  return converted;
}

// 給 Whisper 的提示句：用繁體中文示範，引導辨識結果輸出繁體
const WHISPER_TRADITIONAL_PROMPT = '以下是繁體中文的保險業務行程與客戶紀錄，例如：明天下午三點和王小姐在台北101討論醫療險保單。';


// 1. Groq Whisper (STT) 語音轉錄
async function transcribeWithGroq(audioBase64: string): Promise<{ text: string | null; err?: string }> {
  if (!GROQ_API_KEY) return { text: null, err: 'GROQ_API_KEY 未在 Supabase Secrets 中設定' };
  
  try {
    const binaryStr = atob(audioBase64);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    const file = new File([bytes], 'audio.webm', { type: 'audio/webm' });
    const formData = new FormData();
    formData.append('file', file);
    formData.append('model', 'whisper-large-v3-turbo');
    formData.append('language', 'zh');
    formData.append('prompt', WHISPER_TRADITIONAL_PROMPT);
    formData.append('response_format', 'json');

    const res = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${GROQ_API_KEY.trim()}`,
      },
      body: formData,
    });

    const resText = await res.text();
    if (res.ok) {
      const data = JSON.parse(resText);
      return { text: data.text ?? null };
    } else {
      console.error('Groq STT error:', res.status, resText);
      return { text: null, err: `[Groq STT ${res.status}]: ${resText}` };
    }
  } catch (e) {
    console.error('Groq STT catch:', e);
    return { text: null, err: `Groq STT catch: ${e}` };
  }
}

interface ScheduleParseResult {
  title: string;
  start_at: string;
  end_at: string;
  customer_name: string | null;
  location: string | null;
  is_time_defaulted: boolean;
  is_title_defaulted: boolean;
}

// 動態自 Groq API 獲取當前在線的最新 active chat 模型清單
async function fetchActiveGroqModels(): Promise<string[]> {
  if (!GROQ_API_KEY) return [];
  try {
    const res = await fetch('https://api.groq.com/openai/v1/models', {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${GROQ_API_KEY.trim()}` }
    });
    if (res.ok) {
      const data = await res.json();
      if (Array.isArray(data?.data)) {
        const activeIds: string[] = data.data
          .map((m: any) => m.id as string)
          .filter((id: string) => 
            !id.includes('whisper') && 
            !id.includes('safetensors') && 
            !id.includes('guard') &&
            !id.includes('brotli')
          );
        if (activeIds.length > 0) {
          console.log('[Groq Dynamic Models] 成功動態獲取在線 Groq 模型清單:', activeIds);
          return activeIds;
        }
      }
    } else {
      console.warn('[Groq Dynamic Models] 取得模型清單失敗:', res.status, await res.text());
    }
  } catch (e) {
    console.warn('[Groq Dynamic Models] 網路請求異常:', e);
  }
  return ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];
}

// 2. Groq 語意解析 (自適應動態模型輪替)
async function parseScheduleWithGroq(transcript: string, localTime: string): Promise<ScheduleParseResult> {
  if (!GROQ_API_KEY) throw new Error('GROQ_API_KEY 未設定，無法使用 Groq 解析');

  // 動態獲取 Groq 當前線上 active 的所有模型 ID
  const dynamicModels = await fetchActiveGroqModels();
  const models = Array.from(new Set([...dynamicModels, 'llama-3.3-70b-versatile', 'llama-3.1-8b-instant']));
  const errorLogs: string[] = [];

  for (const model of models) {
    try {
      console.log(`[Groq NLU] 嘗試使用動態在線模型: ${model} ...`);
      const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${GROQ_API_KEY.trim()}`,
        },
        body: JSON.stringify({
          model: model,
          messages: [
            {
              role: 'system',
              content: `你是一位智慧行事曆助理。請根據使用者所在基準時間 (localTime)，推算行程的絕對開始時間 (start_at) 與結束時間 (end_at)。
並從語音文字中提取出：行程標題 (title)、提及的客戶姓名或稱謂 (customer_name) 與地點 (location)。

請嚴格遵循以下規則：
1. 輸出必須是嚴格 JSON 格式。不要有 markdown 標記，必須可以直接被 JSON.parse() 解析。
2. JSON 包含以下欄位：
   - title: 行程標題 (如 "與張總在臺北101吃飯" 或 "客戶拜訪")。請精簡提煉，包含人、地點與核心事項，嚴禁原封不動拷貝整句長語音或包含口語時間贅字 (例如: "明天下午5點" 不要放在標題中)。若完全沒提及做什麼或屬於無意義雜音，請設為預設標題 (如 "商務行程")。
   - start_at: 行程開始時間，使用 ISO 8601 格式且必須包含與 localTime 相同的時區偏移量 (例如: "2026-08-04T15:00:00+08:00")。若沒提及具體時間或日期，請預設為 localTime 日期的當天 18:00 (例如: "2026-08-03T18:00:00+08:00")。
   - end_at: 行程結束時間，使用 ISO 8601 格式且必須包含與 localTime 相同的時區偏移量。若未提及持續時間，預設為 start_at 往後推算 1 小時。
   - customer_name: 提到的聯絡客戶姓名或稱謂 (如 "張總", "劉董", "林經理")，若未提及請設為 null。
   - location: 提到的純地點名稱 (如 "臺北101", "星巴克")，請排除動詞與時間詞，若未提及請設為 null。
   - is_time_defaulted: 布林值。若語音中未提及具體日期或時間，因而使用了系統預設時間，請設為 true，否則為 false。
   - is_title_defaulted: 布林值。若語音中未提及明確行程主題，或輸入為無意義詞句/廢話，因而使用了預設標題，請設為 true，否則為 false。
3. 若提及「明天」，代表基準時間的隔天。若提及「後天」，代表基準時間的後兩天。
4. title、customer_name、location 一律使用繁體中文（台灣用語），不可使用簡體字。`
            },
            {
              role: 'user',
              content: `基準時間 (localTime): ${localTime}
行程語音內容: "${transcript}"`
            }
          ],
          temperature: 0.1,
          response_format: { type: 'json_object' }
        })
      });

      const resText = await res.text();
      if (res.ok) {
        const data = JSON.parse(resText);
        const jsonStr = data?.choices?.[0]?.message?.content;
        if (!jsonStr) {
          throw new Error('Groq 語意解析未回傳 choices 內容');
        }
        return JSON.parse(jsonStr) as ScheduleParseResult;
      } else {
        throw new Error(`[${model} ${res.status}]: ${resText}`);
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.warn(`[Groq NLU] 模型 ${model} 呼叫失敗:`, errMsg);
      errorLogs.push(errMsg);
    }
  }

  throw new Error(`所有 Groq 模型均呼叫失敗: ${errorLogs.join(' | ')}`);
}

// ---------------------------------------------------------------------------
// 檢查 AI 結果的小工具（不依賴 AI 自己的判斷）
// ---------------------------------------------------------------------------

// 語音文字裡有沒有提到日期或時間
function hasTimeWords(text: string): boolean {
  return /[0-9０-９一二三四五六七八九十兩]\s*[點點時:：]|上午|下午|中午|晚上|早上|凌晨|傍晚|今天|明天|後天|週|星期|禮拜|[0-9一二三四五六七八九十]+\s*[號日月]/.test(text);
}

// 標題開頭的「明天上午10點」這類時間字拿掉（例：明天上午10點拜訪王測一 → 拜訪王測一）
function removeLeadingTimeWords(title: string): string {
  const trimmed = (title ?? '').trim();
  const leadingTime = /^(今天|明天|後天|大後天|下週.|這週.|週.|星期.|禮拜.)?\s*(早上|上午|中午|下午|傍晚|晚上|凌晨)?\s*([0-9０-９一二三四五六七八九十兩]{1,3}\s*[點時](半|[0-9一二三四五六七八九十]{1,3}分?)?)?\s*[，,、]?\s*/;
  const cleaned = trimmed.replace(leadingTime, '').trim();
  return cleaned || trimmed;
}

// 標題是不是「沒講要做什麼」時的預設值
function isDefaultTitle(title: string): boolean {
  const defaultTitles = ['商務行程', '行程', '客戶拜訪', '新行程', ''];
  return defaultTitles.includes((title ?? '').trim());
}

// 直接從 ISO 字串取「月/日 時:分」，不經過主機時區換算（主機是 UTC，會把 10:00 算成 02:00）
function formatLocalDateTime(isoText: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(isoText ?? '');
  if (!match) return isoText;
  return `${Number(match[2])}/${Number(match[3])} ${match[4]}:${match[5]}`;
}

// 客戶比對：只找自己的客戶。
// 1. 先去掉稱謂（王小姐 → 王）
// 2. 名字或暱稱「完全等於」說出來的稱呼或去掉稱謂後的名字 → 只有一位就帶入
// 3. 否則名字開頭是這個姓／名、或暱稱包含它的客戶 → 剛好一位才帶入；多位就不帶入，回傳候選名單讓使用者自己選
interface CustomerMatchResult {
  id: string | null;
  name: string | null;
  candidateNames: string[];
  // true：全名找不到，candidateNames 是「同姓」的猜測名單（例：王策醫 → 王測一、王測二），只提示不帶入
  isSurnameGuess: boolean;
}

async function matchCustomer(supabaseClient: any, userId: string, spokenName: string): Promise<CustomerMatchResult> {
  const noMatch: CustomerMatchResult = { id: null, name: null, candidateNames: [], isSurnameGuess: false };
  const spoken = spokenName.trim();

  let cleanName = spoken;
  const titleSuffixes = ['副總', '經理', '協理', '專員', '主任', '阿姨', '先生', '小姐', '總', '姐', '哥', '董'];
  for (const suffix of titleSuffixes) {
    if (cleanName.endsWith(suffix) && cleanName.length > suffix.length) {
      cleanName = cleanName.substring(0, cleanName.length - suffix.length);
      break;
    }
  }
  // 拿掉會破壞查詢語法的符號（逗號、括號、萬用字元等）
  cleanName = cleanName.replace(/[,()%*\\.:"'\s]/g, '');
  if (!cleanName) return noMatch;

  const { data: customers, error } = await supabaseClient
    .from('customers')
    .select('id, name, nickname')
    .eq('profile_id', userId)
    .is('deleted_at', null)
    .or(`name.ilike.${cleanName}%,nickname.ilike.%${cleanName}%`)
    .limit(20);

  if (error) {
    console.error('查詢客戶時發生錯誤:', error);
    return noMatch;
  }
  const candidates: { id: string; name: string; nickname: string | null }[] = customers ?? [];
  if (candidates.length === 0) {
    console.log(`[Customer Match] 找不到「${cleanName}」開頭的客戶，改用姓氏提示`);
    return await guessBySurname(supabaseClient, userId, cleanName);
  }

  const exactMatches = candidates.filter((customer) =>
    customer.name === spoken || customer.name === cleanName ||
    customer.nickname === spoken || customer.nickname === cleanName
  );
  if (exactMatches.length === 1) {
    return { id: exactMatches[0].id, name: exactMatches[0].name, candidateNames: [], isSurnameGuess: false };
  }
  if (exactMatches.length === 0 && candidates.length === 1) {
    return { id: candidates[0].id, name: candidates[0].name, candidateNames: [], isSurnameGuess: false };
  }

  const sameNameList = exactMatches.length > 1 ? exactMatches : candidates;
  console.log(`[Customer Match] 「${spoken}」找到 ${sameNameList.length} 位，不自動帶入`);
  return { id: null, name: null, candidateNames: sameNameList.map((customer) => customer.name), isSurnameGuess: false };
}

// 全名找不到時（常見是同音字聽錯，例：王測一 → 王策醫），用第一個字（姓）找同姓客戶當提示，不自動帶入
async function guessBySurname(supabaseClient: any, userId: string, cleanName: string): Promise<CustomerMatchResult> {
  const noMatch: CustomerMatchResult = { id: null, name: null, candidateNames: [], isSurnameGuess: false };
  if (cleanName.length < 2) return noMatch;
  const surname = cleanName.substring(0, 1);

  const { data: customers, error } = await supabaseClient
    .from('customers')
    .select('name')
    .eq('profile_id', userId)
    .is('deleted_at', null)
    .ilike('name', `${surname}%`)
    .limit(20);

  if (error || !customers || customers.length === 0) return noMatch;
  const names: string[] = customers.map((customer: { name: string }) => customer.name);
  return { id: null, name: null, candidateNames: names, isSurnameGuess: true };
}

// 3. Edge Function 進入點
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader || '' } }
    });
    
    const token = authHeader ? authHeader.replace(/^Bearer\s+/i, '').trim() : '';
    if (!token) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    let user: any = null;
    try {
      const { data, error } = await supabaseClient.auth.getUser(token);
      if (error) throw error;
      if (!data.user) throw new Error('no user');
      user = data.user;
    } catch (_) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { audioBase64, transcript, mimeType, localTime } = await req.json();

    if (!audioBase64 && (!transcript || !transcript.trim())) {
      return new Response(
        JSON.stringify({ error: '缺少音訊資料或聽寫文字內容' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!localTime) {
      return new Response(
        JSON.stringify({ error: '缺少基準時間 (localTime)' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 步驟 1：語音轉錄 / 文字取得
    // 有錄音就一律用 Whisper（品質較穩定）；瀏覽器邊聽邊轉的文字只在 Whisper 失敗或沒有錄音時備用
    const browserTranscript = (transcript && typeof transcript === 'string') ? transcript.trim() : '';
    let transcriptText = '';

    if (audioBase64) {
      const groqResult = await transcribeWithGroq(audioBase64);
      if (groqResult.text && groqResult.text.trim()) {
        transcriptText = groqResult.text.trim();
      } else if (browserTranscript) {
        console.warn('Groq STT 失敗，改用瀏覽器辨識文字:', groqResult.err);
        transcriptText = browserTranscript;
      } else {
        console.error('Groq STT 失敗:', groqResult.err);
        return new Response(
          JSON.stringify({
            error: '語音辨識失敗，請確認麥克風運作正常且音訊清晰。',
            details: { groq: groqResult.err }
          }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    } else {
      transcriptText = browserTranscript;
    }

    // 簡體字保險轉換（S5）
    transcriptText = toTraditional(transcriptText);
    console.log(`[STT / Text] 待解析內容: "${transcriptText}"`);

    // 步驟 2：語意提取 (使用 Groq 自適應)
    let parsedResult: ScheduleParseResult;
    try {
      console.log('嘗試使用 Groq 自適應模型進行語意解析...');
      parsedResult = await parseScheduleWithGroq(transcriptText, localTime);
      console.log('[NLU] Groq-Adaptive-Llama 解析成功:', parsedResult);
      parsedResult.title = toTraditional(parsedResult.title ?? '');
      if (parsedResult.location) parsedResult.location = toTraditional(parsedResult.location);
      if (parsedResult.customer_name) parsedResult.customer_name = toTraditional(parsedResult.customer_name);
      // AI 的「沒講時間／沒講標題」判斷不穩定，改由程式檢查（2026-10-14 沛沛測試發現）
      parsedResult.title = removeLeadingTimeWords(parsedResult.title);
      parsedResult.is_time_defaulted = parsedResult.is_time_defaulted && !hasTimeWords(transcriptText);
      parsedResult.is_title_defaulted = isDefaultTitle(parsedResult.title);
      if (!parsedResult.title) parsedResult.title = '商務行程';
    } catch (groqNluError) {
      console.error('Groq 語意分析失敗:', groqNluError);
      return new Response(
        JSON.stringify({
          error: '行程智慧解析失敗，請確認 Groq API 金鑰配置無誤。',
          details: { groq: groqNluError instanceof Error ? groqNluError.message : groqNluError }
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 步驟 3：比對客戶（S17，2026-10-14 沛沛決定 A 方案）
    const customerMatch = parsedResult.customer_name
      ? await matchCustomer(supabaseClient, user.id, parsedResult.customer_name)
      : { id: null, name: null, candidateNames: [] as string[], isSurnameGuess: false };
    const matchedCustomerId: string | null = customerMatch.id;
    const matchedCustomerName: string | null = customerMatch.name;

    // 判定紅黃綠燈狀態與警示訊息
    let status = 'green';
    const warningMessages: string[] = [];

    if (parsedResult.is_time_defaulted) {
      status = 'yellow';
      warningMessages.push(`沒有聽到行程時間，已先排在 ${formatLocalDateTime(parsedResult.start_at)}，請確認`);
    }

    if (parsedResult.is_title_defaulted) {
      status = 'yellow';
      warningMessages.push(`沒有聽到要做什麼，標題先填「${parsedResult.title}」，請修改`);
    }

    if (parsedResult.customer_name && !matchedCustomerId) {
      status = 'yellow';
      const candidateCount = customerMatch.candidateNames.length;
      const preview = customerMatch.candidateNames.slice(0, 3).join('、');
      const more = candidateCount > 3 ? '…' : '';
      if (customerMatch.isSurnameGuess) {
        warningMessages.push(`找不到「${parsedResult.customer_name}」，你是不是要找：${preview}${more}？請在「關聯客戶」中選擇`);
      } else if (candidateCount > 1) {
        warningMessages.push(`「${parsedResult.customer_name}」找到 ${candidateCount} 位客戶（${preview}${more}），請在「關聯客戶」中選擇`);
      } else {
        warningMessages.push(`找不到聯絡人「${parsedResult.customer_name}」，請在「關聯客戶」中選擇或留空`);
      }
    }

    const eventType = matchedCustomerId ? 'meeting' : 'personal';

    // 只辨識、不存檔（S18）：回傳填好內容的「新行程」，使用者在編輯視窗按儲存才寫入資料庫
    const draftEvent = {
      id: '',
      profile_id: user.id,
      customer_id: matchedCustomerId,
      title: parsedResult.title,
      start_at: parsedResult.start_at,
      end_at: parsedResult.end_at,
      location: parsedResult.location,
      // 完整的語音文字放進備註，標題只放精簡重點
      description: transcriptText,
      event_type: eventType,
      is_completed: false,
    };
    console.log('[Draft Event] 辨識結果（尚未存檔）:', draftEvent);

    return new Response(
      JSON.stringify({
        success: true,
        status: status,
        warning_messages: warningMessages,
        transcript: transcriptText,
        nluEngine: 'Groq-Adaptive-Llama',
        event: draftEvent,
        matchedCustomer: matchedCustomerName ? { id: matchedCustomerId, name: matchedCustomerName } : null
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Edge Function 內部錯誤:', error);
    return new Response(
      JSON.stringify({ error: `伺服器內部錯誤: ${error instanceof Error ? error.message : error}` }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
