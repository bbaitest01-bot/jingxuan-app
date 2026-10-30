# 給付項目（D16、D18、D22）

從國泰、富邦、南山的官方條款整理「給付項目與怎麼算」，存進資料表 `insurance_product_benefit_items`，給比較頁的「給付項目（條款）」使用。範圍只做這三家，原則是抓精、抓正確（2026-10-30 沛沛定）。

## 檔案
| 檔案 | 用途 |
|---|---|
| `extract_benefit_items.py` | 下載條款 PDF、讀出每個「給付○○保險金」與算法 → `benefit_items_auto.json` |
| `accident_targets.json` | 不在 6 類裡、另外要整理的意外險（傷害醫療、意外骨折、意外附加條款等） |
| `check_benefit_items.py` | **固定檢查**（見下方），產生匯入檔前自動執行 |
| `benefit_items_verified.json` | 標準答案：人工對照條款確認正確的項目 |
| `check_exceptions.json` | 檢查列出、但確定不是錯的項目（一定要寫理由） |
| `build_seed_sql.py` | 先跑固定檢查，通過才產生 `supabase/seed/benefit_items_1～3.sql`；加 `accident` 只產生意外險那份 |

## 更新步驟
1. 執行 `python3 tool/benefit_items/extract_benefit_items.py`（條款快取在 `.cache/`，第一次要下載約 10 分鐘）
2. 執行 `python3 tool/benefit_items/build_seed_sql.py`（會先跑固定檢查，約 5 分鐘）
3. 檢查沒通過：照清單修工具或資料；確定不是錯的才寫進 `check_exceptions.json`
4. 通過後，在 Supabase SQL Editor 依序執行產生的 SQL，最後的數字要和工具印出的一樣

## 固定檢查（2026-10-30 D23）
每次整理條款資料都要通過，避免「越對越多錯」：
1. **漏抓**：條款每一條標題「第○條 ○○保險金的給付」都要在項目裡
2. **數字**：算法裡的數字要在那一條條文或附表裡找得到
3. **標準答案**：`benefit_items_verified.json` 的項目算法要一模一樣（改規則時不會把對的改壞）

檢查抓不到的：條款沒有標題、寫法沒看過的項目，以及「數字對但意思錯」。所以仍要定期抽查；抽查確認正確的項目，加進 `benefit_items_verified.json`，標準答案會越來越多。

## 寫法原則
- 讀不懂的寫「依條款（點看原文）」，不要猜數字（寧可讓業務員點開看原文，也不要顯示錯的數字）
- 金額寫在保單上的（傷害醫療限額、滿期保險金額），寫「依保單…」
