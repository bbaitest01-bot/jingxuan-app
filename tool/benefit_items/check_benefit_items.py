"""給付項目固定檢查（2026-10-30 D23，沛沛要求：每次整理條款資料都要自動檢查，不能越對越多錯）

產生匯入檔（build_seed_sql.py）前一定要先通過。檢查三件事：
1. 漏抓：條款每一條標題「第○條 ○○保險金的給付」，都要在這款商品的項目裡
2. 數字：算法裡的數字（10%、2 倍、5 萬元）要在那一條條文或附表裡找得到
3. 標準答案：benefit_items_verified.json 裡人工核對過的項目，算法要一模一樣（改規則時不會把對的改壞）

快速檢查：讀條款的規則（extract_benefit_items.py）從上次全部檢查後沒改過，
每月一鍵更新只檢查新的或有變動的商品＋標準答案（幾十秒）；規則改過就自動全部檢查（約 5 分鐘）。

確定不是錯的（例：「喪葬費用保險金」就是身故的另一種說法），寫進 check_exceptions.json 並寫理由。

執行：python3 tool/benefit_items/check_benefit_items.py
全部通過回傳 0；有問題列出清單並回傳 1。
"""
import hashlib
import json
import os
import re
import sys
from datetime import date

import extract_benefit_items as extractor

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
ITEMS_FILE = os.path.join(TOOL_DIR, 'benefit_items_auto.json')
VERIFIED_FILE = os.path.join(TOOL_DIR, 'benefit_items_verified.json')
EXCEPTIONS_FILE = os.path.join(TOOL_DIR, 'check_exceptions.json')
CACHE_DIR = os.path.join(TOOL_DIR, '.cache')
# 上次「全部檢查」通過時的規則指紋（2026-10-30 D24：規則沒改時，每月只查新的或有變動的商品）
FULL_CHECK_FILE = os.path.join(TOOL_DIR, 'last_full_check.json')

# 算法裡不用比對的數字：1 倍（保額 × 1）太常見，條款也常寫成「保險金額」不寫一
IGNORED_NUMBERS = {1.0}


def numbers_in_text(text):
    """條款裡出現的所有數字（阿拉伯數字和國字都轉成數字）"""
    numbers = set()
    for match in re.finditer(r'\d[\d,]*(?:\.\d+)?', text):
        numbers.add(float(match.group(0).replace(',', '')))
    for match in re.finditer(r'[零一二兩三四五六七八九十百千仟萬點]+', text):
        value = extractor.chinese_to_number(match.group(0).replace('仟', '千'))
        if value is not None:
            numbers.add(value)
    return numbers


def title_item_keys(text):
    """條款標題「第十條滿期保險金的給付」裡的項目（「或」後面是同一項的另一種說法，不算）"""
    keys = set()
    pattern = r'第[一二三四五六七八九十百]+條【?(?:保險範圍：)?([^第】。，]{2,40}?)的給付'
    for title in re.finditer(pattern, text):
        for name in re.split(r'[、及與和]', title.group(1).split('或')[0]):
            name = name.strip('「」『』')
            if name.endswith('保險金') and len(name) > 3:
                keys.add(extractor.normalize_item_key(name))
    return keys


def check_missing_items(product, text):
    item_keys = {item['item_key'] for item in product['items']}
    problems = []
    for key in sorted(title_item_keys(text)):
        # 名稱有包含關係也算有（例：「癌症住院醫療」和「癌症住院醫療（重度）」）
        if any(key in item_key or item_key in key for item_key in item_keys):
            continue
        problems.append(f'漏抓：條款標題有「{key}」，項目裡沒有')
    return problems


def article_text(text, item):
    """這一項的條文：從標題「○○保險金的給付」到下一條；找不到標題就用出處那一句"""
    match = re.search(re.escape(item['item_name']) + r'[」』]?[的之]給付', text)
    if not match:
        return item['excerpt']
    segment = text[match.start():match.start() + 1500]
    next_article = re.search(r'(?<=。)第[一二三四五六七八九十百]+條', segment[10:])
    if next_article:
        segment = segment[:next_article.start() + 10]
    return segment + item['excerpt']


