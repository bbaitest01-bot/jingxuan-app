"""從條款抓「給付項目」與「怎麼算」（第 5 階段 D 第 2 層：住院日額、手術、癌症、重大傷病、長照、意外）

做法：
1. 讀 tool/coverage_categories/coverage_categories.json，挑出 6 類有條款連結的商品
2. 下載條款 PDF（快取檔名 md5(url).pdf），用 pdfplumber 讀文字
3. 每個「給付『○○保險金』」第一次出現＝一個給付項目（三家條款都用這個句型）
4. 在那一句找「怎麼算」：保險金額的百分之 N、乘以 N、每單位新臺幣 N 元；
   找不到就留空（畫面顯示「依條款」），一律附原文一句當出處，不猜

執行：venv2/bin/python tool/benefit_items/extract_benefit_items.py <條款快取資料夾>
輸出：tool/benefit_items/benefit_items_auto.json
"""
import hashlib
import json
import os
import re
import sys
import unicodedata
import urllib.parse
import urllib.request

import pdfplumber

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
CATEGORY_FILE = os.path.join(TOOL_DIR, '..', 'coverage_categories', 'coverage_categories.json')
OUTPUT_FILE = os.path.join(TOOL_DIR, 'benefit_items_auto.json')
TARGET_CATEGORIES = ['daily_hospital', 'surgery', 'cancer', 'critical_illness', 'long_term_care', 'accident', 'life']
MAX_PAGES = 30

CHINESE_NUMBERS = {'零': 0, '一': 1, '二': 2, '兩': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9}
# 不是給付項目的標題（限制、責任、扣除這類）
# 指稱其他條的寫法（各項保險金、前項保險金）不是項目名稱
LOOSE_REFERENCE_WORDS = ['各項', '本項', '該項', '前項', '其他', '相關', '之', '最高', '其中', '一項', '較嚴重', '金額', '指定', '開始日前', '增額繳清', '分期定期']
NOT_BENEFIT_WORDS = ['限制', '責任', '扣除', '申領', '受益人', '減少', '停止', '暫停', '方式', '上限', '總額', '文件']


def chinese_to_number(text):
    """「十五」→ 15、「百分之三十」裡的「三十」→ 30、「二百」→ 200；阿拉伯數字直接轉"""
    text = text.replace(',', '').replace('，', '')
    if re.fullmatch(r'\d+(?:\.\d+)?', text):
        return float(text)
    if '點' in text:
        whole, _, fraction = text.partition('點')
        whole_number = chinese_to_number(whole) or 0
        digits = ''.join(str(CHINESE_NUMBERS[char]) for char in fraction if char in CHINESE_NUMBERS)
        if not digits:
            return None
        return float(f'{int(whole_number)}.{digits}')
    total = 0
    current = 0
    for char in text:
        if char in CHINESE_NUMBERS:
            current = CHINESE_NUMBERS[char]
        elif char == '十':
            total += (current or 1) * 10
            current = 0
        elif char == '百':
            total += (current or 1) * 100
            current = 0
        elif char == '千':
            total += (current or 1) * 1000
            current = 0
        elif char == '萬':
            total = (total + current) * 10000
            current = 0
        else:
            return None
    return float(total + current)


def format_number(value):
    if value == int(value):
        return f'{int(value):,}'
    return f'{value:g}'


