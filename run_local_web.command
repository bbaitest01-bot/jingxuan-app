#!/bin/zsh
# ==============================================
#   Mac 版本機預覽（Windows 組員請用 run_local_web.bat）
#   雙擊執行；關閉此視窗即停止伺服器
# ==============================================
cd "$(dirname "$0")"
# 若 flutter 不在 PATH，嘗試常見安裝位置
if ! command -v flutter >/dev/null 2>&1; then
  for p in "$HOME/development/flutter/bin" "$HOME/flutter/bin" "/opt/homebrew/bin"; do
    [ -x "$p/flutter" ] && export PATH="$p:$PATH" && break
  done
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "[ERROR] 找不到 flutter，請先安裝 Flutter SDK 並加入 PATH。"; read -k1; exit 1
fi

echo "[1/2] 工具包版本校對（比對 ../jingxuan-vault/工具包.md）..."
if ! dart tool/verify_toolpack.dart; then
  echo ""
  echo "[WARNING] 工具包校對未通過，5 秒後仍繼續啟動預覽..."
  sleep 5
fi

echo ""
echo "[2/2] 啟動本機預覽：http://localhost:8080 （首次編譯約 30 秒）"
echo "      金鑰：若需指定，請加上 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=..."
flutter run -d web-server --web-port=8080 --web-hostname=localhost
