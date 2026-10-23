-- ============================================================================
-- 5-2b②：清除假商品資料（問題 D1、D3、D4）
-- 日期：2026-10-23
--
-- 背景：policy_clauses 的 12,090 筆商品全是假資料產生器 crawl-insurance-products 用公式編的
--       （含 20260817_seed_real_policy_clauses.sql 的種子資料，網址也是拼的）。
--       5-2a 已改用真實商品表 insurance_products，5-2b① 畫面已改讀真資料。
--
-- 這份 migration 做三件事：
--   1. 取消 20260812 設的每日排程 daily-insurance-crawler-job（每天呼叫假資料產生器，會把假資料灌回來）
--   2. 刪除連到假商品的客戶保單：2026-10-23 唯讀查詢共 11 筆，全部是測試資料，
--      分屬 peggy wu 4 筆、萱芮 3 筆、蘿蔔 2 筆、巨獸 1 筆、brian.bb.insure 1 筆（沛沛確認全部刪除）
--      → 客戶本身不刪，只是保單區變空；連到真實商品的保單不受影響
--   3. 刪除 policy_clauses 全部資料（表格與權限保留，之後整理時再決定是否移除）
--
-- 可重複執行：排程不存在就跳過；刪除條件找不到資料就什麼都不做。
-- ============================================================================

-- 1. 取消每日假資料排程（資料庫沒有 pg_cron 或排程不存在時跳過）
DO $$
BEGIN
  IF to_regclass('cron.job') IS NOT NULL
     AND EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-insurance-crawler-job') THEN
    PERFORM cron.unschedule('daily-insurance-crawler-job');
  END IF;
END
$$;

-- 2. 刪除連到假商品的客戶保單（policy_clause_id 是文字，存的是 policy_clauses.id）
DELETE FROM public.customer_policies AS customer_policy
WHERE EXISTS (
  SELECT 1
  FROM public.policy_clauses AS fake_product
  WHERE fake_product.id::text = customer_policy.policy_clause_id
);

-- 3. 刪除全部假商品
DELETE FROM public.policy_clauses;
