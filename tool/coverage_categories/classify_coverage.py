"""
把商品目錄的每款商品分到「保單健檢」的保障類別（第 5 階段 D；設計見全景地圖 4-L）

用法：
    python3 tool/coverage_categories/classify_coverage.py 目錄JSON資料夾 [條款下載快取資料夾]

目錄 JSON 用 tool/product_catalog/crawl_products.py --dry-run 產生。
1. 先用商品名稱判斷（大部分商品名稱就看得出來）
2. 名稱看不出來的醫療險，下載官方條款，用條款裡的關鍵字判斷
3. 有實支實付限額表的商品（tool/benefit_plans/targets.json）一律是實支實付
輸出 coverage_categories.json；人工核對後由 build_seed_sql.py 產生匯入檔。
"""
import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_DIR = os.path.dirname(os.path.dirname(TOOL_DIR))
OUTPUT_PATH = os.path.join(TOOL_DIR, 'coverage_categories.json')
# 讀條款後人工判斷的結果（附理由），優先於自動判斷
MANUAL_OVERRIDES_PATH = os.path.join(TOOL_DIR, 'manual_overrides.json')
BENEFIT_TARGETS_PATH = os.path.join(REPOSITORY_DIR, 'tool', 'benefit_plans', 'targets.json')

# 健檢用的保障類別；none＝不列入健檢（批註、豁免、投資、年金、旅平…）
CATEGORIES = ['life', 'accident', 'reimbursement', 'daily_hospital', 'surgery',
              'cancer', 'critical_illness', 'long_term_care', 'none']

# 名稱看不出來時，條款裡這些關鍵字出現越多次，越可能是那一類
CLAUSE_KEYWORDS = {
    'cancer': r'癌症',
    'critical_illness': r'重大傷病|重大疾病|特定傷病',
    'long_term_care': r'長期照顧|失能扶助|失能保險金',
    'surgery': r'手術保險金|手術醫療保險金',
    'daily_hospital': r'住院日額|住院醫療保險金|每日.{0,6}保險金',
}


def classify_by_name(product, reimbursement_names):
    """回傳 (類別, 依據)；看不出來回傳 (None, '')"""
    name = product['product_name']
    insurance_type = product.get('insurance_type') or 'other'
    if product.get('product_kind') == 'endorsement':
        return 'none', 'rule:批註條款'
    if name in reimbursement_names:
        return 'reimbursement', 'rule:有實支實付限額表'
    if re.search(r'豁免', name):
        return 'none', 'rule:保費豁免'
    if insurance_type in ('investment', 'annuity'):
        return 'none', 'rule:投資型／年金'
    if re.search(r'海外|旅行|旅平|暢遊', name):
        return 'none', 'rule:旅平／海外短期'
    # 「傷害失能」是意外險（一次給付），不是長照（2026-10-27 沛沛測試：200 萬被算成每月）
    if insurance_type == 'long_term_care' or (re.search(r'失能', name) and not re.search(r'傷害|意外', name)):
        return 'long_term_care', 'rule:名稱'
    if insurance_type == 'cancer':
        return 'cancer', 'rule:名稱'
    if insurance_type == 'critical_illness' or re.search(r'傷病', name):
        return 'critical_illness', 'rule:名稱'
    if insurance_type == 'accident':
        # 傷害醫療（意外醫療）不是八大保障之一，第一版不列入
        if re.search(r'醫療', name):
            return 'none', 'rule:意外醫療'
        return 'accident', 'rule:名稱'
    if insurance_type == 'medical':
        # 名稱有「傷害／意外」的醫療險是意外醫療，不是八大保障之一
        if re.search(r'傷害|意外', name):
            return 'none', 'rule:意外醫療'
        if re.search(r'手術|處置', name) and not re.search(r'住院醫療', name):
            return 'surgery', 'rule:名稱'
        if re.search(r'日額|定額', name):
            return 'daily_hospital', 'rule:名稱'
        return None, ''
    if insurance_type == 'life' or re.search(r'外幣保險|壽險', name):
        return 'life', 'rule:名稱'
    return None, ''


