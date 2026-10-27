# 實支實付理賠限額（D14）

把三家保險公司「住院醫療實支實付」商品的給付限額，整理進資料表 `insurance_product_benefit_plans`，給保單比較頁使用。設計見 vault 全景地圖 4-K。

## 檔案
| 檔案 | 用途 |
|---|---|
| `targets.json` | 要整理哪些商品：公司、商品名稱、條款網址；`mode` 是 `auto`（程式讀表格）或 `manual`（人工整理）；`overrides`、`note` 補條款表格看不出來的事 |
| `extract_benefit_plans.py` | 下載條款 PDF，讀出 `auto` 商品的給付表 → `benefit_plans_auto.json` |
| `manual_plans.json` | 限額寫在條文句子裡、或總額型的商品，人工整理 |
| `build_seed_sql.py` | 合併上面兩份 → `supabase/seed/benefit_plans.sql`（在 Supabase SQL Editor 執行即可匯入，可重複執行） |

## 有新商品或條款改版時
1. 在 `targets.json` 加一筆（商品名稱要和 `insurance_products` 一字不差）
2. 執行（需要 `pip install -r tool/product_catalog/requirements.txt`）：
   ```
   python3 tool/benefit_plans/extract_benefit_plans.py
   python3 tool/benefit_plans/build_seed_sql.py
   ```
3. 看 `benefit_plans_auto.json` 有沒有「沒有對到比較項目」的提醒；讀不出來的改用 `manual_plans.json`
4. **一定要人工核對**：對照官方條款給付表，數字一致才匯入
5. 在 Supabase SQL Editor 執行 `supabase/seed/benefit_plans.sql`，最後的檢查表每款計畫數不能是 0；核對後再把 `verified_at` 設成核對時間

## 注意
- 官網凌晨常在維護，下載到「維護公告」網頁時程式會報錯，白天再試
- 限額幾乎不會改，不需要每週自動更新
- 意外傷害醫療、旅平險的實支第一版不放
