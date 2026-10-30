"""列出「還沒整理給付項目」的新商品（2026-10-30 D24）

商品目錄每週自動更新，但給付項目要跑工具才會有；這個檔案比對最新目錄和已整理的清單，
把新商品列出來。每週 GitHub 抓完國泰、富邦後會跑一次，結果顯示在 Actions 頁面；
每月一鍵更新（tool/monthly_update.py）也用它找新商品。

執行：python3 tool/benefit_items/list_new_products.py <目錄 JSON 資料夾>
"""
import json
import os
import sys

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_DIR = os.path.dirname(os.path.dirname(TOOL_DIR))
CATEGORY_FILE = os.path.join(REPOSITORY_DIR, 'tool', 'coverage_categories', 'coverage_categories.json')

COMPANY_NAMES = {'cathay': '國泰', 'fubon': '富邦', 'nanshan': '南山'}
# 批註條款不能單獨購買、比較頁預設不顯示，不提醒
SKIPPED_KINDS = {'endorsement'}


def load_catalog(catalog_dir):
    products = []
    for file_name in sorted(os.listdir(catalog_dir)):
        if not file_name.endswith('.json'):
            continue
        with open(os.path.join(catalog_dir, file_name), encoding='utf-8') as file:
            data = json.load(file)
        for product in data.get('products', []):
            product['company_code'] = data.get('company_code')
            products.append(product)
    return products


def find_new_products(catalog_products):
    """目錄裡有、但還沒整理過（不在 coverage_categories.json）的商品"""
    with open(CATEGORY_FILE, encoding='utf-8') as file:
        known_names = {product['product_name'] for product in json.load(file)}
    new_products = []
    for product in catalog_products:
        if product['product_name'] in known_names or product.get('product_kind') in SKIPPED_KINDS:
            continue
        new_products.append(product)
    return new_products


def summary_markdown(new_products):
    if not new_products:
        return '✅ 沒有新商品，給付項目都是最新的。'
    lines = [
        f'🆕 有 {len(new_products)} 款新商品還沒有給付項目（比較頁會顯示「—」）。',
        '下次每月一鍵更新（`tool/monthly_update.py`）會補上；急的話可以提早跑。',
        '',
        '| 公司 | 商品 | 核准日期 | 有條款連結 |',
        '|---|---|---|---|',
    ]
    for product in new_products:
        company = COMPANY_NAMES.get(product['company_code'], product['company_code'])
        has_clause = '有' if product.get('clause_url') else '沒有'
        lines.append(f"| {company} | {product['product_name']} | {product.get('approval_date') or ''} | {has_clause} |")
    return '\n'.join(lines)


def main():
    new_products = find_new_products(load_catalog(sys.argv[1]))
    text = summary_markdown(new_products)
    print(text)
    # 在 GitHub Actions 裡，同一段文字也顯示在執行結果頁面
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        with open(summary_path, 'a', encoding='utf-8') as file:
            file.write(text + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