def download_clause(url, cache_dir):
    os.makedirs(cache_dir, exist_ok=True)
    path = os.path.join(cache_dir, hashlib.md5(url.encode('utf-8')).hexdigest() + '.pdf')
    if not os.path.exists(path):
        safe_url = urllib.parse.quote(url, safe=':/?&=%#')
        request = urllib.request.Request(safe_url, headers={'User-Agent': 'Mozilla/5.0'})
        data = urllib.request.urlopen(request, timeout=60).read()
        if not data.startswith(b'%PDF-'):
            raise RuntimeError('下載到的不是 PDF（官網可能在維護）')
        with open(path, 'wb') as file:
            file.write(data)
    return path


def classify_by_clause(product, cache_dir):
    """讀條款前 20 頁，算各類關鍵字出現次數，取最多的；回傳 (類別, 依據, 次數說明)"""
    import pdfplumber  # 只有需要讀條款時才載入
    url = product.get('clause_url') or ''
    if not url.startswith('https://'):
        return None, '', '沒有條款連結'
    try:
        path = download_clause(url, cache_dir)
        with pdfplumber.open(path) as pdf:
            text = ''.join((page.extract_text() or '') for page in pdf.pages[:20])
    except Exception as error:  # 下載或讀取失敗就交給人工
        return None, '', f'條款讀取失敗：{error}'
    flat = re.sub(r'\s+', '', text)
    counts = {category: len(re.findall(pattern, flat)) for category, pattern in CLAUSE_KEYWORDS.items()}
    best = max(counts, key=counts.get)
    summary = '、'.join(f'{category}={count}' for category, count in counts.items())
    if counts[best] == 0:
        return None, '', summary
    return best, 'clause:條款關鍵字', summary


def load_catalog(catalog_dir):
    products = []
    for file_name in sorted(os.listdir(catalog_dir)):
        if not file_name.endswith('.json'):
            continue
        with open(os.path.join(catalog_dir, file_name), encoding='utf-8') as file:
            data = json.load(file)
        # crawl_products.py 的檔案：外層是公司資訊，商品放在 products 裡（商品本身沒有 company_code）
        company_code = data.get('company_code') if isinstance(data, dict) else None
        if isinstance(data, dict):
            data = data.get('products', data.get('items', []))
        for product in data:
            product.setdefault('company_code', company_code)
        products.extend(data)
    return products


def main():
    catalog_dir = sys.argv[1]
    cache_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(TOOL_DIR, '.cache')
    with open(BENEFIT_TARGETS_PATH, encoding='utf-8') as file:
        reimbursement_names = {target['product_name'] for target in json.load(file)}

    with open(MANUAL_OVERRIDES_PATH, encoding='utf-8') as file:
        overrides = {item['product_name']: item for item in json.load(file)}

    results = []
    for product in load_catalog(catalog_dir):
        detail = ''
        override = overrides.get(product['product_name'])
        if override:
            category, basis, detail = override['coverage_category'], 'manual:讀條款人工判斷', override['reason']
        else:
            category, basis = classify_by_name(product, reimbursement_names)
            if category is None and product.get('insurance_type') == 'medical':
                category, basis, detail = classify_by_clause(product, cache_dir)
        if category is None:
            # 名稱和條款都看不出來：先不列入健檢，業務員可以在客戶保單上自己改類別
            category, basis = 'none', 'manual:名稱看不出來，先不列入'
        results.append({
            'company_code': product['company_code'],
            'product_name': product['product_name'],
            'insurance_type': product.get('insurance_type'),
            'coverage_category': category,
            'basis': basis,
            'clause_keyword_counts': detail,
            'clause_url': product.get('clause_url'),
        })

    with open(OUTPUT_PATH, 'w', encoding='utf-8') as file:
        json.dump(results, file, ensure_ascii=False, indent=2)
    counts = {}
    for result in results:
        counts[result['coverage_category']] = counts.get(result['coverage_category'], 0) + 1
    print('已輸出', OUTPUT_PATH, len(results), '款', counts)
    print('條款判斷', sum(1 for r in results if r['basis'].startswith('clause')), '款；待人工',
          sum(1 for r in results if r['basis'].startswith('manual')), '款')


if __name__ == '__main__':
    main()
