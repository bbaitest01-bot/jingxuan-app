"""商品目錄抓取的共用工具：下載、民國日期、文號解析、商品分類。

設計見全景地圖 4-H。三家公司各自的解析放在 cathay.py、fubon.py、nanshan.py。
"""

import io
import re
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from datetime import date
from typing import List, Optional

import pdfplumber

# 每次請求之間至少間隔幾秒（對官網有禮貌，見全景地圖 4-H ④ 爬蟲規則）
REQUEST_INTERVAL_SECONDS = 3.0
USER_AGENT = "Mozilla/5.0 (compatible; jingxuan-app/product-catalog; +https://github.com/bbaitest01-bot/jingxuan-app)"

_last_request_time = 0.0


@dataclass
class Product:
    """一款商品，欄位對應資料表 insurance_products。"""

    product_name: str
    source_category: str
    source_url: str
    product_code: Optional[str] = None
    approval_date: Optional[str] = None  # 西元日期字串 YYYY-MM-DD
    approval_number: Optional[str] = None
    approval_history: Optional[str] = None
    clause_url: Optional[str] = None
    product_kind: str = "main"
    insurance_type: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "product_name": self.product_name,
            "product_code": self.product_code,
            "product_kind": self.product_kind,
            "insurance_type": self.insurance_type,
            "source_category": self.source_category,
            "approval_date": self.approval_date,
            "approval_number": self.approval_number,
            "approval_history": self.approval_history,
            "clause_url": self.clause_url,
            "source_url": self.source_url,
        }


@dataclass
class ClauseLink:
    """官網上一份條款檔案：商品名稱、條款網址、商品代碼。"""

    product_name: str
    clause_url: str
    product_code: Optional[str] = None


@dataclass
class CompanyResult:
    """一家公司這次抓到的全部商品。"""

    company_code: str
    company_name: str
    products: List[Product] = field(default_factory=list)


def download(url: str, headers: Optional[dict] = None, retry_count: int = 2) -> bytes:
    """下載網址內容；網路暫時不穩時，等一下再重試（最多 retry_count 次）。"""
    for attempt in range(retry_count + 1):
        try:
            return _download_once(url, headers)
        except OSError:
            # urllib 的連線錯誤、逾時都屬於 OSError；最後一次還失敗就交給呼叫的人處理
            if attempt == retry_count:
                raise
            time.sleep(10 * (attempt + 1))
    raise RuntimeError("不會走到這裡")


