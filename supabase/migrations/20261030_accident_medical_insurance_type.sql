-- ============================================================================
-- 第 5 階段 D22：傷害醫療商品改歸「意外傷害」
-- 日期：2026-10-30
--
-- 原因：商品目錄依名稱分險種時，「醫療」排在「傷害」前面，傷害醫療、意外住院日額
--       被分進醫療；業務員在「意外傷害」找不到（沛沛測試發現）。
-- 爬蟲規則已同步修改（tool/product_catalog/catalog_common.py），每週更新不會改回來。
-- 只改 insurance_type，不動其他欄位；權限不變（insurance_products 登入者唯讀）
-- 可重複執行
-- ============================================================================

UPDATE public.insurance_products
SET insurance_type = 'accident'
WHERE insurance_type = 'medical'
  AND product_name ~ '傷害醫療|意外.{0,6}(醫療|住院|日額)|傷害.{0,4}住院';

-- 檢查：應該列出 25 款，險種都是 accident
SELECT company_name, product_name, insurance_type
FROM public.insurance_products
WHERE product_name ~ '傷害醫療|意外.{0,6}(醫療|住院|日額)|傷害.{0,4}住院'
ORDER BY company_name, product_name;
