-- ============================================================================
-- 示範帳號假資料（2026-10-30，給保險業主管試用與新手教學）
--
-- 用途：demo1、demo2 兩個示範帳號放一模一樣的假資料，兩位主管各用一個，互不影響。
-- 重置：這一份可以重複執行。每次執行都會「先清空這兩個帳號的資料，再放回原本的假資料」；
--       日期以執行當天為準（例：行程永遠是「今天」「明天」），所以重置後畫面是新的。
--       只想重置其中一個帳號：把下面 demo_emails 裡另一個刪掉再執行。
-- 安全：只處理 @jingxuan.test 結尾的帳號；名字、電話、信箱全部虛構（0900-000-xxx、@example.com）。
-- 前提：先在 Supabase → Authentication → Users 建好 demo1@jingxuan.test、demo2@jingxuan.test。
-- 執行：Supabase SQL Editor 整份貼上 → Run；最後會列出每個帳號的筆數。
-- ============================================================================

CREATE TEMP TABLE IF NOT EXISTS demo_customer_ids (customer_name TEXT PRIMARY KEY, id UUID NOT NULL);
CREATE TEMP TABLE IF NOT EXISTS demo_record_ids (title TEXT PRIMARY KEY, id UUID NOT NULL);

DO $$
DECLARE
  demo_emails TEXT[] := ARRAY['demo1@jingxuan.test', 'demo2@jingxuan.test'];
  demo_email TEXT;
  demo_user_id UUID;
  today_local TIMESTAMP := date_trunc('day', now() AT TIME ZONE 'Asia/Taipei');
  daily_project_id UUID;
  checkup_project_id UUID;
  newborn_project_id UUID;
  identity_category_id UUID;
  insurance_category_id UUID;
  interest_category_id UUID;
  health_category_id UUID;
  followup_category_id UUID;
