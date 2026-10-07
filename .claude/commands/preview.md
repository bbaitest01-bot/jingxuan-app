---
description: 啟動本機網頁預覽（自動判斷 Windows / Mac）
---
執行「讓我看看」：

1. **判斷作業系統**（例如看 shell 環境或 `uname`/`ver`）。
2. **Windows（puro）**：
   - 告訴使用者可在專案根目錄雙擊 `run_local_web.bat`（先做工具包校對，再 `puro flutter build web --release`，最後用 `npx http-server` 或 `python -m http.server` 開在 8080）。
   - 若要由 AI 在背景啟動：`puro flutter run -d web-server --web-port=8080`。
3. **Mac**：
   - 告訴使用者可雙擊 `run_local_web.command`（先做工具包校對，再 `flutter run -d web-server --web-port=8080`）。
   - 若要由 AI 在背景啟動：`flutter run -d web-server --web-port=8080 --web-hostname=localhost`。
4. 啟動後提供連結 **http://localhost:8080**。
5. 提醒：Google 登入在部分內嵌瀏覽器（如 IDE 或 Claude 內建面板）會失敗，請用一般 Chrome / Safari 開啟測試。
