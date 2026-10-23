# 保險商品目錄抓取（5-2a）

從國泰、富邦、南山官網「資訊公開 → 保險商品」抓取**第一層商品目錄**（商品名稱、代碼、核准文號、條款連結），
寫進資料表 `insurance_products`。設計見 vault 的全景地圖 4-H。

- 只收**個人保險**，不收團險（2026-10-23 沛沛決定）
- 只抓事實欄位與官方連結，不下載條款內容、不抓 DM
- 每次請求間隔 3 秒，網路不穩自動重試 2 次
- 某家失敗時其他家照常；失敗那家的舊資料不動，`product_crawl_runs` 會記一筆失敗

## 檔案

| 檔案 | 做什麼 |
|---|---|
| `crawl_products.py` | 主程式：依序跑三家，試跑存成 JSON，或送到雲端函式 |
| `catalog_common.py` | 共用：下載、讀 PDF 表格、民國日期、文號、主約／附約與險種判斷 |
| `cathay.py`、`fubon.py`、`nanshan.py` | 各家官網的解析方式（每個檔案開頭寫了來源與格式） |
| `requirements.txt` | Python 套件（`pdfplumber`） |

寫入資料庫的是雲端函式 `supabase/functions/import-product-catalog/`；排程是 `.github/workflows/product-catalog.yml`。

## 在電腦上試跑（不寫資料庫）

組員平常不需要跑；改了解析程式時才用。需要 Python 3.9 以上。

```bash
cd tool/product_catalog
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python crawl_products.py --dry-run --output output
```

畫面會印出每家的筆數、有代碼／條款連結的數量、險種分布；完整結果在 `output/<公司>.json`（不要提交進 repo）。

## 正式寫入

| 公司 | 誰來跑 | 頻率 |
|---|---|---|
| 國泰、富邦 | GitHub Actions「Weekly Insurance Product Catalog」自動執行（也可在 Actions 頁面按 Run workflow） | 每週一台灣時間 03:00 |
| 南山 | 沛沛在自己的電腦手動執行（見下一節） | 每月一次 |

為什麼南山不給 GitHub 跑：南山網站會拒絕 GitHub 伺服器（在國外）的連線，台灣網路就可以（2026-10-23 實測）。
南山的資料不會錯，只是停在上次更新的日期；保險商品不常變動，每月更新一次就夠。

需要的設定：

- GitHub Secret `PRODUCT_CATALOG_SECRET`
- Supabase Secret `PRODUCT_CATALOG_SECRET`（同一把密碼）
- 雲端函式 `import-product-catalog` 已部署，且 **Verify JWT 關閉**（函式自己比對排程密碼）

## 每月更新南山（Mac，約 3 分鐘）

1. 確認電腦連的是台灣的網路（家裡或學校都可以；開著國外 VPN 會被擋）
2. 打開「終端機」App，第一次使用時先準備環境（之後每個月不用再做）：
   ```bash
   cd ~/Documents/GitHub/jingxuan-app/tool/product_catalog && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
   ```
3. 每個月執行這一行，看到「請貼上排程密碼」時貼上 `PRODUCT_CATALOG_SECRET` 的值（畫面不會顯示）再按 Enter：
   ```bash
   cd ~/Documents/GitHub/jingxuan-app/tool/product_catalog && read -s "PRODUCT_CATALOG_SECRET?請貼上排程密碼後按 Enter（畫面不會顯示）: " && echo && export PRODUCT_CATALOG_SECRET && PRODUCT_CATALOG_FUNCTION_URL=https://algufuoxkeizxwkofmmp.supabase.co/functions/v1/import-product-catalog .venv/bin/python crawl_products.py --company nanshan
   ```
4. 看到 `=== 南山人壽（nanshan）：success` 和 `寫入結果： 200 {"success":true…}` 就完成了
5. 如果出現 `failed`：多半是南山網站維修中（官網會先公告停機時間），隔天再跑一次；連續失敗再找人看

## 官網改版時

筆數少於 30 筆會當成失敗，GitHub 會顯示紅燈。到 Actions 的紀錄看是哪一家、哪個步驟出錯，
再對照該家檔案開頭的「來源」說明，打開官網確認格式是否改了。