BEGIN
  FOREACH demo_email IN ARRAY demo_emails LOOP
    -- 只准處理示範帳號，避免誤刪真的業務員資料
    IF demo_email NOT LIKE '%@jingxuan.test' THEN
      RAISE EXCEPTION '只能處理 @jingxuan.test 的示範帳號：%', demo_email;
    END IF;
    SELECT id INTO demo_user_id FROM auth.users WHERE email = demo_email;
    IF demo_user_id IS NULL THEN
      RAISE NOTICE '找不到 %，請先在 Authentication 建立帳號；這個帳號先跳過', demo_email;
      CONTINUE;
    END IF;

    -- 1. 清空舊資料（客戶刪掉時，保單、保障目標、關係、提醒會一起刪）
    DELETE FROM public.notifications WHERE profile_id = demo_user_id;
    DELETE FROM public.visit_results WHERE profile_id = demo_user_id;
    -- 「日常拜訪」是預設專案，資料庫規定不能刪，所以保留、只刪其他專案
    DELETE FROM public.visit_projects WHERE profile_id = demo_user_id AND NOT is_default;
    DELETE FROM public.schedule_events WHERE profile_id = demo_user_id;
    DELETE FROM public.visit_records WHERE profile_id = demo_user_id;
    DELETE FROM public.customer_relationships WHERE user_id = demo_user_id;
    DELETE FROM public.visit_logs WHERE user_id = demo_user_id;
    DELETE FROM public.customers WHERE profile_id = demo_user_id;
    DELETE FROM public.user_tag_categories WHERE profile_id = demo_user_id;
    TRUNCATE demo_customer_ids;
    TRUNCATE demo_record_ids;
    -- 新手導覽「看過了」的紀錄清掉，主管第一次登入會自動跳出導覽（2026-11-01）
    UPDATE auth.users
    SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) - 'onboarding_tour_seen'
    WHERE id = demo_user_id;

    -- 2. 業務員本人（個人帳號、名片）；權限一律是一般業務員
    UPDATE public.profiles SET
      full_name = '林示範',
      role = 'agent',
      status = 'active',
      phone = '0900-000-001',
      company = '經選保險經紀人',
      job_title = '資深業務經理',
      website = 'https://example.com',
      address = '台北市信義區示範路 100 號',
      bio = '從業 8 年，專長家庭保障規劃與醫療險健檢。相信保險是讓家人安心的承諾。',
      line_id = 'demo_lin',
      license_no = 'DEMO-000001',
      honor_title = '家庭保障規劃顧問',
      badges = ARRAY['壽險管理人員', '外幣保單證照', '投資型保險證照'],
      updated_at = now()
    WHERE id = demo_user_id;

    -- 3. 標籤分類與標籤（帳號專屬）
    INSERT INTO public.user_tag_categories (profile_id, name, color_hex, sort_order) VALUES (demo_user_id, '客戶身分', '#0369A1', 1) RETURNING id INTO identity_category_id;
    INSERT INTO public.user_tag_categories (profile_id, name, color_hex, sort_order) VALUES (demo_user_id, '已購險種', '#15803D', 2) RETURNING id INTO insurance_category_id;
    INSERT INTO public.user_tag_categories (profile_id, name, color_hex, sort_order) VALUES (demo_user_id, '生活興趣', '#B45309', 3) RETURNING id INTO interest_category_id;
    INSERT INTO public.user_tag_categories (profile_id, name, color_hex, sort_order) VALUES (demo_user_id, '健康與體況', '#BE123C', 4) RETURNING id INTO health_category_id;
    INSERT INTO public.user_tag_categories (profile_id, name, color_hex, sort_order) VALUES (demo_user_id, '跟進狀態', '#6B21A8', 5) RETURNING id INTO followup_category_id;
    INSERT INTO public.user_tags (profile_id, category_id, name) VALUES
      (demo_user_id, identity_category_id, '青年(18-35)'), (demo_user_id, identity_category_id, '中年(36-60)'),
      (demo_user_id, identity_category_id, '樂齡(60+)'), (demo_user_id, identity_category_id, '高資產'),
      (demo_user_id, identity_category_id, '新手爸媽'), (demo_user_id, identity_category_id, '公司負責人'),
      (demo_user_id, identity_category_id, '醫療從業'),
      (demo_user_id, insurance_category_id, '醫療險'), (demo_user_id, insurance_category_id, '意外險'),
      (demo_user_id, insurance_category_id, '防癌險'), (demo_user_id, insurance_category_id, '壽險'),
      (demo_user_id, insurance_category_id, '長照險'),
      (demo_user_id, interest_category_id, '露營'), (demo_user_id, interest_category_id, '高爾夫'),
      (demo_user_id, interest_category_id, '爬山'), (demo_user_id, interest_category_id, '咖啡'),
      (demo_user_id, health_category_id, '健康'), (demo_user_id, health_category_id, '高血壓'),
      (demo_user_id, followup_category_id, '高意願'), (demo_user_id, followup_category_id, '定期聯繫'),
      (demo_user_id, followup_category_id, '觀望中'), (demo_user_id, followup_category_id, '轉介紹');

    -- 4. 客戶 18 位＋垃圾桶 2 位（保戶、跟進中、未開發由保單、行程、拜訪結果自動判斷）
    WITH inserted AS (
      INSERT INTO public.customers (profile_id, name, nickname, gender, phone, email, tags, notes, client_status, custom_attributes, created_at, deleted_at)
      SELECT demo_user_id, v.name, v.nickname, v.gender, v.phone, v.email, v.tags, v.notes, v.status, '{}'::jsonb,
             now() - make_interval(days => v.created_days_ago),
             CASE WHEN v.deleted_days_ago IS NULL THEN NULL ELSE now() - make_interval(days => v.deleted_days_ago) END
      FROM (VALUES
        -- 保戶
        ('王大明', '大明哥', 'male',   '0900-000-101', 'daming@example.com',  ARRAY['中年(36-60)','醫療險','壽險','意外險','定期聯繫'], '45 歲，科技公司工程師，已婚有兩個小孩。重視家庭保障，每年一起做保單健檢。', 'positive', 400, NULL::int),
        ('王美華', NULL,     'female', '0900-000-102', 'meihua@example.com',  ARRAY['中年(36-60)','醫療險','壽險'],                      '43 歲，國小老師，王大明的太太。想了解實支實付夠不夠。', 'considering', 380, NULL),
        ('陳志豪', '陳醫師', 'male',   '0900-000-103', 'drchen@example.com',  ARRAY['中年(36-60)','醫療從業','高資產','高爾夫','轉介紹'], '38 歲，家醫科診所醫師，吳雅婷在同一間診所。人脈很廣，介紹過好幾位朋友，也是王大明的高爾夫球友。', 'positive', 360, NULL),
        ('李淑芬', NULL,     'female', '0900-000-104', 'shufen@example.com',  ARRAY['中年(36-60)','長照險','爬山'],                      '52 歲，高中老師，開始規劃退休與長照。', 'negative', 300, NULL),
        ('張家瑋', NULL,     'male',   '0900-000-105', 'jiawei@example.com',  ARRAY['青年(18-35)','意外險','露營'],                      '30 歲，業務，王大明介紹。常騎車跑客戶，先買了意外險。', 'positive', 240, NULL),
        ('吳雅婷', '雅婷',   'female', '0900-000-106', 'yating@example.com',  ARRAY['青年(18-35)','新手爸媽','防癌險'],                  '34 歲，護理師，今年剛生寶寶，想幫小孩規劃。', 'positive', 200, NULL),
        ('吳建宏', NULL,     'male',   '0900-000-107', 'jianhong@example.com',ARRAY['樂齡(60+)','醫療險','高血壓'],                      '60 歲，剛退休，吳雅婷的爸爸。有高血壓，關心手術與住院。', 'positive', 500, NULL),
        -- 跟進中
        ('林佳穎', NULL,     'female', '0900-000-108', 'jiaying@example.com', ARRAY['青年(18-35)','咖啡','高意願'],                      '29 歲，平面設計師，陳醫師介紹。今天約咖啡廳談醫療險。', 'considering', 30, NULL),
        ('劉俊傑', NULL,     'male',   '0900-000-109', 'junjie@example.com',  ARRAY['中年(36-60)','觀望中'],                            '41 歲，連鎖餐飲店長，陳醫師介紹（以前在醫院餐廳認識）。', 'considering', 25, NULL),
        ('蔡宜君', NULL,     'female', '0900-000-110', 'yijun@example.com',   ARRAY['中年(36-60)','高意願'],                            '36 歲，會計，林佳穎的同事。昨天拜訪過，對實支實付有興趣。', 'considering', 20, NULL),
        ('許文彬', '許董',   'male',   '0900-000-111', 'wenbin@example.com',  ARRAY['中年(36-60)','公司負責人','高資產','高爾夫'],       '48 歲，貿易公司老闆，和陳醫師是獅子會社友。想談員工團保與個人資產傳承。', 'considering', 15, NULL),
        ('鄭雅文', NULL,     'female', '0900-000-112', 'yawen@example.com',   ARRAY['青年(18-35)','定期聯繫'],                          '27 歲，研究生，蔡宜君的表妹介紹來的。預算有限，先從意外險開始。', NULL, 12, NULL),
        ('楊志明', NULL,     'male',   '0900-000-113', 'zhiming@example.com', ARRAY['中年(36-60)','觀望中'],                            '55 歲，公務員，李淑芬的同事。目前覺得公保就夠。', 'negative', 40, NULL),
        -- 未開發
        ('周怡君', NULL,     'female', '0900-000-114', 'yijun.chou@example.com', ARRAY['青年(18-35)'],                                  '31 歲，在活動上交換名片，還沒聯絡。', NULL, 10, NULL),
        ('謝承恩', NULL,     'male',   '0900-000-115', 'chengen@example.com',    ARRAY['青年(18-35)','露營'],                           '26 歲，張家瑋的露營朋友。', NULL, 8, NULL),
        ('洪麗玲', NULL,     'female', '0900-000-116', 'liling@example.com',     ARRAY['中年(36-60)'],                                  '47 歲，家庭主婦，社區媽媽群認識。', NULL, 6, NULL),
        ('郭建志', NULL,     'male',   '0900-000-117', 'jianzhi@example.com',    ARRAY['中年(36-60)','轉介紹'],                         '39 歲，陳醫師介紹的牙醫師朋友，下週再聯絡。', NULL, 3, NULL),
        ('曾美玲', '曾媽媽', 'female', '0900-000-118', 'meiling@example.com',    ARRAY['樂齡(60+)','健康'],                             '65 歲，王美華的媽媽，吳建宏在社區長青班的同學，經他介紹。身體健康，想了解長照。', NULL, 5, NULL),
        -- 垃圾桶（示範可以還原）
        ('黃小測', NULL,     'male',   '0900-000-119', NULL,                     ARRAY[]::text[],                                       '重複建立的客戶，已移到垃圾桶。', NULL, 50, 2),
        ('范假名', NULL,     'female', '0900-000-120', NULL,                     ARRAY[]::text[],                                       '電話打錯的名單，已移到垃圾桶。', NULL, 45, 4)
      ) AS v(name, nickname, gender, phone, email, tags, notes, status, created_days_ago, deleted_days_ago)
      RETURNING id, name
    )
    INSERT INTO demo_customer_ids (customer_name, id) SELECT name, id FROM inserted;

    -- 5. 人脈關係：三個家庭、陳醫師是人脈王，用球友、同診所、讀書會把各群串起來（人脈拓撲才好看）
    --    周怡君、洪麗玲故意沒有任何關係（示範「沒有關係的客戶」在外圈）
    INSERT INTO public.customer_relationships (user_id, source_customer_id, target_customer_id, relationship_type, relationship_detail)
    SELECT demo_user_id, s.id, t.id, v.relationship_type, v.detail
    FROM (VALUES
      ('王大明', '王美華', 'family', '夫妻'),
      ('曾美玲', '王美華', 'family', '母女'),
      ('吳建宏', '吳雅婷', 'family', '父女'),
      ('陳志豪', '許文彬', 'social', '獅子會社友'),
      ('陳志豪', '王大明', 'social', '高爾夫球友'),
      ('陳志豪', '吳雅婷', 'workplace', '同診所'),
      ('林佳穎', '蔡宜君', 'workplace', '同事'),
      ('李淑芬', '楊志明', 'workplace', '同校老師'),
      ('李淑芬', '王美華', 'social', '教師讀書會'),
      ('張家瑋', '謝承恩', 'social', '露營朋友')
    ) AS v(source_name, target_name, relationship_type, detail)
    JOIN demo_customer_ids s ON s.customer_name = v.source_name
    JOIN demo_customer_ids t ON t.customer_name = v.target_name;

    -- 5b. 轉介紹來源（人脈拓撲畫成有箭頭的線，點客戶時顯示「由誰介紹、介紹了誰」）
    --     介紹人和被介紹的人之間不另外建上面的關係，箭頭才看得到
    UPDATE public.customers c
    SET referral_source_id = referrer.id
    FROM (VALUES
      ('林佳穎', '陳志豪'),
      ('劉俊傑', '陳志豪'),
      ('郭建志', '陳志豪'),
      ('張家瑋', '王大明'),
      ('鄭雅文', '蔡宜君'),
      ('曾美玲', '吳建宏')
    ) AS v(customer_name, referrer_name)
    JOIN demo_customer_ids referred ON referred.customer_name = v.customer_name
    JOIN demo_customer_ids referrer ON referrer.customer_name = v.referrer_name
    WHERE c.id = referred.id;

    -- 6. 保單（用資料庫裡真的國泰、富邦、南山商品；同一張保單的主約、附約用同一個保單編號）
    INSERT INTO public.customer_policies (
      customer_id, policy_clause_id, product_name, company_name, category,
      room_limit, surgery_limit, misc_limit, benefits_json, raw_pdf_url, status,
      policy_group_id, policy_number, coverage_role, plan_or_amount, effective_date, premium,
      coverage_amount, benefit_plan_id, source, enrolled_at
    )
    SELECT c.id, p.id::text, p.product_name, p.company_name,
           CASE p.insurance_type WHEN 'medical' THEN '醫療' WHEN 'cancer' THEN '癌症' WHEN 'critical_illness' THEN '重大疾病'
             WHEN 'long_term_care' THEN '長期照顧' WHEN 'accident' THEN '意外傷害' WHEN 'life' THEN '壽險' ELSE '其他' END,
           NULL, NULL, NULL, '{}'::jsonb, p.clause_url, v.status,
           CASE WHEN v.policy_number IS NULL THEN NULL ELSE md5(demo_user_id::text || v.policy_number)::uuid END,
           v.policy_number, v.coverage_role, v.plan_or_amount,
           (today_local - make_interval(days => v.effective_days_ago))::date, v.premium, v.coverage_amount,
           (SELECT plan.id FROM public.insurance_product_benefit_plans plan WHERE plan.product_id = p.id AND plan.plan_code = v.plan_code LIMIT 1),
           v.source, now() - make_interval(days => v.effective_days_ago)
    FROM (VALUES
      -- 王大明：一張國泰保單＝主約＋2 附約（示範「一張保單一張卡片」）；另一張防癌險已失效
      ('王大明', '國泰人壽新GO心保障100定期壽險',                      'active', 'DEMO-A0001', 'main',  '300萬',   1800, 24000, 3000000, NULL,  'scan'),
      ('王大明', '國泰人壽新實全心意PLUS住院醫療健康保險附約（外溢型）', 'active', 'DEMO-A0001', 'rider', 'M20',     1800, 9800,  NULL,    'M20', 'scan'),
      ('王大明', '國泰人壽超全方位傷害暨兒童傷害失能保險附約',          'active', 'DEMO-A0001', 'rider', '100萬',   1800, 2100,  1000000, NULL,  'scan'),
      ('王大明', '國泰人壽鍾愛守護防癌定期保險',                        'lapsed', NULL,         NULL,    '50萬',    3200, 6500,  500000,  NULL,  'manual'),
      -- 王美華：富邦主約＋實支附約
      ('王美華', '富邦人壽新平準終身壽險',                              'active', 'DEMO-F0002', 'main',  '100萬',   1500, 31000, 1000000, NULL,  'scan'),
      ('王美華', '富邦人壽佳實在一年期住院醫療健康保險附約',            'active', 'DEMO-F0002', 'rider', '計劃2',   1500, 8200,  NULL,    '計劃2', 'scan'),
      -- 陳志豪：南山壽險＋重大疾病附約；另買一張實支終身
      ('陳志豪', '南山人壽新定期壽險',                                  'active', 'DEMO-N0003', 'main',  '500萬',   1100, 15800, 5000000, NULL,  'scan'),
      ('陳志豪', '南山人壽至尊康祥重大疾病健康保險附約(乙型)',         'active', 'DEMO-N0003', 'rider', '200萬',   1100, 12600, 2000000, NULL,  'scan'),
      ('陳志豪', '南山人壽實健溢百住院醫療終身保險',                    'active', NULL,         NULL,    '計劃20',  700,  21000, NULL,    '計劃20', 'manual'),
      -- 其他保戶各一張（保額沒填的會顯示「補保額」，可示範保單健檢補資料）
      ('李淑芬', '富邦人壽連馨滿溢長期照顧終身健康保險',                'active', NULL,         NULL,    '3萬',     900,  36000, 30000,   NULL,  'manual'),
      ('張家瑋', '富邦人壽 e心守護網路投保傷害保險',                    'active', NULL,         NULL,    '300萬',   400,  3600,  3000000, NULL,  'manual'),
      ('吳雅婷', '南山人壽滿溢久久2癌症醫療健康保險',                   'active', NULL,         NULL,    '10單位',  150,  7200,  NULL,    NULL,  'manual'),
      ('吳建宏', '國泰人壽醫定安心手術醫療終身保險',                    'active', NULL,         NULL,    '1萬',     1600, 18500, 10000,   NULL,  'manual')
    ) AS v(customer_name, product_name, status, policy_number, coverage_role, plan_or_amount, effective_days_ago, premium, coverage_amount, plan_code, source)
    JOIN demo_customer_ids c ON c.customer_name = v.customer_name
    JOIN public.insurance_products p ON p.product_name = v.product_name;

    -- 7. 保單健檢目標（王大明壽險有缺口、實支夠；陳醫師重大疾病有缺口）
    INSERT INTO public.customer_coverage_targets (customer_id, category, target_amount)
    SELECT c.id, v.category, v.target_amount
    FROM (VALUES
      ('王大明', 'life', 5000000), ('王大明', 'accident', 1000000), ('王大明', 'reimbursement_hospital', 200000),
      ('王美華', 'life', 2000000),
      ('陳志豪', 'critical_illness', 3000000), ('陳志豪', 'life', 5000000)
    ) AS v(customer_name, category, target_amount)
    JOIN demo_customer_ids c ON c.customer_name = v.customer_name;

    -- 8. 行程（以今天為準：今天 3 個、這週 4 個、過去 2 個已完成）
    INSERT INTO public.schedule_events (profile_id, customer_id, title, start_at, end_at, location, event_type, tag, is_completed)
    SELECT demo_user_id, c.id, v.title,
           (today_local + make_interval(days => v.day_offset, mins => v.start_minute)) AT TIME ZONE 'Asia/Taipei',
           (today_local + make_interval(days => v.day_offset, mins => v.start_minute + v.duration_minutes)) AT TIME ZONE 'Asia/Taipei',
           v.location, v.event_type, v.tag, v.is_completed
    FROM (VALUES
      (NULL::text, '團隊晨會',                   0, 540,  60,  '通訊處會議室',        'personal', '內勤', false),
      ('林佳穎',   '林佳穎 醫療險需求訪談',       0, 630,  60,  '信義區示範咖啡廳',    'customer_visit', '首談', false),
      ('許文彬',   '許董 員工團保與傳承規劃',     0, 870,  90,  '許董公司（內湖）',    'meeting',  '規劃', false),
      ('王大明',   '王大明 保單送件',             1, 600,  30,  '台北分公司',          'follow_up', '送件', false),
      ('吳建宏',   '吳建宏 生日關懷',             2, 570,  60,  NULL,                 'follow_up', '關懷', false),
      ('劉俊傑',   '劉俊傑 第二次拜訪',           3, 900,  60,  '中山區餐廳',          'customer_visit', '跟進', false),
      ('鄭雅文',   '鄭雅文 意外險說明',           5, 720,  60,  '學校附近',            'customer_visit', '跟進', false),
      ('蔡宜君',   '蔡宜君 實支實付說明',        -1, 840,  60,  '蔡宜君公司樓下',      'customer_visit', '跟進', true),
      ('楊志明',   '楊志明 退休規劃聊聊',        -3, 600,  60,  '學校',                'customer_visit', '首談', true)
    ) AS v(customer_name, title, day_offset, start_minute, duration_minutes, location, event_type, tag, is_completed)
    LEFT JOIN demo_customer_ids c ON c.customer_name = v.customer_name;

    -- 9. 專案拜訪：日常拜訪（每人預設一個）＋年底保單健檢＋新生兒家庭關懷
    SELECT id INTO daily_project_id FROM public.visit_projects WHERE profile_id = demo_user_id AND is_default;
    IF daily_project_id IS NULL THEN
      INSERT INTO public.visit_projects (profile_id, title, purpose, period_type, target_count, is_default)
      VALUES (demo_user_id, '日常拜訪', '', 'month', 20, true) RETURNING id INTO daily_project_id;
    END IF;
    INSERT INTO public.visit_projects (profile_id, title, purpose, period_type, start_date, end_date, target_count, is_default)
    VALUES (demo_user_id, '年底保單健檢', '年底前幫既有保戶檢視保障缺口，順便更新保單資料', 'range',
            (today_local - interval '20 days')::date, (today_local + interval '40 days')::date, 10, false)
    RETURNING id INTO checkup_project_id;
    INSERT INTO public.visit_projects (profile_id, title, purpose, period_type, start_date, end_date, target_count, is_default)
    VALUES (demo_user_id, '新生兒家庭關懷', '今年有新生兒的家庭，介紹小孩的醫療與意外保障', 'range',
            (today_local - interval '10 days')::date, (today_local + interval '50 days')::date, 5, false)
    RETURNING id INTO newborn_project_id;

    INSERT INTO public.visit_project_customers (visit_project_id, customer_id, is_visited)
    SELECT v.project_id, c.id, v.is_visited
    FROM (VALUES
      (checkup_project_id, '王大明', true), (checkup_project_id, '王美華', true), (checkup_project_id, '陳志豪', true),
      (checkup_project_id, '李淑芬', true), (checkup_project_id, '吳建宏', false),
      (newborn_project_id, '吳雅婷', true), (newborn_project_id, '鄭雅文', false), (newborn_project_id, '周怡君', false)
    ) AS v(project_id, customer_name, is_visited)
    JOIN demo_customer_ids c ON c.customer_name = v.customer_name;

    INSERT INTO public.visit_results (profile_id, project_id, customer_id, visited_on, result, note)
    SELECT demo_user_id, v.project_id, c.id, (today_local - make_interval(days => v.days_ago))::date, v.result, v.note
    FROM (VALUES
      (checkup_project_id, '王大明', 12, 'positive',    '壽險保額不足，同意加保 200 萬'),
      (checkup_project_id, '王美華', 12, 'considering', '想先比較實支實付計畫'),
      (checkup_project_id, '陳志豪', 8,  'positive',    '重大疾病想再加 100 萬，下次帶建議書'),
      (checkup_project_id, '李淑芬', 5,  'negative',    '今年預算已用完，明年再談'),
      (newborn_project_id, '吳雅婷', 6,  'positive',    '幫寶寶投保醫療與意外，已送件'),
      (daily_project_id,   '蔡宜君', 1,  'considering', '對實支實付有興趣，下週給試算'),
      (daily_project_id,   '楊志明', 3,  'negative',    '覺得公保就夠，半年後再關心'),
      (daily_project_id,   '劉俊傑', 9,  'considering', '要跟太太討論')
    ) AS v(project_id, customer_name, days_ago, result, note)
    JOIN demo_customer_ids c ON c.customer_name = v.customer_name;

    -- 10. 拜訪紀錄（5 篇已整理：原始轉錄有辨識錯字，整理後只修錯字與標點；1 篇還沒整理）
    WITH inserted AS (
      INSERT INTO public.visit_records (profile_id, customer_id, title, raw_transcript, organized_content, status, created_at, updated_at)
      SELECT demo_user_id, c.id, v.title, v.raw_transcript, v.organized_content, v.status,
             now() - make_interval(days => v.days_ago), now() - make_interval(days => v.days_ago)
      FROM (VALUES
        -- 原始轉錄模擬語音辨識常見的錯（同音錯字、沒有標點）；整理後內容＝AI「非錯勿動」：只修錯字與標點，不加原文沒說的話
        ('王大明', '王大明 年度保單健檢', 12,
         '今天跟大明哥看了一下他的保單 壽險三百萬 他覺得小孩還小 房帶還有一千多萬 三百萬好像不太夠 時支實付是M二十 住院的部份應該還可以 他說太太那邊也想看一下',
         '今天跟大明哥看了一下他的保單，壽險三百萬。他覺得小孩還小，房貸還有一千多萬，三百萬好像不太夠。實支實付是 M20，住院的部分應該還可以。他說太太那邊也想看一下。', 'done'),
        ('陳志豪', '陳醫師 重大疾病規劃', 8,
         '陳醫師說他在診所看到很多重大急病的病人 自己的重大急病只有兩百萬 想再加 另外他說有幾個朋友也想找人規畫 會幫我介紹',
         '陳醫師說他在診所看到很多重大疾病的病人，自己的重大疾病只有兩百萬，想再加。另外他說有幾個朋友也想找人規劃，會幫我介紹。', 'done'),
        ('林佳穎', '林佳穎 初次認識', 20,
         '陳醫師介紹的林小姐 做平面設計 自由接案沒有公司團寶 目前只有一張很久以前買的意外鹹 對醫療鹹有興趣但怕太貴',
         '陳醫師介紹的林小姐，做平面設計，自由接案沒有公司團保。目前只有一張很久以前買的意外險，對醫療險有興趣但怕太貴。', 'done'),
        ('蔡宜君', '蔡宜君 實支實付說明', 1,
         '跟蔡小姐說明時支實付跟日額的差別 他覺得時支比較實用 他公司的團寶只有基本的 想補一張 預算一個月兩千左右',
         '跟蔡小姐說明實支實付跟日額的差別，她覺得實支比較實用。她公司的團保只有基本的，想補一張，預算一個月兩千左右。', 'done'),
        ('許文彬', '許董 第一次見面', 15,
         '許董是獅子會的社友 公司大概三十個員工 想了解員工團寶 另外也在想資產要怎麼留給小孩',
         '許董是獅子會的社友，公司大概三十個員工，想了解員工團保。另外也在想資產要怎麼留給小孩。', 'done'),
        (NULL::text, '週五通訊處分享會筆記', 4,
         '今天分享會講到年底是保單健儉的好時機 很多客戶年底有獎金 可以趁機提醒加保 另外提到長照鹹的需求越來越多',
         NULL, 'raw')
      ) AS v(customer_name, title, days_ago, raw_transcript, organized_content, status)
      LEFT JOIN demo_customer_ids c ON c.customer_name = v.customer_name
      RETURNING id, title
    )
    INSERT INTO demo_record_ids (title, id) SELECT title, id FROM inserted;

    -- 11. 通知（拜訪紀錄整理完成、行程提醒）
    INSERT INTO public.notifications (profile_id, type, title, content, link_path, target_visit_record_id, is_read, created_at)
    SELECT demo_user_id, v.type, v.title, v.content,
           CASE WHEN r.id IS NULL THEN v.link_path ELSE '/visit-records/' || r.id::text END,
           r.id, v.is_read, now() - make_interval(hours => v.hours_ago)
    FROM (VALUES
      ('visit_record_ready', '拜訪紀錄整理完成', '「蔡宜君 實支實付說明」已整理好，錯字與標點已修正。', '蔡宜君 實支實付說明', NULL, false, 20),
      ('visit_record_ready', '拜訪紀錄整理完成', '「陳醫師 重大疾病規劃」已整理好，錯字與標點已修正。', '陳醫師 重大疾病規劃', NULL, true, 190),
      ('schedule_reminder',  '今天有 3 個行程',  '10:30 林佳穎 醫療險需求訪談、14:30 許董 員工團保與傳承規劃…', NULL, '/schedule', false, 2),
      ('schedule_reminder',  '明天：王大明 保單送件', '別忘了帶要保書與身分證影本。', NULL, '/schedule', false, 1)
    ) AS v(type, title, content, record_title, link_path, is_read, hours_ago)
    LEFT JOIN demo_record_ids r ON r.title = v.record_title;

    RAISE NOTICE '已放好 % 的假資料', demo_email;
  END LOOP;