def download_clause(url, cache_dir):
    os.makedirs(cache_dir, exist_ok=True)
    path = os.path.join(cache_dir, hashlib.md5(url.encode('utf-8')).hexdigest() + '.pdf')
    if not os.path.exists(path):
        # 網址裡有中文要先編碼
        request = urllib.request.Request(urllib.parse.quote(url, safe=':/?=&%#'), headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(request, timeout=40) as response:
            data = response.read()
        with open(path, 'wb') as output:
            output.write(data)
    return path


def read_clause(path):
    """回傳（條款全文, 附表裡「每單位給付金額」那種表格）"""
    pages = []
    tables = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages[:MAX_PAGES]:
            pages.append(page.extract_text() or '')
            for table in page.extract_tables():
                if any('給付金額' in (cell or '') for row in table for cell in row):
                    tables.append(table)
    flat = re.sub(r'\s+', '', ''.join(pages))
    # 有些 PDF 的「年」「率」「金」用的是長得一樣、編碼不同的字（相容字、康熙部首），轉回一般的字
    flat = re.sub(r'[\u2F00-\u2FDF\uF900-\uFAFF]', lambda match: unicodedata.normalize('NFKC', match.group(0)), flat)
    # 去掉頁首頁尾「第 6 頁，共 35 頁」
    return re.sub(r'第\d+頁[，,]?共\d+頁', '', flat), tables


def clean_cell(cell):
    return re.sub(r'\s+', '', cell or '')


def read_unit_amount_tables(tables):
    """附表「保險金項目｜條件｜每單位給付金額」→ {項目代號: [(條件, 金額文字)]}
    項目名稱欄空白代表延續上一列（例：同一項目第 1～90 日、第 91 日起兩列）"""
    amounts = {}
    for table in tables:
        current_key = None
        for row in table:
            cells = [clean_cell(cell) for cell in row]
            if not cells or '給付金額' in ''.join(cells):
                continue
            if cells[0]:
                current_key = normalize_item_key(cells[0])
            if not current_key:
                continue
            amount = cells[-1]
            if not re.match(r'[\d,]+', amount):
                continue
            condition = '、'.join(cell for cell in cells[1:-1] if cell)
            amounts.setdefault(current_key, []).append((condition, amount))
    return amounts


def format_unit_amount(rows):
    """[(第1～20保單年度, 50,000), (第21保單年度起, 75,000)] → 每單位 50,000 元（第21保單年度起 75,000）"""
    def money(text):
        match = re.match(r'([\d,]+)(?:元)?(?:／|/)?(每日|每次|每年|每月)?', text)
        if not match:
            return text
        unit = match.group(2) or ''
        return f'{unit}{match.group(1)} 元'
    first_condition, first_amount = rows[0]
    text = f'每單位 {money(first_amount)}'
    for condition, amount in rows[1:3]:
        text += f'（{condition} {money(amount)}）'
    return text


# 算法的基準：保額或日額（條款寫法很多種）
BASE_PATTERN = r'(總保險金額|基本保額|保險金額|單位日額|住院醫療保險金日額|住院日額保險金日額|保險金日額|日額)」?'
NUMBER_PATTERN = r'([一二三四五六七八九十百點零\d.]+)'


def base_label(base_text):
    if '日額' in base_text:
        return '日額'
    return '保額'


def find_formula(context):
    """在「給付『○○保險金』」前面那段找「怎麼算」；回傳畫面要顯示的短句，找不到回傳 None"""
    # 富邦常見：同一句裡依「第 1～10 保單年度、第 11～15 保單年度…」給不同比例，先標分情況
    if len(re.findall(r'保單年度', context)) >= 2 and re.search(r'[〜~～]', context):
        return '分情況（看原文）'
    # 只看最後一個算法句（同一句前面可能提到別項保險金）
    candidates = []
    for match in re.finditer(BASE_PATTERN + r'(?:的|之)?百分之' + NUMBER_PATTERN, context):
        candidates.append((match.start(), base_label(match.group(1)), '× {}%', match.group(2)))
    for match in re.finditer(BASE_PATTERN + r'(?:的|之)?' + r'(\d+(?:\.\d+)?)[%％]', context):
        candidates.append((match.start(), base_label(match.group(1)), '× {}%', match.group(2)))
    for match in re.finditer(BASE_PATTERN + r'(?:的|之)?' + NUMBER_PATTERN + '倍', context):
        candidates.append((match.start(), base_label(match.group(1)), '× {}', match.group(2)))
    for match in re.finditer(BASE_PATTERN + r'[，,]?乘以(\d+(?:\.\d+)?)[%％]', context):
        candidates.append((match.start(), base_label(match.group(1)), '× {}%', match.group(2)))
    # 後面緊接 % 的不算（上一條處理），避免「乘以115%」被讀成 115 倍
    for match in re.finditer(BASE_PATTERN + r'[，,]?乘以' + NUMBER_PATTERN + r'(?![\d.%％])(?![^，。]{0,4}(?:日數|天數))', context):
        candidates.append((match.start(), base_label(match.group(1)), '× {}', match.group(2)))
    for match in re.finditer(BASE_PATTERN + r'[^。]{0,30}?附表[一二三四五六\d]*[^。]{0,12}?倍數', context):
        candidates.append((match.start(), base_label(match.group(1)), '× 附表倍數', None))
    for match in re.finditer(r'投保單位」?乘以新臺幣' + r'([一二三四五六七八九十百千萬\d,]+)元', context):
        candidates.append((match.start(), '每單位', '{} 元', match.group(1)))
    for match in re.finditer(r'(?<!乘)(?:以|按)新臺幣([一二三四五六七八九十百千萬\d,]+)元[，,]?給付', context):
        candidates.append((match.start(), '每次', '{} 元', match.group(1)))
    # 「日額乘以住院日數」「住院日數乘以單位日額」：日額 × 天數
    for match in re.finditer(BASE_PATTERN + r'[，,]?乘以[^。]{0,30}日數', context):
        candidates.append((match.start(), base_label(match.group(1)), '× 天數', None))
    for match in re.finditer(r'日數乘以「?' + BASE_PATTERN, context):
        candidates.append((match.start(), base_label(match.group(1)), '× 天數', None))
    # 失能、骨折、脫臼、處置：保額乘以附表的比例或倍數
    for match in re.finditer(BASE_PATTERN + r'[^。]{0,40}?(?:該表|附表|別表)[^。]{0,16}?(?:比例|倍數)', context):
        candidates.append((match.start(), base_label(match.group(1)), '× 附表比例', None))
    for match in re.finditer(BASE_PATTERN + r'[^。]{0,40}?給付倍數', context):
        candidates.append((match.start(), base_label(match.group(1)), '× 附表倍數', None))
    # 「日額乘以入院日當年度之增額係數，給付」：就是日額 × 1（後面再註明乘增額係數）
    for match in re.finditer(BASE_PATTERN + r'[，,]?乘以[^。，]{0,16}增額係數」?[，,]給付$', context):
        candidates.append((match.start(), base_label(match.group(1)), '× {}', '1'))

    text = None
    if candidates:
        candidates.sort(key=lambda candidate: candidate[0])
        position, label, template, number_text = candidates[-1]
        if number_text is None:
            text = f'{label} {template}'
            if template == '× 天數':
                return text
        else:
            number = chinese_to_number(number_text)
            if number:
                text = f'{label} {template.format(format_number(number))}'
        if text:
            tail = context[position:]
            # 「日數乘以投保單位乘以新臺幣一千元」：天數寫在前面
            if re.search(r'乘以[^。]{0,16}日數', tail) or '日數乘以' in context[max(0, position - 14):position]:
                text += ' × 天數'
            if '增額係數' in tail:
                text += '（再乘增額係數）'
            return text
    if re.search(r'(?:按|依)(?:本契約|本附約)?(?:保險單上所記載之)?「?(?:保險單上所記載之|當年度|[^，。「」]{0,14}?(?:時|當時|日)之)*「?(?:當年度|總|基本)?(?:保險金額|保額)」?(?:為準)?[，,]?(?:依照本契約約定)?給付$', context):
        return '保額 × 1'
    # 「按下列約定」「按保險年齡一百零四歲之保險單年度末，下列二款計算方式…」都算分情況
    if re.search(r'(?:按|以|依)[^。]{0,30}?(?:下列|下表)', context):
        return '分情況（看原文）'
    # 身故、祝壽、滿期常見：已繳保費或保單價值準備金，數字因人而異
    if re.search(r'已繳|保單價值準備金|保險費', context):
        return '依已繳保費計算（看原文）'
    return None


ITEM_KEY_SYNONYMS = [
    (r'^予', ''),  # 「給予身故保險金」多抓到的「予」
    (r'^首次', '初次'),
    (r'^(?:身故保險金或喪葬費用|身故或喪葬費用|喪葬費用)$', '身故'),
    (r'^意外(?:傷害|事故)身故$', '意外身故'),
    (r'^意外傷害失能$', '意外失能'),
    (r'^出院後療養$', '出院療養'),
    (r'^住院前後門診醫療$', '住院前後門診'),
]


def normalize_item_key(name):
    """對齊用的代號：去掉括號全半形差異、「保險金」字樣"""
    key = re.sub(r'[「」『』\s]', '', name)
    key = key.replace('(', '（').replace(')', '）')
    key = re.sub(r'保險金$', '', key)
    # 同一種給付、各家寫法不同：統一名稱，比較表才會排在同一列
    for pattern, replacement in ITEM_KEY_SYNONYMS:
        key = re.sub(pattern, replacement, key)
    return key


def short_condition(condition):
    """把情況的條件縮短：「診斷確定日在第一保險單年度以內」→「第1年內」、「第二保單年度(含)以後」→「第2年起」、
    「第一及第二保險單年度」→「第1-2年」、「投保當時保險年齡未達十六歲」→「未滿16歲」；看不懂回傳 None（就不整理）"""
    condition = condition.replace('(', '（').replace(')', '）')
    numbers = r'([一二三四五六七八九十\d]+)'
    match = re.search(r'第' + numbers + r'及第' + numbers + r'(?:保險單|保單)?年度', condition)
    if match:
        return f'第{int(chinese_to_number(match.group(1)))}-{int(chinese_to_number(match.group(2)))}年'
    match = re.search(r'第' + numbers + r'(?:保險單|保單)?年度(?:（含）)?(以內|內|起|以後|之後|及以後)?', condition)
    if match:
        suffix = ''
        if match.group(2) in ('以內', '內'):
            suffix = '內'
        elif match.group(2):
            suffix = '起'
        return f'第{int(chinese_to_number(match.group(1)))}年{suffix}'
    if re.search(r'投保之(?:保險單|保單)年度內', condition):
        return '第1年內'
    match = re.search(r'年齡(未達|未滿|達|滿)' + numbers + r'歲(?:（含）)?(以上)?', condition)
    if match:
        age = int(chinese_to_number(match.group(2)))
        if match.group(1) in ('未達', '未滿'):
            return f'未滿{age}歲'
        return f'{age}歲以上'
    if '續保' in condition:
        return '續保後'
    return None


def case_formula(value):
    """一種情況的金額：「「保險金額」的百分之五十」→ 保額 × 50%；「年繳應繳保險費」乘以一點零六 → 保費 × 1.06"""
    value = re.sub(r'^(?:本公司)?(?:按|依)', '', value)
    value = re.sub(r'(?:後之金額)?給付$', '', value)
    # 一種情況裡又分小項或「二者取其大」：太複雜，不整理（看原文）
    if re.search(r'（一）|\(一\)|取其大|或「', value):
        return None
    # 壽險常見第三款：保單價值準備金（依保單年度與利率而定，畫面寫「保單價值」）
    if '保單價值準備金' in value:
        return '保單價值'
    if '保險費' in value:
        match = re.search(r'(?:乘以([一二三四五六七八九十點零\d.]+)|(?:的|之)([一二三四五六七八九十點零\d.]+)倍)', value)
        if match:
            number = chinese_to_number(match.group(1) or match.group(2))
            if number:
                return f'保費 × {format_number(number)}'
        if re.fullmatch(r'[^，。]{0,12}「[^」]*保險費[^」]*」', value):
            return '保費 × 1'
        return None
    formula = find_formula('按' + value + '給付')
    if formula and '看原文' not in formula:
        return formula
    return None


def summarize_cases(text, start, context):
    """「按下列約定給付…：一、第一保險單年度以內：保額的百分之五十。二、第二保險單年度起：保額。」
    → 「第2年起：保額 × 1（第1年內：保額 × 50%）」；最後一種情況通常是主要的金額。
    「按下列二者之最大值給付：一、保險金額。二、保費總和 1.06 倍」→「取較高：保額 × 1／保費 × 1.06」。整理不出來回傳 None"""
    segment = text[start:start + 700]
    first = segment.find('一、')
    if first == -1 or first > 220:
        return None
    take_larger = bool(re.search(r'最大值|較大者|較高者|之最大者', context + text[start:start + 60]))
    cases = []
    for numeral, body in re.findall(r'([一二三四五六])、([^。]{2,200}?)。', segment[first:]):
        if numeral != '一二三四五六'[len(cases)]:
            break
        condition = None
        value = body
        if '：' in body:
            condition, _, value = body.rpartition('：')
        formula = case_formula(value)
        if not formula:
            return None
        if take_larger:
            cases.append((None, formula))
            continue
        short = short_condition(condition or '')
        if not short:
            return None
        cases.append((short, formula))
    if len(cases) < 2:
        return None
    # 每種情況算法都一樣（例：未滿 16 歲、16 歲以上都是保額 × 50%）就不分情況
    distinct_formulas = {formula for _, formula in cases}
    if len(distinct_formulas) == 1:
        return cases[0][1]
    if take_larger:
        return '取較高：' + '／'.join(formula for _, formula in cases)
    main_condition, main_formula = cases[-1]
    others = '；'.join(f'{condition}：{formula}' for condition, formula in cases[:-1])
    return f'{main_condition}：{main_formula}（{others}）'


def summarize_year_table(segment):
    """富邦常見的年度表：「第1保單年度按…保險金額乘以1%、第2保單年度…3%…第16〜20保單年度…115%」
    → 「保額 × 1%～115%（依投保第幾年）」；表格少於 2 列回傳 None"""
    percents = []
    for match in re.finditer(r'第\d+(?:[〜~～]\d+)?保單年度(?:起)?[〜~～]?按[^第。]{0,40}?保險金額(?:\(以萬元為單位\))?乘以(\d+(?:\.\d+)?)[%％]', segment):
        percents.append(float(match.group(1)))
    if len(percents) < 2:
        return None
    lowest = format_number(min(percents))
    highest = format_number(max(percents))
    return f'保額 × {lowest}%～{highest}%（依投保第幾年）'


def sentence_around(text, match):
    """「給付『○○保險金』」所在的那一句：往前到上一個。；】（最多 160 字），往後到句尾（最多 80 字）"""
    sentence_start = max(text.rfind(mark, 0, match.start()) for mark in ['。', '；', '】'])
    sentence_start = max(sentence_start + 1, match.start() - 160)
    end_candidates = [position for position in (text.find('。', match.end()), text.find('；', match.end())) if position != -1]
    sentence_end = match.end()
    if end_candidates:
        sentence_end = min(end_candidates) + 1
    sentence_end = min(sentence_end, match.end() + 80)
    return sentence_start, sentence_end


def extract_items(text):
    """每個「給付『○○保險金』」＝一個給付項目（依第一次出現排序）；
    同一項目出現好幾次時，挑寫得出算法的那一句，都沒有就挑「本公司按…給付」那句，再沒有用第一句"""
    quoted_matches = list(re.finditer(r'給付「([^」]{2,30}?保險金)」', text))
    unquoted_matches = list(re.finditer(r'給付([\u4e00-\u9fff（）()]{2,20}?保險金)', text))
    # 有些條款名稱沒加「」（例：給付重大疾病保險金），沒有引號的寫法也收；
    # 有引號的條款，沒引號的句子只拿來找更好的算法句，不新增項目（避免雜項）
    if quoted_matches:
        quoted_keys = {normalize_item_key(match.group(1)) for match in quoted_matches}
        # 「給付『身故保險金』及『完全失能保險金』」後面那個也是項目（常出現在不給付責任那條）
        for match in re.finditer(r'(?:及|或|、)「([^」]{2,30}?保險金)」', text):
            if '給付' in text[max(0, match.start() - 40):match.start()]:
                quoted_keys.add(normalize_item_key(match.group(1)))
        extra_matches = [match for match in unquoted_matches if normalize_item_key(match.group(1)) in quoted_keys]
        matches = sorted(quoted_matches + extra_matches, key=lambda match: match.start())
    else:
        matches = unquoted_matches

    candidates_by_key = {}
    names_by_key = {}
    for match in matches:
        name = match.group(1)
        if any(word in name for word in NOT_BENEFIT_WORDS + LOOSE_REFERENCE_WORDS):
            continue
        key = normalize_item_key(name)
        # 「該保險金」「生存保險金」這種只剩一兩個字的通常是指稱，不是項目名稱
        if len(key) < 2 or key in ('該', '生存'):
            continue
        names_by_key.setdefault(key, name)
        sentence_start, sentence_end = sentence_around(text, match)
        formula = find_formula(text[sentence_start:match.start() + 2])
        excerpt = text[sentence_start:sentence_end]
        # 依投保年度給不同比例的表格（表格可能在這句前面或後面）
        if formula is None or formula == '分情況（看原文）':
            # 只讀到下一條（第 X 條）之前，避免讀到下一個項目的表
            following = text[match.end():match.end() + 600]
            next_article = re.search(r'第[一二三四五六七八九十]+條', following)
            if next_article:
                following = following[:next_article.start()]
            year_summary = summarize_year_table(text[sentence_start:match.end()] + following)
            if year_summary:
                formula = year_summary
        # 分好幾種情況的（第 1 年、第 2 年起…）：整理成「主要金額（其他情況）」，出處也帶上那幾種情況
        if formula == '分情況（看原文）':
            summary = summarize_cases(text, match.end(), text[sentence_start:match.start() + 2])
            if summary:
                formula = summary
                excerpt = text[sentence_start:min(len(text), match.end() + 260)]
        candidates_by_key.setdefault(key, []).append((formula, excerpt))

    items = []
    for key, candidates in candidates_by_key.items():
        chosen = candidates[0]
        for formula, excerpt in candidates:
            if formula and '看原文' not in formula:
                chosen = (formula, excerpt)
                break
        else:
            for formula, excerpt in candidates:
                if formula or re.search(r'本公司(?:按|依|以)', excerpt):
                    chosen = (formula, excerpt)
                    break
        items.append({'item_key': key, 'item_name': names_by_key[key], 'formula': chosen[0], 'excerpt': chosen[1]})
    return items


def fill_from_unit_tables(items, unit_amounts):
    """條款寫「乘以附表的每單位給付金額」、文字找不到算法的項目，用附表的金額補上"""
    for item in items:
        if item['formula'] and '看原文' not in item['formula']:
            continue
        rows = unit_amounts.get(item['item_key'])
        if rows:
            item['formula'] = format_unit_amount(rows)


def main():
    cache_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(TOOL_DIR, '.cache')
    with open(CATEGORY_FILE, encoding='utf-8') as file:
        products = json.load(file)

    results = []
    for product in products:
        if product['coverage_category'] not in TARGET_CATEGORIES or not product.get('clause_url'):
            continue
        record = {
            'company_code': product['company_code'],
            'product_name': product['product_name'],
            'coverage_category': product['coverage_category'],
            'clause_url': product['clause_url'],
            'items': [],
            'error': None,
        }
        try:
            text, tables = read_clause(download_clause(product['clause_url'], cache_dir))
            record['items'] = extract_items(text)
            fill_from_unit_tables(record['items'], read_unit_amount_tables(tables))
            if not record['items']:
                record['error'] = '找不到「給付『○○保險金』」'
        except Exception as error:  # 下載或讀檔失敗：記下來，人工補
            record['error'] = f'讀不到條款：{error}'
        results.append(record)
        print(f"{len(record['items']):>2} 項  {record['product_name']}  {record['error'] or ''}", flush=True)

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as file:
        json.dump(results, file, ensure_ascii=False, indent=1)
    found = sum(1 for record in results if record['items'])
    with_formula = sum(1 for record in results for item in record['items'] if item['formula'])
    total_items = sum(len(record['items']) for record in results)
    print(f'\n商品 {len(results)} 款，抓到項目 {found} 款；項目 {total_items} 個，有倍數 {with_formula} 個')


if __name__ == '__main__':
    main()
