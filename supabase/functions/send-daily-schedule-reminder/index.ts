import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import nodemailer from "npm:nodemailer@6.9.10";

// ---------------------------------------------------------------------------
// 每日行程提醒信（規劃見交接檔「段 2」）
// 1. 支援測試模式（action: "test"）：驗證 Gmail 465 埠與信件樣板
// 2. 正式排程模式：由 pg_cron 每整點呼叫，找出「選了這個時間且開啟提醒」的人
// 3. 客戶姓名去識別化保護：劉先生 / 王小姐 / 劉客戶 / 客戶拜訪
// 4. 純白話乾淨版面：只放 時間、行程標題、地點、客戶稱呼；不放個資與備註
// ---------------------------------------------------------------------------

const GMAIL_SMTP_USER = Deno.env.get("GMAIL_SMTP_USER") ?? "";
const GMAIL_SMTP_PASS = Deno.env.get("GMAIL_SMTP_PASS") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const REMINDER_CRON_SECRET = Deno.env.get("REMINDER_CRON_SECRET") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-reminder-cron-secret",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/// 客戶稱呼去識別化（依交接檔 4-3b 規範）
function formatCustomerName(name?: string | null, gender?: string | null): string {
  if (!name || !name.trim()) return "";
  const trimmed = name.trim();

  // 公司名或機構判斷：超過 4 個字，或包含行號字詞
  const companyKeywords = ["公司", "行", "社", "處", "組", "部", "店", "坊", "廠", "館", "會", "局", "院"];
  const isCompany = trimmed.length > 4 || companyKeywords.some((kw) => trimmed.includes(kw));
  if (isCompany) {
    return "客戶拜訪";
  }

  // 取姓氏（第一個字）
  const surname = trimmed.charAt(0);
  if (gender === "male") {
    return `${surname}先生`;
  }
  if (gender === "female") {
    return `${surname}小姐`;
  }
  // 未填性別：姓氏 + 客戶（不用圈圈）
  return `${surname}客戶`;
}