END $$;

DROP TABLE IF EXISTS demo_customer_ids;
DROP TABLE IF EXISTS demo_record_ids;

-- 檢查：每個示範帳號應該是 客戶 20（含垃圾桶 2）、保單 13、行程 9、專案 3、拜訪結果 8、拜訪紀錄 6、通知 4
SELECT u.email,
  (SELECT count(*) FROM public.customers c WHERE c.profile_id = u.id) AS customers,
  (SELECT count(*) FROM public.customer_policies cp JOIN public.customers c ON c.id = cp.customer_id WHERE c.profile_id = u.id) AS policies,
  (SELECT count(*) FROM public.schedule_events s WHERE s.profile_id = u.id) AS schedules,
  (SELECT count(*) FROM public.visit_projects vp WHERE vp.profile_id = u.id) AS projects,
  (SELECT count(*) FROM public.visit_results vr WHERE vr.profile_id = u.id) AS visit_results,
  (SELECT count(*) FROM public.visit_records r WHERE r.profile_id = u.id) AS visit_records,
  (SELECT count(*) FROM public.notifications n WHERE n.profile_id = u.id) AS notifications
FROM auth.users u
WHERE u.email IN ('demo1@jingxuan.test', 'demo2@jingxuan.test')
ORDER BY u.email;
