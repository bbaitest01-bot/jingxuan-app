#!/bin/zsh
# ==============================================
#   Mac 版本機預覽（Windows 組員請用 run_local_web.bat）
#   用正式版（release）編譯，畫面速度跟上線網站一樣。
#   改完程式後，在這個視窗按 Enter 重新編譯，再到瀏覽器重新整理即可。
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

echo "[1/3] 工具包版本校對（比對 ../jingxuan-vault/工具包.md）..."
if ! dart tool/verify_toolpack.dart; then
  echo ""
  echo "[WARNING] 工具包校對未通過，5 秒後仍繼續啟動預覽..."
  sleep 5
fi

# 編譯正式版，並換掉 Flutter 的離線快取，讓瀏覽器每次都讀到最新版
build_release() {
  echo ""
  echo "[編譯] 正式版編譯中（約 1 分鐘）..."
  echo "      金鑰：若需指定，請在下面指令加上 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=..."
  if flutter build web --release; then
    cp tool/service_worker_cleanup.js build/web/flutter_service_worker.js
    echo "[完成] $(date '+%H:%M:%S') 編譯好了，到瀏覽器重新整理就是最新版。"
    return 0
  else
    echo "[ERROR] 編譯失敗，請看上面的錯誤訊息；修好後按 Enter 再試一次。"
    return 1
  fi
}

echo ""
echo "[2/3] 第一次編譯..."
build_release

echo ""
echo "[3/3] 啟動本機預覽：http://localhost:8080"
# 8080 已經有人在用（例如上一次沒關的預覽），就沿用它，不重複啟動
if lsof -nP -iTCP:8080 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "      8080 已有伺服器在跑，沿用它。"
  server_pid=""
else
  python3 tool/serve_spa.py 8080 build/web &
  server_pid=$!
  # 關閉此視窗時一併停止伺服器
  trap '[ -n "$server_pid" ] && kill $server_pid 2>/dev/null' EXIT
fi

# 等使用者按 Enter 就重新編譯；Ctrl+C 或關閉視窗結束
while true; do
  echo ""
  echo "👉 改完程式後按 Enter 重新編譯；要結束請按 Ctrl+C 或關閉視窗。"
  read -r
  build_release
done
