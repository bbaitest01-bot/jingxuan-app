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

由 GitHub Actions「Weekly Insurance Product Catalog」執行（目前只開手動觸發）。需要：

- GitHub Secret `PRODUCT_CATALOG_SECRET`
- Supabase Secret `PRODUCT_CATALOG_SECRET`（同一把密碼）
- 雲端函式 `import-product-catalog` 已部署，且 **Verify JWT 關閉**（函式自己比對排程密碼）

## 官網改版時

筆數少於 30 筆會當成失敗，GitHub 會顯示紅燈。到 Actions 的紀錄看是哪一家、哪個步驟出錯，
再對照該家檔案開頭的「來源」說明，打開官網確認格式是否改了。
