"""
把程式讀出的限額（benefit_plans_auto.json）和人工整理的（manual_plans.json）合成一份 SQL 匯入檔

用法：
    python3 tool/benefit_plans/build_seed_sql.py

輸出 supabase/seed/benefit_plans.sql：在 Supabase SQL Editor 執行即可匯入。
用「公司代號＋商品名稱」找 insurance_products 的 id，可重複執行（同一個計畫會更新、不會重複）。
"""
import json
import os

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_DIR = os.path.dirname(os.path.dirname(TOOL_DIR))
OUTPUT_PATH = os.path.join(REPOSITORY_DIR, 'supabase', 'seed', 'benefit_plans.sql')

AMOUNT_COLUMNS = [
    'room_daily_limit', 'hospital_expense_limit', 'surgery_limit', 'outpatient_surgery_limit',
    'per_admission_total_limit', 'annual_total_limit', 'lifetime_total_limit',
    'room_deductible', 'hospital_expense_deductible', 'outpatient_surgery_deductible',
    'daily_hospital_benefit',
]
ALL_COLUMNS = (['plan_code', 'plan_order', 'benefit_type'] + AMOUNT_COLUMNS
               + ['hospital_expense_includes_surgery', 'note', 'source_page'])


def sql_text(value):
    """字串加上單引號、把裡面的單引號變成兩個（避免 SQL 被打斷）；沒有值寫 NULL"""
    if value is None:
        return 'NULL'
    return "'" + str(value).replace("'", "''") + "'"


def sql_value(column, plan):
    value = plan.get(column)
    if column == 'hospital_expense_includes_surgery':
        return 'true' if value else 'false'
    if column in AMOUNT_COLUMNS or column in ('plan_order', 'source_page'):
        return 'NULL' if value is None else str(int(value))
    return sql_text(value)


def load_products():
    products = []
    for file_name in ('benefit_plans_auto.json', 'manual_plans.json'):
        with open(os.path.join(TOOL_DIR, file_name), encoding='utf-8') as file:
            products.extend(json.load(file))
    return products


def build_statements(products):
    """一筆 INSERT：VALUES 列出所有計畫，再用公司＋商品名稱對到 insurance_products"""
    value_rows = []
    for product in products:
        for plan in product['plans']:
            values = [sql_text(product['company_code']), sql_text(product['product_name'])]
            values.extend(sql_value(column, plan) for column in ALL_COLUMNS)
            value_rows.append('  (' + ', '.join(values) + ')')
    select_columns = []
    for column in ALL_COLUMNS:
        if column in AMOUNT_COLUMNS or column in ('plan_order', 'source_page'):
            select_columns.append(f'v.{column}::integer')
        elif column == 'hospital_expense_includes_surgery':
            select_columns.append(f'v.{column}::boolean')
        else:
            select_columns.append(f'v.{column}::text')
    updates = ',\n  '.join(f'{column} = EXCLUDED.{column}' for column in ALL_COLUMNS if column != 'plan_code')
    names = ', '.join(sql_text(product['product_name']) for product in products)
    return (
        '-- 實支實付理賠限額匯入檔（D14）：由 tool/benefit_plans/build_seed_sql.py 產生，請勿手改\n'
        '-- 在 Supabase SQL Editor 執行；可重複執行。最後會列出每款商品匯入了幾個計畫（對不到的商品是 0）。\n'
        f'INSERT INTO public.insurance_product_benefit_plans (product_id, {", ".join(ALL_COLUMNS)})\n'
        f'SELECT p.id, {", ".join(select_columns)}\n'
        f'FROM (VALUES\n' + ',\n'.join(value_rows) + '\n'
        f') AS v(company_code, product_name, {", ".join(ALL_COLUMNS)})\n'
        'JOIN public.insurance_products p ON p.company_code = v.company_code AND p.product_name = v.product_name\n'
        f'ON CONFLICT (product_id, plan_code) DO UPDATE SET\n  {updates},\n  updated_at = now();\n\n'
        'SELECT p.company_name, p.product_name, count(b.id) AS plan_count\n'
        'FROM public.insurance_products p\n'
        'LEFT JOIN public.insurance_product_benefit_plans b ON b.product_id = p.id\n'
        f'WHERE p.product_name IN ({names})\n'
        'GROUP BY p.company_name, p.product_name\n'
        'ORDER BY p.company_name, p.product_name;\n'
    )


def main():
    products = load_products()
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as file:
        file.write(build_statements(products))
    plan_count = sum(len(product['plans']) for product in products)
    print(f'已輸出 {OUTPUT_PATH}：{len(products)} 款商品、{plan_count} 個計畫')


if __name__ == '__main__':
    main()
