"""南山人壽：分類清單 API ＋ 商品清單 PDF ＋ 條款索引 PDF。

來源：資訊公開 → 資訊類別「保險商品」（2026-10-23 實測，見盤點紀錄第五節）
- API 回傳各項目的分類與 PDF 網址（要帶 Content-Type: application/json，否則回 406）
- 「商品名稱與核准…文號」：每個分類一份 PDF，表格「商品名稱｜日期｜文號」
- 「契約條款」：每個分類一份索引 PDF，每列「商品名稱｜請按此下載」，連結檔名＝商品代碼
- 團體人身保險商品不收（2026-10-23 沛沛決定先收個人保險）
"""

import io
import json
from typing import Dict, List, Optional

import pdfplumber

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

SITE = "https://www.nanshanlife.com.tw/nanshanlife"
COMPANY_PREFIX = "南山人壽"
API_URL = SITE + "/portal-api/DataSource/public_information_type/162"
PAGE_URL = SITE + "/about-public-info"
PRODUCT_LIST_TITLE = "商品名稱與核准、核備或備查日期及文號"
CLAUSE_TITLE = "契約條款"
SKIPPED_CATEGORY_KEYWORDS = ["團體"]


def fetch_category_files() -> Dict[str, Dict[str, str]]:
    """回傳 {項目名稱: {分類名稱: PDF 網址}}。"""
    response_bytes = download(API_URL, headers={"Content-Type": "application/json"})
    response_data = json.loads(response_bytes.decode("utf-8"))

    files_by_title: Dict[str, Dict[str, str]] = {}
    for data_item in response_data.get("datas", []):
        content = json.loads(data_item.get("content") or "{}")
        files_by_title[data_item.get("name", "")] = _category_files_in_content(content)
    return files_by_title


def _category_files_in_content(content: dict) -> Dict[str, str]:
    category_files: Dict[str, str] = {}
    for language in content.get("languages", []):
        for block in language.get("blocks", []):
            for template in block.get("templates", []):
                for group_field in template.get("groupFields", []):
                    for row_fields in group_field.get("fields", []):
                        values = {field.get("fieldId"): field.get("fieldVal") for field in row_fields}
                        category_name = values.get("name") or ""
                        file_path = values.get("primary-url") or ""
                        if category_name and file_path.endswith(".pdf"):
                            category_files[category_name] = SITE + file_path
    return category_files


def _is_skipped(category_name: str) -> bool:
    return any(keyword in category_name for keyword in SKIPPED_CATEGORY_KEYWORDS)


def parse_product_list(pdf_url: str, category_name: str) -> List[Product]:
    products: List[Product] = []
    for row in download_pdf_tables(pdf_url):
        if not row:
            continue
        name_text = clean_product_name(row[0] or "")
        approval_text = " ".join(cell for cell in row[1:] if cell)

        if name_text.startswith("商品名稱"):
            continue
        # 不是「南山人壽」開頭：表頭殘片、文號續行或換頁後的名稱後半段
        if not name_text.startswith(COMPANY_PREFIX):
            if products and (name_text or approval_text) and not _is_header_fragment(approval_text):
                append_continuation(products[-1], name_text, approval_text)
            continue

        product = Product(product_name=name_text, source_category=category_name, source_url=pdf_url)
        set_approval(product, approval_text)
        products.append(product)
    return products


def _is_header_fragment(approval_text: str) -> bool:
    """每頁表頭會被拆成好幾列（「核准、核備」「或備查日期」），不能接到商品上。"""
    return any(keyword in approval_text for keyword in ["核准、核備", "或備查日期", "備查文號"])


def parse_clause_index(pdf_url: str) -> List[ClauseLink]:
    """索引 PDF 的每一列：用表格列的上下範圍，找出落在這一列的超連結。"""
    pdf_bytes = download(pdf_url)
    clause_links: List[ClauseLink] = []
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            page_links = [link for link in page.hyperlinks if link.get("uri")]
            for table in page.find_tables():
                for row in table.rows:
                    clause_link = _clause_link_in_row(page, row, page_links)
                    if clause_link is not None:
                        clause_links.append(clause_link)
    return clause_links


def _clause_link_in_row(page, row, page_links) -> Optional[ClauseLink]:
    name_cell_box = row.cells[0]
    if name_cell_box is None:
        return None
    product_name = clean_product_name(page.crop(name_cell_box).extract_text() or "")
    if not product_name or product_name.startswith("商品名稱"):
        return None

    row_top = row.bbox[1]
    row_bottom = row.bbox[3]
    for link in page_links:
        link_middle = (link["top"] + link["bottom"]) / 2
        if row_top - 1 <= link_middle <= row_bottom + 1:
            return ClauseLink(
                product_name=product_name,
                clause_url=link["uri"],
                product_code=code_from_filename(link["uri"]),
            )
    return None


def crawl() -> CompanyResult:
    files_by_title = fetch_category_files()
    product_list_files = files_by_title.get(PRODUCT_LIST_TITLE, {})
    clause_index_files = files_by_title.get(CLAUSE_TITLE, {})
    if not product_list_files:
        raise ValueError("南山 API 找不到商品清單，網站可能改版了")

    products: List[Product] = []
    for category_name, pdf_url in product_list_files.items():
        if not _is_skipped(category_name):
            products.extend(parse_product_list(pdf_url, category_name))

    clause_links: List[ClauseLink] = []
    for category_name, pdf_url in clause_index_files.items():
        if not _is_skipped(category_name):
            clause_links.extend(parse_clause_index(pdf_url))

    merge_clause_links(products, clause_links)
    return CompanyResult(
        company_code="nanshan",
        company_name="南山人壽",
        products=finish_products(products),
    )
