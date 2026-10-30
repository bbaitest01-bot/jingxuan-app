"""抓取國泰、富邦、南山的商品目錄，送到雲端函式 import-product-catalog 寫進資料庫。

用法：
  先在電腦試跑、不寫資料庫（結果存成 JSON 檔）：
    python crawl_products.py --dry-run
  只跑指定的公司（可以重複寫，例如 GitHub 排程只跑國泰、富邦）：
    python crawl_products.py --dry-run --company cathay
    python crawl_products.py --company cathay --company fubon
  正式送出（GitHub 排程用，需要兩個環境變數）：
    PRODUCT_CATALOG_FUNCTION_URL=https://<專案>.supabase.co/functions/v1/import-product-catalog
    PRODUCT_CATALOG_SECRET=<排程密碼>
    python crawl_products.py

某一家失敗時，其他家照常送出；失敗的那家也會送一筆「失敗紀錄」，資料庫裡它的舊資料不動。
"""

import argparse
import json
import os
import sys
import traceback
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Dict, List

import cathay
import fubon
import nanshan
from catalog_common import USER_AGENT, CompanyResult

CRAWLERS: Dict[str, Callable[[], CompanyResult]] = {
    "cathay": cathay.crawl,
    "fubon": fubon.crawl,
    "nanshan": nanshan.crawl,
}
COMPANY_NAMES = {"cathay": "國泰人壽", "fubon": "富邦人壽", "nanshan": "南山人壽"}

# 筆數少於這個數字，多半是網站改版、解析壞掉，當成失敗處理（不送出不完整的資料）
MINIMUM_PRODUCT_COUNT = 30


def crawl_company(company_code: str) -> dict:
    """抓一家公司，回傳要送給雲端函式的內容（成功或失敗都有）。"""
    started_at = datetime.now(timezone.utc).isoformat()
    try:
        result = CRAWLERS[company_code]()
        product_count = len(result.products)
        if product_count < MINIMUM_PRODUCT_COUNT:
            raise ValueError(f"只抓到 {product_count} 筆，少於 {MINIMUM_PRODUCT_COUNT} 筆，網站可能改版了")
        return {
            "company_code": company_code,
            "company_name": result.company_name,
            "status": "success",
            "started_at": started_at,
            "products": [product.to_dict() for product in result.products],
        }
    except Exception as error:  # 任何錯誤都記下來，不讓一家的失敗影響其他家
        traceback.print_exc()
        return {
            "company_code": company_code,
            "company_name": COMPANY_NAMES[company_code],
            "status": "failed",
            "started_at": started_at,
            "error_message": str(error)[:900],
            "products": [],
        }


def print_summary(payload: dict) -> None:
    """在畫面上印出這家的筆數與各種分類的數量，方便檢查。"""
    products: List[dict] = payload["products"]
    print(f"\n=== {payload['company_name']}（{payload['company_code']}）：{payload['status']}，{len(products)} 筆")
    if payload["status"] == "failed":
        print("  失敗原因：", payload.get("error_message"))
        return

    with_code = sum(1 for product in products if product["product_code"])
    with_clause = sum(1 for product in products if product["clause_url"])
    with_date = sum(1 for product in products if product["approval_date"])
    print(f"  有商品代碼 {with_code}、有條款連結 {with_clause}、有核准日期 {with_date}")
    print("  主約／附約／批註：", dict(Counter(product["product_kind"] for product in products)))
    print("  險種：", dict(Counter(product["insurance_type"] for product in products)))
    print("  官網分類：", dict(Counter(product["source_category"] for product in products)))


def send_to_function(payload: dict, function_url: str, secret: str) -> None:
    request = urllib.request.Request(
        function_url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": USER_AGENT,
            "x-product-catalog-secret": secret,
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        print("  寫入結果：", response.status, response.read().decode("utf-8")[:300])


def main() -> int:
    parser = argparse.ArgumentParser(description="抓取保險商品目錄")
    # 南山會擋國外連線，GitHub 排程只跑國泰、富邦；南山在台灣網路的電腦手動跑（README「每月更新南山」）
    parser.add_argument(
        "--company",
        action="append",
        choices=sorted(CRAWLERS.keys()),
        help="只抓指定的公司，可以重複寫（不填就是三家）",
    )
    parser.add_argument("--dry-run", action="store_true", help="只抓不送出，結果存成 JSON 檔")
    parser.add_argument("--output", default="output", help="--dry-run 時 JSON 檔放哪個資料夾")
    # 正式寫入時也順便存一份 JSON（每週提醒、每月一鍵更新要拿來比對新商品；2026-10-30 D24）
    parser.add_argument("--save-json", help="正式寫入時，另外把結果存成 JSON 到這個資料夾")
    arguments = parser.parse_args()

    function_url = os.environ.get("PRODUCT_CATALOG_FUNCTION_URL", "")
    secret = os.environ.get("PRODUCT_CATALOG_SECRET", "")
    if not arguments.dry_run and (not function_url or not secret):
        print("❌ 缺少 PRODUCT_CATALOG_FUNCTION_URL 或 PRODUCT_CATALOG_SECRET；只想試跑請加 --dry-run")
        return 1

    company_codes = arguments.company or list(CRAWLERS.keys())
    has_failure = False
    for company_code in company_codes:
        payload = crawl_company(company_code)
        print_summary(payload)
        has_failure = has_failure or payload["status"] == "failed"

        if arguments.dry_run:
            output_folder = Path(arguments.output)
            output_folder.mkdir(parents=True, exist_ok=True)
            output_file = output_folder / f"{company_code}.json"
            output_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
            print("  已存檔：", output_file)
        else:
            send_to_function(payload, function_url, secret)
            if arguments.save_json:
                save_folder = Path(arguments.save_json)
                save_folder.mkdir(parents=True, exist_ok=True)
                (save_folder / f"{company_code}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    # 有任何一家失敗，就讓 GitHub 顯示紅燈，方便發現
    return 1 if has_failure else 0


if __name__ == "__main__":
    sys.exit(main())
