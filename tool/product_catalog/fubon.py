"""富邦人壽：商品清單 PDF ＋ 網頁資料區裡的「契約條款」。

來源：公開揭露事項 → 保險商品（2026-10-23 實測，見盤點紀錄第五節）
- 網頁原始碼 <script id="__NUXT_DATA__"> 是一個大陣列，物件裡的數字是指向陣列其他位置的編號
- 商品清單：檔名含「5-1_保險商品之名稱、日期及文號」的 PDF，表格「商品名稱｜日期｜文號」，
  只有名稱沒有日期的列是分類標題（人壽保險、健康保險、團體保險…）
- 契約條款：區塊標題為「契約條款」的檔案，內含商品名稱、檔案編號、商品代碼
- 下載網址：/life/api/v1/files/{檔案編號}/download/{檔名}（/open/ 會轉到 http，不用）
- 團險分類不收（2026-10-23 沛沛決定先收個人保險）
"""

import json
import re
import urllib.parse
from typing import Any, List, Optional

from catalog_common import (
    ClauseLink,
    CompanyResult,
    Product,
    append_continuation,
    clean_product_name,
    download,
    download_pdf_tables,
    finish_products,
    looks_incomplete,
    merge_clause_links,
    set_approval,
)

SITE = "https://www.fubon.com"
COMPANY_PREFIX = "富邦人壽"
PAGE_URL = SITE + "/life/investor/public-info1?c=commodity"
PRODUCT_LIST_FILE_KEYWORD = "保險商品之名稱、日期及文號"
CLAUSE_BLOCK_TITLE = "契約條款"
# 分類名稱含這些字就跳過整個分類
SKIPPED_CATEGORY_KEYWORDS = ["團體"]


class NuxtData:
    """把網頁資料區的大陣列包起來，方便用編號取值。"""

    def __init__(self, page_html: str):
        match = re.search(r'<script[^>]*id="__NUXT_DATA__"[^>]*>(.*?)</script>', page_html, re.S)
        if match is None:
            raise ValueError("富邦網頁找不到 __NUXT_DATA__ 資料區，網站可能改版了")
        self.items: List[Any] = json.loads(match.group(1))

    def value(self, reference: Any) -> Any:
        """物件裡的數字是指向陣列的編號，取出真正的值。"""
        if isinstance(reference, int) and 0 <= reference < len(self.items):
            return self.items[reference]
        return reference

    def file_url(self, file_id: Any, file_name: str) -> str:
        # 官網的 /open/ 會轉到不加密的 http 網址，所以直接用轉過去的 /download/ 加密網址
        # 檔名用來當下載檔名，中文要先編碼成網址格式
        return SITE + "/life/api/v1/files/" + str(file_id) + "/download/" + urllib.parse.quote(file_name) + ".pdf"


def find_product_list_url(nuxt_data: NuxtData) -> str:
    for item in nuxt_data.items:
        if not isinstance(item, dict) or "fileId" not in item or "fileOriginalName" not in item:
            continue
        original_name = nuxt_data.value(item["fileOriginalName"])
        if isinstance(original_name, str) and PRODUCT_LIST_FILE_KEYWORD in original_name:
            return nuxt_data.file_url(nuxt_data.value(item["fileId"]), "product-list")
    raise ValueError("富邦網頁找不到商品清單 PDF，網站可能改版了")


def parse_clause_links(nuxt_data: NuxtData) -> List[ClauseLink]:
    # 先找出「契約條款」這個區塊標題的編號
    clause_title_ids = set()
    for item in nuxt_data.items:
        if isinstance(item, dict) and "title" in item and "id" in item:
            if nuxt_data.value(item["title"]) == CLAUSE_BLOCK_TITLE:
                clause_title_ids.add(nuxt_data.value(item["id"]))

    clause_links: List[ClauseLink] = []
    for item in nuxt_data.items:
        if not isinstance(item, dict) or "blockTitleId" not in item:
            continue
        if nuxt_data.value(item["blockTitleId"]) not in clause_title_ids:
            continue
        for file_reference in nuxt_data.value(item.get("block1s")) or []:
            clause_link = _clause_link_from_file(nuxt_data, nuxt_data.value(file_reference))
            if clause_link is not None:
                clause_links.append(clause_link)
    return clause_links


def _clause_link_from_file(nuxt_data: NuxtData, file_item: Any) -> Optional[ClauseLink]:
    if not isinstance(file_item, dict) or "fileId" not in file_item:
        return None
    product_name = nuxt_data.value(file_item.get("fileName"))
    if not isinstance(product_name, str) or not product_name.strip():
        return None

    # hookedProductCode 是一串編號，第一個就是商品代碼（例：FPF）
    product_code: Optional[str] = None
    code_references = nuxt_data.value(file_item.get("hookedProductCode")) or []
    if isinstance(code_references, list) and code_references:
        first_code = nuxt_data.value(code_references[0])
        if isinstance(first_code, str) and re.match(r"^[A-Za-z0-9]{2,12}$", first_code):
            product_code = first_code.upper()

    return ClauseLink(
        product_name=clean_product_name(product_name),
        clause_url=nuxt_data.file_url(nuxt_data.value(file_item["fileId"]), clean_product_name(product_name)),
        product_code=product_code,
    )


def parse_product_list(pdf_url: str) -> List[Product]:
    products: List[Product] = []
    current_category = ""
    skipping_category = False

    for row in download_pdf_tables(pdf_url):
        if not row:
            continue
        name_text = clean_product_name(row[0] or "")
        approval_text = " ".join(cell for cell in row[1:] if cell)

        if name_text.startswith("商品名稱"):
            continue
        # 上一款名稱還沒結束（換頁被切斷），這一列是名稱後半段，不是分類標題
        if products and not skipping_category and looks_incomplete(products[-1].product_name):
            append_continuation(products[-1], name_text, approval_text)
            continue
        # 只有名稱、沒有日期文號的列是分類標題
        if name_text and not approval_text:
            current_category = name_text
            skipping_category = any(keyword in current_category for keyword in SKIPPED_CATEGORY_KEYWORDS)
            continue
        if skipping_category:
            continue
        # 不是「富邦人壽」開頭：上一款商品的文號續行，或換頁後的名稱後半段
        if not name_text.startswith(COMPANY_PREFIX):
            if products:
                append_continuation(products[-1], name_text, approval_text)
            continue

        product = Product(product_name=name_text, source_category=current_category, source_url=PAGE_URL)
        set_approval(product, approval_text)
        products.append(product)
    return products


def load_page_with_retry() -> NuxtData:
    """官網偶爾回傳不完整的網頁，找不到商品清單時重抓一次。"""
    try:
        nuxt_data = NuxtData(download(PAGE_URL).decode("utf-8", errors="ignore"))
        find_product_list_url(nuxt_data)
        return nuxt_data
    except ValueError:
        return NuxtData(download(PAGE_URL).decode("utf-8", errors="ignore"))


def crawl() -> CompanyResult:
    nuxt_data = load_page_with_retry()
    products = parse_product_list(find_product_list_url(nuxt_data))
    merge_clause_links(products, parse_clause_links(nuxt_data))
    return CompanyResult(
        company_code="fubon",
        company_name="富邦人壽",
        products=finish_products(products),
    )