/// 格式化台北時間
function formatTaipeiTime(isoString: string): string {
  try {
    const d = new Date(isoString);
    return new Intl.DateTimeFormat("zh-TW", {
      timeZone: "Asia/Taipei",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(d);
  } catch (_) {
    return "";
  }
}

/// 產生漂亮的 HTML 行程通知信
function buildEmailHtml(params: {
  agentName: string;
  isTodayMode: boolean;
  dateLabel: string;
  weekdayLabel: string;
  events: Array<{
    title: string;
    startAt: string;
    endAt: string;
    location?: string | null;
    customerLabel: string;
  }>;
}): string {
  const modeTitle = params.isTodayMode ? "今日行程提醒" : "明日行程預告";
  const salutation = params.isTodayMode ? "早安" : "晚安";
  const greeting = `${salutation}，${params.agentName || "夥伴"}！這是你${params.isTodayMode ? "今天" : "明天"}的拜訪行程摘要：`;

  let eventListHtml = "";
  if (params.events.length === 0) {
    eventListHtml = `
      <div style="background-color: #f8fafc; border: 1px dashed #cbd5e1; border-radius: 8px; padding: 24px; text-align: center; color: #64748b;">
        <p style="margin: 0; font-size: 15px;">🌟 ${params.isTodayMode ? "今天" : "明天"}目前沒有排定行程，祝你有順心充實的一天！</p>
      </div>
    `;
  } else {
    eventListHtml = params.events
      .map((e, index) => {
        const timeRange = `${formatTaipeiTime(e.startAt)} - ${formatTaipeiTime(e.endAt)}`;
        const customerBadge = e.customerLabel
          ? `<span style="background: #e0f2fe; color: #0369a1; padding: 2px 8px; border-radius: 4px; font-size: 12px; margin-left: 8px;">${e.customerLabel}</span>`
          : "";
        const locationRow = e.location
          ? `<div style="color: #64748b; font-size: 13px; margin-top: 4px;">📍 ${e.location}</div>`
          : "";

        return `
        <div style="background: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px 16px; margin-bottom: 12px; border-left: 4px solid #0284c7;">
          <div style="display: flex; align-items: center; justify-content: space-between;">
            <div style="font-size: 13px; font-weight: 600; color: #0284c7;">⏰ ${timeRange}</div>
          </div>
          <div style="font-size: 16px; font-weight: 600; color: #1e293b; margin-top: 6px;">
            ${e.title} ${customerBadge}
          </div>
          ${locationRow}
        </div>
      `;
      })
      .join("");
  }

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 20px 0; background-color: #f1f5f9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Noto Sans TC', sans-serif;">
      <div style="max-width: 580px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05); border: 1px solid #e2e8f0;">
        
        <!-- 頂部標題列 -->
        <div style="background: linear-gradient(135deg, #0284c7 0%, #0369a1 100%); padding: 24px; color: #ffffff;">
          <div style="font-size: 13px; text-transform: uppercase; letter-spacing: 1px; opacity: 0.9;">經選助手 • 智能秘書</div>
          <h1 style="margin: 6px 0 0 0; font-size: 22px; font-weight: 700;">${modeTitle}</h1>
          <div style="margin-top: 6px; font-size: 14px; opacity: 0.9;">📅 ${params.dateLabel}（${params.weekdayLabel}）</div>
        </div>

        <!-- 內容區 -->
        <div style="padding: 24px;">
          <p style="margin: 0 0 18px 0; font-size: 15px; color: #334155;">${greeting}</p>

          ${eventListHtml}

          <!-- 按鈕 -->
          <div style="text-align: center; margin: 28px 0 10px 0;">
            <a href="https://jingxuan-app.vercel.app/home" target="_blank" style="display: inline-block; background-color: #0284c7; color: #ffffff; text-decoration: none; padding: 12px 28px; border-radius: 8px; font-size: 15px; font-weight: 600; box-shadow: 0 2px 4px rgba(2, 132, 199, 0.2);">
              開啟經選助手查看完整行程 →
            </a>
          </div>
        </div>

        <!-- 頁尾 -->
        <div style="background: #f8fafc; padding: 16px 24px; border-top: 1px solid #e2e8f0; text-align: center; font-size: 12px; color: #94a3b8;">
          此郵件為系統定時自動發送 • 客戶資訊已遵循去識別化保護規範 • 請至 App 設定調整提醒偏好
        </div>
      </div>
    </body>
    </html>
  `;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!GMAIL_SMTP_USER || !GMAIL_SMTP_PASS) {
      return jsonResponse(
        {
          error: "未設定 GMAIL_SMTP_USER 或 GMAIL_SMTP_PASS 環境變數",
        },
        500
      );
    }

    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      auth: {
        user: GMAIL_SMTP_USER,
        pass: GMAIL_SMTP_PASS,
      },
    });

    let body: any = {};
    if (req.method === "POST") {
      try {
        body = await req.json();
      } catch (_) {}
    }

    const url = new URL(req.url);
    const isTestMode = body.action === "test" || url.searchParams.get("action") === "test";

    // -------------------------------------------------------------------------
    // 1. 測試模式：發送測試信驗證連線與排版
    // -------------------------------------------------------------------------
    if (isTestMode) {
      const targetEmail = body.test_email || GMAIL_SMTP_USER;
      console.log(`[Reminder] 發送測試信至 ${targetEmail}...`);

      const testHtml = buildEmailHtml({
        agentName: "測試業務員",
        isTodayMode: true,
        dateLabel: "2026 年 11 月 01 日",
        weekdayLabel: "星期日",
        events: [
          {
            title: "保單年度檢視與家庭保障諮詢",
            startAt: new Date().toISOString(),
            endAt: new Date(Date.now() + 3600000).toISOString(),
            location: "台北市信義區松壽路 1 號星巴克",
            customerLabel: "陳先生",
          },
          {
            title: "新契約簽署與文件點收",
            startAt: new Date(Date.now() + 7200000).toISOString(),
            endAt: new Date(Date.now() + 10800000).toISOString(),
            location: "國泰世華銀行總行會議室",
            customerLabel: "林小姐",
          },
        ],
      });

      const info = await transporter.sendMail({
        from: `"經選助手" <${GMAIL_SMTP_USER}>`,
        to: targetEmail,
        subject: "【經選助手】每日行程提醒：465 埠排版測試信",
        html: testHtml,
      });

      return jsonResponse({
        success: true,
        message: `測試信已成功寄出至 ${targetEmail}`,
        messageId: info.messageId,
      }, 200);
    }

    // -------------------------------------------------------------------------
    // 2. 排程模式：由 pg_cron 每整點觸發，檢查當前台北時間該寄給誰
    // -------------------------------------------------------------------------
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return jsonResponse({ error: "未設定 SUPABASE_URL 或 SUPABASE_SERVICE_ROLE_KEY" }, 500);
    }

    // 驗證排程呼叫安全密碼（若有設定 REMINDER_CRON_SECRET）
    if (REMINDER_CRON_SECRET) {
      const authHeader = req.headers.get("x-reminder-cron-secret");
      if (authHeader !== REMINDER_CRON_SECRET && body.cron_secret !== REMINDER_CRON_SECRET) {
        return jsonResponse({ error: "未經授權的排程呼叫" }, 401);
      }
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 計算當前台北時間（UTC+8）
    const nowUtc = new Date();
    const taipeiDateObj = new Date(nowUtc.getTime() + 8 * 3600 * 1000);

    const taipeiHourStr = body.target_hour || `${String(taipeiDateObj.getUTCHours()).padStart(2, "0")}:00`;
    console.log(`[Reminder] 正在處理台北時間 [${taipeiHourStr}] 的行程提醒排程...`);

    // 判斷此時段為「今天早上」還是「前一晚看明天」
    const hourNum = parseInt(taipeiHourStr.split(":")[0], 10);
    const isTodayMode = hourNum < 12; // 早上模式看今天；晚上模式（>=12）看明天

    // 計算目標日期的起訖時間（台北時間該日的 00:00:00 至 23:59:59）
    const targetDateObj = new Date(taipeiDateObj);
    if (!isTodayMode) {
      // 晚上模式加一天看明天
      targetDateObj.setUTCDate(targetDateObj.getUTCDate() + 1);
    }

    const year = targetDateObj.getUTCFullYear();
    const month = targetDateObj.getUTCMonth();
    const date = targetDateObj.getUTCDate();

    // 台北時間 00:00:00 相當於 UTC 前一天 16:00:00
    const startRangeUtc = new Date(Date.UTC(year, month, date, 0, 0, 0) - 8 * 3600 * 1000);
    const endRangeUtc = new Date(Date.UTC(year, month, date, 23, 59, 59, 999) - 8 * 3600 * 1000);

    const weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"];
    const weekdayLabel = weekdays[targetDateObj.getUTCDay()];
    const dateLabel = `${year} 年 ${String(month + 1).padStart(2, "0")} 月 ${String(date).padStart(2, "0")} 日`;

    // 撈取「開啟提醒」且「時間符合」的業務員
    const { data: users, error: userError } = await supabaseAdmin
      .from("profiles")
      .select("id, full_name, email, schedule_reminder_time")
      .eq("schedule_reminder_enabled", true)
      .eq("schedule_reminder_time", taipeiHourStr);

    if (userError) {
      console.error("[Reminder] 查詢使用者失敗:", userError);
      return jsonResponse({ error: userError.message }, 500);
    }

    if (!users || users.length === 0) {
      console.log(`[Reminder] 時段 ${taipeiHourStr} 無任何開啟提醒的使用者。`);
      return jsonResponse({
        success: true,
        message: `時段 ${taipeiHourStr} 無需發送提醒`,
        processed: 0,
      }, 200);
    }

    let sentCount = 0;
    const errors: any[] = [];

    for (const user of users) {
      if (!user.email) continue;

      try {
        // 撈取該使用者的當日行程
        const { data: events, error: eventError } = await supabaseAdmin
          .from("schedule_events")
          .select("id, title, start_at, end_at, location, customer_id")
          .eq("profile_id", user.id)
          .is("deleted_at", null)
          .gte("start_at", startRangeUtc.toISOString())
          .lte("start_at", endRangeUtc.toISOString())
          .order("start_at", { ascending: true });

        if (eventError) {
          console.error(`[Reminder] 撈取使用者 ${user.id} 行程失敗:`, eventError);
          continue;
        }

        // 整理客戶稱呼
        const formattedEvents: any[] = [];
        for (const evt of events || []) {
          let customerLabel = "";
          if (evt.customer_id) {
            const { data: customer } = await supabaseAdmin
              .from("customers")
              .select("name, gender")
              .eq("id", evt.customer_id)
              .maybeSingle();

            if (customer) {
              customerLabel = formatCustomerName(customer.name, customer.gender);
            }
          }

          formattedEvents.push({
            title: evt.title,
            startAt: evt.start_at,
            endAt: evt.end_at,
            location: evt.location,
            customerLabel,
          });
        }

        const emailHtml = buildEmailHtml({
          agentName: user.full_name || "夥伴",
          isTodayMode,
          dateLabel,
          weekdayLabel,
          events: formattedEvents,
        });

        const subjectMode = isTodayMode ? "今日行程提醒" : "明日行程預告";
        await transporter.sendMail({
          from: `"經選助手" <${GMAIL_SMTP_USER}>`,
          to: user.email,
          subject: `【經選助手】${subjectMode}（${month + 1}/${date}）`,
          html: emailHtml,
        });

        sentCount++;
        console.log(`[Reminder] 已成功寄送行程提醒至 ${user.email}`);
      } catch (err: any) {
        console.error(`[Reminder] 發送給 ${user.email} 失敗:`, err);
        errors.push({ email: user.email, error: String(err) });
      }
    }

    return jsonResponse({
      success: true,
      hour: taipeiHourStr,
      targetDate: dateLabel,
      totalUsers: users.length,
      sentCount,
      errors,
    }, 200);

  } catch (error: any) {
    console.error("[Reminder] 執行失敗:", error);
    return jsonResponse({
      success: false,
      error: error.message || String(error),
    }, 500);
  }
});
