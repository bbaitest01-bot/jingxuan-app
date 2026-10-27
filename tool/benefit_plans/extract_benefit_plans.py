"""
從官方條款 PDF 讀出「實支實付給付限額表」（第 5 階段 D14；設計見全景地圖 4-K）

用法：
    python3 tool/benefit_plans/extract_benefit_plans.py [下載快取資料夾]

讀 targets.json 裡 mode=auto 的商品：下載條款 → 找出有計畫欄位的給付表 → 每一列對到 7 個比較項目，
輸出 benefit_plans_auto.json。程式讀出來的只是草稿，一定要再人工核對（沛沛抽查）才匯入。
限額寫在條文句子裡、或總額型的商品（mode=manual）由人工整理在 manual_plans.json。
"""
import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request

import pdfplumber

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
TARGETS_PATH = os.path.join(TOOL_DIR, 'targets.json')
OUTPUT_PATH = os.path.join(TOOL_DIR, 'benefit_plans_auto.json')

# 表頭第一格有這些字，才當成「計畫別」表頭
PLAN_HEADER_PATTERN = re.compile(r'計畫|計劃|項目')
# 給付表一定會有病房或住院醫療費用這類的列，沒有的表格（例如疫苗清單）跳過
BENEFIT_TABLE_PATTERN = re.compile(r'病房|經常費用|雜費|住院醫療費用')
# 實支實付的表一定寫「限額」或「自負額」；只寫「金額」的是定額給付表（例：南山實健溢百的實支前給付），不讀
REIMBURSEMENT_TABLE_PATTERN = re.compile(r'限額|自負額')
# 「先定額、後實支」的商品（富邦實在滿溢、南山實健溢百）：啟動日前的定額表不讀
PRE_ACTIVATION_PATTERN = re.compile(r'啟動日前|實支實付前')


def download_pdf(url, cache_dir):
    """下載條款（已下載過就用快取）；拿到的不是 PDF（例如官網維護公告）就報錯"""
    os.makedirs(cache_dir, exist_ok=True)
    # 用網址的雜湊當檔名：富邦好幾份條款網址結尾都是「…一年期住院醫療健康保險附約.pdf」，截取結尾會撞名
    file_name = hashlib.md5(url.encode('utf-8')).hexdigest() + '.pdf'
    path = os.path.join(cache_dir, file_name)
    if not os.path.exists(path):
        safe_url = urllib.parse.quote(url, safe=':/?&=%#')
        request = urllib.request.Request(safe_url, headers={'User-Agent': 'Mozilla/5.0'})
        data = urllib.request.urlopen(request, timeout=60).read()
        if not data.startswith(b'%PDF-'):
            raise RuntimeError('下載到的不是 PDF（官網可能在維護）：' + url)
        with open(path, 'wb') as file:
            file.write(data)
    return path


def parse_amount(text):
    """「7萬」「1.5萬」「1,000」「250萬」→ 整數元；空白、「—」→ None"""
    cleaned = re.sub(r'\s', '', text or '').replace(',', '')
    if not cleaned or cleaned in ('—', '-', '－'):
        return None
    match = re.fullmatch(r'(\d+(?:\.\d+)?)萬(元)?', cleaned)
    if match:
        return int(round(float(match.group(1)) * 10000))
    match = re.fullmatch(r'(\d+)(元)?', cleaned)
    if match:
        return int(match.group(1))
    return None


def field_for_label(label):
    """表格左邊的項目名稱 → 資料表欄位；不在 7 個比較項目內的回傳 None"""
    if '自負額' in label:
        if '病房' in label or '經常費用' in label:
            return 'room_deductible'
        if '門診' in label:
            return 'outpatient_surgery_deductible'
        if '雜費' in label or '住院醫療費用' in label:
            return 'hospital_expense_deductible'
        return None
    if '總限額' in label or '總給付' in label:
        if '每次住院' in label:
            return 'per_admission_total_limit'
        if '每年' in label:
            return 'annual_total_limit'
        return 'lifetime_total_limit'
    if '病房' in label or '經常費用' in label:
        return 'room_daily_limit'
    if '門診手術' in label:
        return 'outpatient_surgery_limit'
    if '住院日額' in label or '日額保險金' in label or '醫療日額' in label:
        return 'daily_hospital_benefit'
    if '雜費' in label or '住院醫療費用' in label:
        return 'hospital_expense_limit'
    if '手術' in label:
        return 'surgery_limit'
    return None


def clean_cell(cell):
    return re.sub(r'\s+', '', cell or '')


