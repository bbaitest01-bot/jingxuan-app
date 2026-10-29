"""把 benefit_items_auto.json 轉成 SQL 匯入檔

用法：
    python3 tool/benefit_items/build_seed_sql.py

輸出 supabase/seed/benefit_items_1.sql～_3.sql（太大一次貼會卡，分三份）：
在 Supabase SQL Editor 依序各執行一次即可匯入。

只更新意外傷害補齊的商品（2026-10-30 D22）：
    python3 tool/benefit_items/build_seed_sql.py accident
輸出 supabase/seed/benefit_items_accident.sql，只要貼這一份。
用「公司代號＋商品名稱」找 insurance_products 的 id；會先刪掉這些商品舊的項目再寫入，可重複執行。
"""
import json
import os
import sys

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_DIR = os.path.dirname(os.path.dirname(TOOL_DIR))
INPUT_PATH = os.path.join(TOOL_DIR, 'benefit_items_auto.json')
OUTPUT_DIR = os.path.join(REPOSITORY_DIR, 'supabase', 'seed')
PART_COUNT = 3
ACCIDENT_TARGETS_PATH = os.path.join(TOOL_DIR, 'accident_targets.json')


def sql_text(value):
    """字串加上單引號、把裡面的單引號變成兩個（避免 SQL 被打斷）；沒有值寫 NULL"""
    if value is None:
        return 'NULL'
    return "'" + str(value).replace("'", "''") + "'"


def build_part_sql(products, part_number, title=None):
    value_lines = []
    for product in products:
        for order, item in enumerate(product['items'], start=1):
            values = [
                sql_text(product['company_code']), sql_text(product['product_name']), str(order),
                sql_text(item['item_key']), sql_text(item['item_name']),
                sql_text(item['formula']), sql_text(item['excerpt']),
            ]
            value_lines.append('  (' + ', '.join(values) + ')')

    sql = (
        f'-- {title or f"定額型商品給付項目匯入 第 {part_number}/{PART_COUNT} 份"}（tool/benefit_items/build_seed_sql.py 產生，不要手改）\n'
        '-- 在 Supabase SQL Editor 整份貼上執行；可重複執行\n\n'
        'DROP TABLE IF EXISTS benefit_items_import;\n'
        'CREATE TEMP TABLE benefit_items_import (\n'
        '  company_code TEXT, product_name TEXT, item_order INTEGER,\n'
        '  item_key TEXT, item_name TEXT, formula TEXT, source_excerpt TEXT\n'
        ');\n\n'
        'INSERT INTO benefit_items_import VALUES\n' + ',\n'.join(value_lines) + ';\n\n'
        '-- 先刪掉這些商品舊的項目，再寫入新的\n'
        'DELETE FROM public.insurance_product_benefit_items i\n'
        'USING public.insurance_products p\n'
        'WHERE i.product_id = p.id\n'
        '  AND (p.company_code, p.product_name) IN (SELECT DISTINCT company_code, product_name FROM benefit_items_import);\n\n'
        'INSERT INTO public.insurance_product_benefit_items (product_id, item_order, item_key, item_name, formula, source_excerpt)\n'
        'SELECT p.id, v.item_order, v.item_key, v.item_name, v.formula, v.source_excerpt\n'
        'FROM benefit_items_import v\n'
        'JOIN public.insurance_products p ON p.company_code = v.company_code AND p.product_name = v.product_name;\n\n'
        'DROP TABLE benefit_items_import;\n\n'
        '-- 檢查：全部匯入後應該是 433 款商品\n'
        'SELECT count(DISTINCT product_id) AS product_count, count(*) AS item_count, count(formula) AS with_formula\n'
        'FROM public.insurance_product_benefit_items;\n'
    )
    return sql, len(value_lines)


def write_accident_only(products):
    with open(ACCIDENT_TARGETS_PATH, encoding='utf-8') as file:
        target_names = {target['product_name'] for target in json.load(file)}
    # 補齊清單＋原本就在 6 類裡、有「傷害醫療」項目的（例：國泰工地工程人員團體傷害保險）
    accident_products = []
    for product in products:
        has_accident_medical = any(item['item_key'] == '傷害醫療' for item in product['items'])
        if product['product_name'] in target_names or has_accident_medical:
            accident_products.append(product)
    sql, item_count = build_part_sql(accident_products, 1, title=f'意外傷害給付項目匯入（D22，{len(accident_products)} 款）')
    output_path = os.path.join(OUTPUT_DIR, 'benefit_items_accident.sql')
    with open(output_path, 'w', encoding='utf-8') as file:
        file.write(sql)
    print(f'寫入 {output_path}：{len(accident_products)} 款商品、{item_count} 個項目')


def main():
    with open(INPUT_PATH, encoding='utf-8') as file:
        products = [product for product in json.load(file) if product['items']]
    if len(sys.argv) > 1 and sys.argv[1] == 'accident':
        write_accident_only(products)
        return

    part_size = (len(products) + PART_COUNT - 1) // PART_COUNT
    for part_index in range(PART_COUNT):
        part_products = products[part_index * part_size:(part_index + 1) * part_size]
        sql, item_count = build_part_sql(part_products, part_index + 1)
        output_path = os.path.join(OUTPUT_DIR, f'benefit_items_{part_index + 1}.sql')
        with open(output_path, 'w', encoding='utf-8') as file:
            file.write(sql)
        print(f'寫入 {output_path}：{len(part_products)} 款商品、{item_count} 個項目')


if __name__ == '__main__':
    main()