def check_formula_numbers(product, text, table_numbers):
    problems = []
    for item in product['items']:
        formula = item['formula'] or ''
        # 只在這一條條文和附表裡找（整份條款太大，數字常常剛好在別處出現）
        clause_numbers = numbers_in_text(article_text(text, item)) | table_numbers
        for number_text in re.findall(r'\d[\d,]*(?:\.\d+)?', formula):
            number = float(number_text.replace(',', ''))
            if number in IGNORED_NUMBERS:
                continue
            # 「200萬」在條款可能寫 2,000,000；「1,000 元」可能寫「一千元」
            if {number, number * 10000, number / 10000} & clause_numbers:
                continue
            problems.append(f'數字：「{item["item_key"]}」寫 {formula}，條款找不到 {number_text}')
    return problems


def check_verified(products_by_name, verified_items):
    problems = []
    for verified in verified_items:
        product = products_by_name.get(verified['product_name'])
        if product is None:
            problems.append(f'標準答案：找不到商品「{verified["product_name"]}」')
            continue
        current = {item['item_key']: item['formula'] for item in product['items']}
        if verified['item_key'] not in current:
            problems.append(f'標準答案：「{verified["product_name"]}」少了「{verified["item_key"]}」')
        elif current[verified['item_key']] != verified['formula']:
            problems.append(
                f'標準答案：「{verified["product_name"]}」的「{verified["item_key"]}」'
                f'應該是 {verified["formula"]}，現在是 {current[verified["item_key"]]}'
            )
    return problems


def load_json(path, default):
    if not os.path.exists(path):
        return default
    with open(path, encoding='utf-8') as file:
        return json.load(file)


def rules_fingerprint():
    """讀條款規則（extract_benefit_items.py）的指紋：程式一改，指紋就變"""
    with open(extractor.__file__, 'rb') as file:
        return hashlib.sha256(file.read()).hexdigest()


def rules_unchanged_since_full_check():
    """上次「全部檢查」通過之後，規則有沒有被改過"""
    return load_json(FULL_CHECK_FILE, {}).get('rules_fingerprint') == rules_fingerprint()


def record_full_check(product_count):
    with open(FULL_CHECK_FILE, 'w', encoding='utf-8') as file:
        json.dump({'rules_fingerprint': rules_fingerprint(), 'checked_at': date.today().isoformat(),
                   'product_count': product_count}, file, ensure_ascii=False, indent=1)


def run_checks(only_product_names=None):
    """回傳 (檢查的商品數, 問題清單)；問題是 (商品名稱, 說明)
    only_product_names：只檢查這些商品（規則沒改時的快速檢查）；標準答案一律全部檢查"""
    all_products = [product for product in load_json(ITEMS_FILE, []) if product['items']]
    products = all_products
    if only_product_names is not None:
        products = [product for product in all_products if product['product_name'] in only_product_names]
    exceptions = {(entry['product_name'], entry['problem']) for entry in load_json(EXCEPTIONS_FILE, [])}
    problems = []
    for product in products:
        try:
            path = extractor.download_clause(product['clause_url'], CACHE_DIR)
            text, tables = extractor.read_clause(path)
        except Exception as error:  # 條款下載不到：記下來，不當成資料錯
            problems.append((product['product_name'], f'讀不到條款：{error}'))
            continue
        table_text = ' '.join(extractor.clean_cell(cell) for table in tables for row in table for cell in row)
        found = check_missing_items(product, text) + check_formula_numbers(product, text, numbers_in_text(table_text))
        for problem in found:
            problems.append((product['product_name'], problem))

    products_by_name = {product['product_name']: product for product in all_products}
    for problem in check_verified(products_by_name, load_json(VERIFIED_FILE, [])):
        problems.append(('（標準答案）', problem))

    remaining = [(name, problem) for name, problem in problems if (name, problem) not in exceptions]
    return len(products), remaining


def main(only_product_names=None):
    product_count, problems = run_checks(only_product_names)
    if not problems:
        if only_product_names is None:
            record_full_check(product_count)
            print(f'✅ 給付項目檢查通過（全部）：{product_count} 款商品')
        else:
            print(f'✅ 給付項目檢查通過（快速：規則沒改，只查新的或有變動的 {product_count} 款＋標準答案）')
        return 0
    print(f'❌ 給付項目檢查：{len(problems)} 個問題（{product_count} 款商品）')
    for name, problem in problems:
        print(f'  - {name}：{problem}')
    print('\n確定不是錯的，寫進 check_exceptions.json（含理由）；其他要先修好再產生匯入檔。')
    return 1


if __name__ == '__main__':
    sys.exit(main())