def find_plan_header(table):
    """回傳 (表頭列位置, [(欄位位置, 計畫名稱)])；找不到回傳 (None, [])"""
    for row_index, row in enumerate(table[:3]):
        cells = [clean_cell(cell) for cell in row]
        if not cells or not PLAN_HEADER_PATTERN.search(cells[0]):
            continue
        plan_columns = []
        for column_index in range(1, len(cells)):
            if cells[column_index]:
                plan_columns.append((column_index, cells[column_index]))
        if plan_columns:
            return row_index, plan_columns
    return None, []


def parse_benefit_table(table, page_number, plans, warnings):
    """把一張給付表讀進 plans（{計畫名稱: {欄位: 金額}}）"""
    header_index, plan_columns = find_plan_header(table)
    if header_index is None:
        return False
    plan_column_indexes = {column for column, _ in plan_columns}
    previous_label = ''
    for row in table[header_index + 1:]:
        cells = [clean_cell(cell) for cell in row]
        # 左邊不是計畫欄的格子合起來當項目名稱（國泰有些表格把名稱拆成好幾格）
        label_parts = []
        for column_index, cell in enumerate(cells):
            if column_index not in plan_column_indexes and cell and parse_amount(cell) is None:
                label_parts.append(cell)
        label = ''.join(label_parts)
        # 「自負額」「限額」上下兩列共用一個項目名稱（富邦全鑫）
        if label in ('限額', '自負額') and previous_label:
            label = re.sub(r'(自負額|限額)$', '', previous_label) + label
        if label:
            previous_label = label
        field = field_for_label(label)
        if field is None:
            if label:
                warnings.append(f'p{page_number} 沒有對到比較項目：{label}')
            continue
        row_amounts = []
        for column_index, _ in plan_columns:
            cell = cells[column_index] if column_index < len(cells) else ''
            row_amounts.append(parse_amount(cell))
        # 合併儲存格：只有第一個計畫有數字、其他空白 → 所有計畫共用（例：國泰新實全心意門診自負額 1,000）
        if row_amounts and row_amounts[0] is not None and all(amount is None for amount in row_amounts[1:]):
            row_amounts = [row_amounts[0]] * len(row_amounts)
        for (column_index, plan_name), amount in zip(plan_columns, row_amounts):
            if amount is None:
                continue
            plan = plans.setdefault(plan_name, {'source_page': page_number})
            plan[field] = amount
            if field == 'hospital_expense_limit' and '手術' in label:
                plan['hospital_expense_includes_surgery'] = True
    return True


def extract_product(target, cache_dir):
    path = download_pdf(target['clause_url'], cache_dir)
    plans = {}
    warnings = []
    with pdfplumber.open(path) as pdf:
        for page_index, page in enumerate(pdf.pages):
            for table in page.extract_tables():
                flat_text = ''.join(clean_cell(cell) for row in table for cell in row)
                if PRE_ACTIVATION_PATTERN.search(flat_text):
                    continue
                if BENEFIT_TABLE_PATTERN.search(flat_text) and REIMBURSEMENT_TABLE_PATTERN.search(flat_text):
                    parse_benefit_table(table, page_index + 1, plans, warnings)
    plan_list = []
    for order, (plan_code, fields) in enumerate(plans.items(), start=1):
        has_deductible = any(key.endswith('_deductible') for key in fields)
        plan = {'plan_code': plan_code, 'plan_order': order,
                'benefit_type': 'deductible' if has_deductible else 'itemized'}
        plan.update(fields)
        # targets.json 可以補條款表格看不出來的事（例：國泰「住院醫療費用」含手術）
        plan.update(target.get('overrides', {}))
        if target.get('note'):
            plan['note'] = target['note']
        plan_list.append(plan)
    return {
        'company_code': target['company_code'],
        'product_name': target['product_name'],
        'clause_url': target['clause_url'],
        'plans': plan_list,
        'warnings': warnings,
    }


def main():
    cache_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(TOOL_DIR, '.cache')
    with open(TARGETS_PATH, encoding='utf-8') as file:
        targets = json.load(file)
    results = []
    for target in targets:
        if target['mode'] != 'auto':
            continue
        result = extract_product(target, cache_dir)
        print(f"{result['product_name']}：{len(result['plans'])} 個計畫，{len(result['warnings'])} 個沒對到的列")
        results.append(result)
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as file:
        json.dump(results, file, ensure_ascii=False, indent=2)
    print('已輸出', OUTPUT_PATH)


if __name__ == '__main__':
    main()
