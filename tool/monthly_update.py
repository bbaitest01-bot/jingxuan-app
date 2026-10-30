"""每月一鍵更新（2026-10-30 D24，沛沛選半自動）

每月跑一次（要在台灣網路，南山會擋國外連線），依序：
1. 抓南山目錄並寫進資料庫（要輸入排程密碼；國泰、富邦每週 GitHub 已自動寫入）
2. 抓三家最新目錄（只存檔），找出還沒整理的新商品
3. 重新分類保障類別、整理給付項目（條款有快取，只下載新的）
4. 固定檢查（check_benefit_items.py），沒通過就停
5. 產生只含新商品或有變動商品的 SQL：supabase/seed/benefit_items_update.sql

執行（第一次先照 tool/product_catalog/README.md 準備 .venv）：
    cd ~/Documents/GitHub/jingxuan-app && tool/product_catalog/.venv/bin/python tool/monthly_update.py
"""
import getpass
import os
import shutil
import subprocess
import sys

TOOL_DIR = os.path.dirname(os.path.abspath(__file__))
REPOSITORY_DIR = os.path.dirname(TOOL_DIR)
CATALOG_DIR = os.path.join(TOOL_DIR, 'product_catalog', 'monthly_output')
# 舊檔備份放在目錄資料夾外面（放在裡面會被分類工具當成商品目錄讀進去）
BACKUP_DIR = os.path.join(TOOL_DIR, 'product_catalog', 'monthly_backup')
ITEMS_FILE = os.path.join(TOOL_DIR, 'benefit_items', 'benefit_items_auto.json')
UPDATE_SQL = os.path.join(REPOSITORY_DIR, 'supabase', 'seed', 'benefit_items_update.sql')
FUNCTION_URL = 'https://algufuoxkeizxwkofmmp.supabase.co/functions/v1/import-product-catalog'


def run_step(title, arguments, environment=None):
    """執行一個步驟；失敗回傳 False（畫面會顯示原因）"""
    print(f'\n▶ {title}', flush=True)
    result = subprocess.run([sys.executable] + arguments, cwd=REPOSITORY_DIR, env=environment)
    if result.returncode != 0:
        print(f'❌ {title} 沒有成功，後面的步驟先不做。')
        return False
    return True


def crawl_catalogs(secret):
    """南山寫進資料庫並存檔；國泰、富邦只存檔（每週 GitHub 已經寫入）"""
    if os.path.exists(CATALOG_DIR):
        shutil.rmtree(CATALOG_DIR)
    crawler = os.path.join('tool', 'product_catalog', 'crawl_products.py')
    environment = dict(os.environ, PRODUCT_CATALOG_SECRET=secret, PRODUCT_CATALOG_FUNCTION_URL=FUNCTION_URL)
    if secret:
        nanshan_ok = run_step('1. 抓南山目錄並寫進資料庫', [crawler, '--company', 'nanshan', '--save-json', CATALOG_DIR], environment)
    else:
        nanshan_ok = run_step('1. 抓南山目錄（沒輸入密碼：只存檔，不寫資料庫）', [crawler, '--company', 'nanshan', '--dry-run', '--output', CATALOG_DIR])
    # 某一家抓失敗時，目錄不完整，整理下去會把那家的商品當成不見了，所以直接停
    if not nanshan_ok:
        return False
    return run_step('2. 抓國泰、富邦最新目錄（只存檔）', [crawler, '--company', 'cathay', '--company', 'fubon', '--dry-run', '--output', CATALOG_DIR])


def main():
    print('=== 每月一鍵更新（請確認連的是台灣網路，不要開國外 VPN）===')
    secret = getpass.getpass('請貼上排程密碼 PRODUCT_CATALOG_SECRET 後按 Enter（畫面不會顯示；直接 Enter＝南山只試跑不寫入）：')
    if not crawl_catalogs(secret.strip()):
        return 1

    run_step('找新商品', [os.path.join('tool', 'benefit_items', 'list_new_products.py'), CATALOG_DIR])

    # 留一份這次之前的給付項目，最後只把有變的商品產生成 SQL
    os.makedirs(BACKUP_DIR, exist_ok=True)
    old_items_file = os.path.join(BACKUP_DIR, 'old_benefit_items_auto.json')
    shutil.copyfile(ITEMS_FILE, old_items_file)

    steps = [
        ('3. 分類保障類別', [os.path.join('tool', 'coverage_categories', 'classify_coverage.py'), CATALOG_DIR]),
        ('4. 整理給付項目', [os.path.join('tool', 'benefit_items', 'extract_benefit_items.py')]),
        ('5. 固定檢查並產生更新 SQL', [os.path.join('tool', 'benefit_items', 'build_seed_sql.py'), 'changed', old_items_file]),
    ]
    for title, arguments in steps:
        if not run_step(title, arguments):
            return 1

    print('\n=== 完成 ===')
    if os.path.exists(UPDATE_SQL):
        print(f'請到 Supabase SQL Editor 貼上並執行：{UPDATE_SQL}')
        if sys.platform == 'darwin':
            subprocess.run(['open', '-e', UPDATE_SQL])
    else:
        print('沒有新商品或變動，這個月不用貼 SQL。')
    print('最後把有變動的檔案提交（tool/coverage_categories、tool/benefit_items、supabase/seed），可以請 Claude「收工」。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
