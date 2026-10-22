"""國泰人壽：商品清單 PDF ＋ 網頁「契約條款」連結。

來源：資訊公開 → 保險商品（2026-10-23 實測，見盤點紀錄第五節）
- 商品清單：product/ 底下的 PDF，表格「商品名稱｜核准、核備或備查日期及文號」
- 條款：同一頁「契約條款」區塊，連結文字＝商品名稱，檔名＝商品代碼
  （投資型有一部分放在 files/products/ 資料夾，2026-10-23 確認也都在契約條款區塊）
- 團險（Group.pdf、group/ 條款）不收（2026-10-23 沛沛決定先收個人保險）
"""

import html
import re
from typing import List

from catalog_common import (
    ClauseLink,
    CompanyResult,
    Product,
    append_continuation,
    clean_product_name,
    code_from_filename,
    download,
    download_pdf_tables,
    finish_products,
    merge_clause_links,
    set_approval,
)

SITE = "https://www.cathaylife.com.tw"
COMPANY_PREFIX = "國泰人壽"
PAGE_URL = SITE + "/official/laws-policies/public-info/info-insurance"
FILE_BASE = SITE + "/official/content/dam/cathaylife-official/files/laws-policies/public-info/insurance"

# 商品清單 PDF 與官網上的分類名稱（不含團險）
PRODUCT_LIST_FILES = [
    ("LifeHealthAnnuity.pdf", "壽險、年金險、健康險主約商品"),
    ("Investment.pdf", "投資型商品"),
    ("AccessoryContract.pdf", "壽險、意外險、醫療險附約"),
    ("Accident.pdf", "意外險商品"),
]

# 「契約條款」區塊的資料夾（不含 group 團險）
CLAUSE_FOLDERS = ["life-health-annuity", "investment", "accessory-contract", "accident"]


def parse_product_list(pdf_url: str, source_category: str) -> List[Product]:
    """讀一份商品清單 PDF；不是「國泰人壽」開頭的列，是上一款商品的名稱或文號續行。"""
    products: List[Product] = []
    for row in download_pdf_tables(pdf_url, company_prefix=COMPANY_PREFIX):
        if not row:
            continue
        name_text = clean_product_name(row[0] or "")
        approval_text = "\n".join(cell for cell in row[1:] if cell)

        if name_text.startswith("商品名稱"):
            continue
        if not name_text.startswith(COMPANY_PREFIX):
            if products:
                append_continuation(products[-1], name_text, approval_text)
            continue

        product = Product(product_name=name_text, source_category=source_category, source_url=pdf_url)
        set_approval(product, approval_text)
        products.append(product)
    return products


def parse_clause_links(page_html: str) -> List[ClauseLink]:
    """從網頁抓出「契約條款」每一份條款的連結與名稱（名稱在 <a> 裡的 <span>）。"""
    folder_pattern = "|".join(CLAUSE_FOLDERS)
    link_pattern = re.compile(
        # 大多數條款在 public-info/insurance/<分類>/，投資型有一部分放在 files/products/<分類>/
        r'<a href="(/official/content/dam/cathaylife-official/files/'
        r'(?:laws-policies/public-info/insurance/(?:' + folder_pattern + r')|products/[a-z-]+)/[^"]+\.pdf)"'
        r'[^>]*>.*?<span>([^<]+)</span>',
        re.S,
    )
    clause_links: List[ClauseLink] = []
    for match in link_pattern.finditer(page_html):
        clause_url = SITE + match.group(1)
        clause_links.append(
            ClauseLink(
                product_name=clean_product_name(html.unescape(match.group(2))),
                clause_url=clause_url,
                product_code=code_from_filename(clause_url),
            )
        )
    return clause_links


def crawl() -> CompanyResult:
    page_html = download(PAGE_URL).decode("utf-8", errors="ignore")

    products: List[Product] = []
    for file_name, source_category in PRODUCT_LIST_FILES:
        pdf_url = FILE_BASE + "/product/" + file_name
        products.extend(parse_product_list(pdf_url, source_category))

    merge_clause_links(products, parse_clause_links(page_html))
    return CompanyResult(
        company_code="cathay",
        company_name="國泰人壽",
        products=finish_products(products),
    )