def _download_once(url: str, headers: Optional[dict]) -> bytes:
    """下載一次；和上一次請求至少間隔 REQUEST_INTERVAL_SECONDS 秒。"""
    global _last_request_time
    waiting_seconds = REQUEST_INTERVAL_SECONDS - (time.time() - _last_request_time)
    if waiting_seconds > 0:
        time.sleep(waiting_seconds)

    request_headers = {"User-Agent": USER_AGENT}
    if headers:
        request_headers.update(headers)
    # 網址裡的中文要先編碼，否則 urllib 會出錯
    safe_url = urllib.parse.quote(url, safe=":/?=&%")
    request = urllib.request.Request(safe_url, headers=request_headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read()
    finally:
        _last_request_time = time.time()


def _is_not_fill_strip(page_object: dict) -> bool:
    """國泰的 PDF 每行文字底下有淡色底色長條（高度 3～40），會被誤認成格線，要先拿掉。"""
    is_rect = page_object.get("object_type") == "rect"
    return not (is_rect and 3 < page_object.get("height", 0) < 40)


def _extract_rows(pdf_bytes: bytes, ignore_fill_strips: bool) -> List[List[Optional[str]]]:
    all_rows: List[List[Optional[str]]] = []
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            if ignore_fill_strips:
                page = page.filter(_is_not_fill_strip)
            for table in page.extract_tables():
                all_rows.extend(table)
    return all_rows


def _count_rows_starting_with(rows: List[List[Optional[str]]], prefix: str) -> int:
    count = 0
    for row in rows:
        if row and (row[0] or "").strip().startswith(prefix):
            count += 1
    return count


def download_pdf_tables(url: str, company_prefix: Optional[str] = None) -> List[List[Optional[str]]]:
    """下載 PDF，回傳所有頁面表格的每一列（每列是一串儲存格文字）。

    有給 company_prefix 時，兩種讀法都試（一般／忽略底色長條），
    哪一種讀出比較多「公司名開頭」的商品列，就用哪一種。
    """
    pdf_bytes = download(url)
    normal_rows = _extract_rows(pdf_bytes, ignore_fill_strips=False)
    if company_prefix is None:
        return normal_rows

    filtered_rows = _extract_rows(pdf_bytes, ignore_fill_strips=True)
    normal_count = _count_rows_starting_with(normal_rows, company_prefix)
    filtered_count = _count_rows_starting_with(filtered_rows, company_prefix)
    if filtered_count > normal_count:
        return filtered_rows
    return normal_rows


def set_approval(product: Product, approval_text: str) -> None:
    """解析文號原文，填進商品的日期、文號、原文三個欄位。"""
    approval = parse_approval(approval_text)
    product.approval_date = approval["approval_date"]
    product.approval_number = approval["approval_number"]
    product.approval_history = approval["approval_history"]


def append_continuation(product: Product, name_fragment: str, approval_text: str) -> None:
    """表格換行或換頁時，名稱後半段與文號續行會變成新的一列，接回上一款商品。"""
    if name_fragment:
        product.product_name += name_fragment
    if approval_text:
        set_approval(product, (product.approval_history or "") + "\n" + approval_text)


def normalize_name_key(name: str) -> str:
    """比對商品名稱用：去掉所有空白，全形括號改半形。"""
    without_spaces = re.sub(r"\s+", "", name)
    return without_spaces.replace("（", "(").replace("）", ")")


def clean_product_name(raw_name: str) -> str:
    """儲存格裡的名稱可能被換行切開，接回一行。"""
    lines = [line.strip() for line in raw_name.splitlines()]
    return "".join(lines).strip()


# 民國日期兩種寫法：115.09.08、中華民國94年9月26日
_ROC_DOT_DATE = re.compile(r"(\d{2,3})\s*\.\s*(\d{1,2})\s*\.\s*(\d{1,2})")
_ROC_TEXT_DATE = re.compile(r"(?:中華)?民國\s*(\d{2,3})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日")
# 文號：例如「國壽字第109060261號」「金管保壽字第 1130427324 號」
# 字號前面只接中文與括號，避免把前面的日期數字也吃進來
# 很舊的文號沒有「字」，例如「台財保第842028671號」；一-鿿 是中文字的範圍
_APPROVAL_NUMBER = re.compile(r"[一-鿿()（）]{1,12}?字?第[0-9A-Za-z]+號")


# 完整的商品名稱通常以這些字結尾；不是的話，多半是被換頁切斷了
_COMPLETE_NAME_ENDING = re.compile(r"(險|條款|附約|約定|特約|保單|型|\)|）|】|\d)$")


def looks_incomplete(product_name: str) -> bool:
    """名稱看起來還沒結束（例：「…利率變動型即期」），下一列很可能是後半段。"""
    return _COMPLETE_NAME_ENDING.search(product_name) is None


def roc_to_iso(year_text: str, month_text: str, day_text: str) -> Optional[str]:
    """民國年月日轉成西元 YYYY-MM-DD；日期不合理就回傳 None。"""
    try:
        return date(int(year_text) + 1911, int(month_text), int(day_text)).isoformat()
    except ValueError:
        return None


def parse_approval(approval_text: str) -> dict:
    """從文號欄位的原文找出第一個日期與第一個文號，原文保留在 approval_history。"""
    history_lines = [line.strip() for line in approval_text.splitlines() if line.strip()]
    history = "\n".join(history_lines)

    approval_date: Optional[str] = None
    date_match = _ROC_DOT_DATE.search(history) or _ROC_TEXT_DATE.search(history)
    if date_match:
        approval_date = roc_to_iso(date_match.group(1), date_match.group(2), date_match.group(3))

    approval_number: Optional[str] = None
    number_match = _APPROVAL_NUMBER.search(history.replace(" ", ""))
    if number_match:
        approval_number = number_match.group(0)

    return {
        "approval_date": approval_date,
        "approval_number": approval_number,
        "approval_history": history or None,
    }


def classify_product_kind(product_name: str) -> str:
    """依名稱判斷：批註／附加條款 → endorsement，附約 → rider，其餘 → main。"""
    if re.search(r"批註|附加條款|附加約定|特約|約定書", product_name):
        return "endorsement"
    if "附約" in product_name:
        return "rider"
    return "main"


# 險種判斷規則：依序比對，第一個符合的就是答案（越具體的放越前面）
_INSURANCE_TYPE_RULES = [
    ("investment", r"變額|投資型|投資連結|萬能"),
    ("annuity", r"年金"),
    ("long_term_care", r"長期照顧|長照|長期看護|失能扶助|類長照"),
    ("cancer", r"癌"),
    ("critical_illness", r"重大疾病|重大傷病|特定傷病|重症"),
    # 傷害醫療、意外住院日額是意外險（2026-10-30 D22 沛沛：放在「意外傷害」才找得到），要排在醫療前面
    ("accident", r"傷害醫療|意外.{0,6}(?:醫療|住院|日額)|傷害.{0,4}住院"),
    ("medical", r"醫療|住院|手術|門診|健康保險|日額"),
    ("accident", r"傷害|意外|旅行平安|旅平"),
    ("life", r"壽險|壽險保險|終身保險|定期保險|生死合險|養老"),
]


def classify_insurance_type(product_name: str) -> str:
    """依名稱關鍵字判斷險種；判斷不出來就是 other。"""
    for insurance_type, pattern in _INSURANCE_TYPE_RULES:
        if re.search(pattern, product_name):
            return insurance_type
    return "other"


def code_from_filename(url: str, pattern: str = r"^[A-Za-z0-9]{2,12}$") -> Optional[str]:
    """條款檔名就是商品代碼（例：C64.pdf → C64）；檔名不像代碼就回傳 None。"""
    filename = urllib.parse.unquote(url.rsplit("/", 1)[-1])
    stem = filename.rsplit(".", 1)[0]
    if re.match(pattern, stem):
        return stem.upper()
    return None


def merge_clause_links(products: List[Product], clause_links: List[ClauseLink]) -> None:
    """把條款連結與商品代碼，依名稱對到商品清單上（直接修改 products）。"""
    links_by_name = {}
    for clause_link in clause_links:
        links_by_name.setdefault(normalize_name_key(clause_link.product_name), clause_link)

    for product in products:
        clause_link = links_by_name.get(normalize_name_key(product.product_name))
        if clause_link is None:
            continue
        product.clause_url = clause_link.clause_url
        if clause_link.product_code:
            product.product_code = clause_link.product_code


def finish_products(products: List[Product]) -> List[Product]:
    """補上分類、同名只留第一筆（同一款商品可能出現在兩份清單）。"""
    unique_products: List[Product] = []
    seen_names = set()
    for product in products:
        name_key = normalize_name_key(product.product_name)
        if not product.product_name or name_key in seen_names:
            continue
        seen_names.add(name_key)
        product.product_kind = classify_product_kind(product.product_name)
        product.insurance_type = classify_insurance_type(product.product_name)
        unique_products.append(product)
    resolve_shared_clause_links(unique_products)
    return unique_products


def _comparable_name(text: str) -> str:
    """比對名稱用：去空白、全形半形括號統一"""
    return re.sub(r'\s', '', text).replace('(', '（').replace(')', '）')


def resolve_shared_clause_links(products: List[Product]) -> None:
    """兩款以上商品拿到同一個條款連結時（清單某一列沒有連結、借到隔壁列的），
    下載那份條款看封面是哪一款，只留給名稱對得上的；其他的清空，寧可沒有也不要給錯（2026-10-30 D24）"""
    products_by_url = {}
    for product in products:
        if product.clause_url:
            products_by_url.setdefault(product.clause_url, []).append(product)
    for url, sharing_products in products_by_url.items():
        if len(sharing_products) < 2:
            continue
        try:
            with pdfplumber.open(io.BytesIO(download(url))) as pdf:
                cover_text = _comparable_name(pdf.pages[0].extract_text() or '')
        except Exception as error:  # 下載不到就全部清空，下次再抓
            print(f'  ⚠️ 條款連結重複又下載不到，先清空：{url}（{error}）')
            cover_text = ''
        for product in sharing_products:
            name_key = _comparable_name(product.product_name)
            if name_key and name_key in cover_text:
                continue
            print(f'  ⚠️ 條款連結和別款重複且封面不是這款，清空：{product.product_name}')
            product.clause_url = None
            product.product_code = None
