import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';
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


async function transcribeWithGroq(audioBase64: string): Promise<{ text: string | null; err?: string }> {
  if (!GROQ_API_KEY) return { text: null, err: 'GROQ_API_KEY 未在 Supabase Secrets 中設定' };
  
  try {
    // 1. 將 base64 轉為 Uint8Array
    const binaryStr = atob(audioBase64);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    // 2. 建立標準 File 物件 (Deno 支援)
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
      console.error('Groq error:', res.status, resText);
      return { text: null, err: `[Groq ${res.status}]: ${resText}` };
    }
  } catch (e) {
    console.error('Groq catch:', e);
    return { text: null, err: `Groq catch: ${e}` };
  }
}

async function transcribeWithGemini(audioBase64: string, mimeType: string): Promise<{ text: string | null; err?: string }> {
  if (!GEMINI_API_KEY) return { text: null, err: 'GEMINI_API_KEY 未設定' };
  
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY.trim()}`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            role: 'user',
            parts: [
              {
                inline_data: {
                  mime_type: mimeType,
                  data: audioBase64,
                },
              },
              {
                text: `你是一位保險業務員的智慧語音助理。請將以下語音內容轉錄為繁體中文文字。
若有多項重要資訊，請以「•」開頭條列呈現。保留原始說話的完整資訊，不需要額外解釋。`,
              },
            ],
          },
        ],
        generationConfig: { temperature: 0.1 },
      }),
    });

    const resText = await res.text();
    if (res.ok) {
      const data = JSON.parse(resText);
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? null;
      return { text };
    } else {
      return { text: null, err: `[Gemini ${res.status}]: ${resText}` };
    }
  } catch (e) {
    return { text: null, err: `Gemini catch: ${e}` };
  }
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    if (!authHeader || !supabaseUrl || !supabaseAnonKey) {
      return new Response(JSON.stringify({ error: '未授權請求' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    const client = createClient(supabaseUrl, supabaseAnonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: authError } = await client.auth.getUser(authHeader.replace(/^Bearer\s+/i, ''));
    if (authError || !user) {
      return new Response(JSON.stringify({ error: '未授權請求' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    const { audioBase64, mimeType } = await req.json();

    if (!audioBase64) {
      return new Response(
        JSON.stringify({ error: '缺少音訊資料 (audioBase64)' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const resolvedMimeType = mimeType || 'audio/webm';

    // 優先 1：Groq Whisper
    const groqResult = await transcribeWithGroq(audioBase64);
    if (groqResult.text) {
      return new Response(
        JSON.stringify({ transcript: toTraditional(groqResult.text), engine: 'Groq-Whisper' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 優先 2：Gemini 2.0 Flash
    const geminiResult = await transcribeWithGemini(audioBase64, resolvedMimeType);
    if (geminiResult.text) {
      return new Response(
        JSON.stringify({ transcript: toTraditional(geminiResult.text), engine: 'Gemini-2.0-Flash' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 回傳包含 Groq 與 Gemini 兩者的診斷原因
    return new Response(
      JSON.stringify({
        error: '語音轉錄暫時無法使用，請稍後再試。',
      }),
      { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Edge Function internal error:', error);
    return new Response(
      JSON.stringify({ error: '伺服器處理失敗，請稍後再試。' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
