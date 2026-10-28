---
description: 組員裝置對齊工具包：把自己電腦的 Flutter／套件更新到工具包版本並記錄
---
執行「對齊工具包」（裝置對齊）。工具包文件在 `../jingxuan-vault/工具包.md`，紀錄在 `../jingxuan-vault/工具包更新紀錄.md`。

1. **確認身分與裝置**：用 AskUserQuestion 讓使用者點選身分（蘿蔔 lobo、巨獸 beast、沛沛 peihan、小陳 chen）；裝置由系統判斷（Mac／Windows）。
2. **讀建議版本**：從 `工具包.md` 讀「Flutter SDK (建議版本 vX.Y.Z)」與 Supabase CLI 建議版本。
3. **更新本機**（先列出要執行的指令，經使用者同意才執行）：
   - Windows（puro）：`puro create <版本>`（還沒有這個環境時）→ `puro use <版本>`。
   - Mac：版本比建議舊用 `flutter upgrade`；要切到特定版本時說明做法，不自行降版。
   - 專案資料夾執行 `flutter pub get`（Windows：`puro flutter pub get`）。
4. **校對**：執行 `dart tool/verify_toolpack.dart`（或雙擊 `verify_toolpack.command`／`.bat`），必須「校對成功」；本機版本仍不符時說明原因。
5. **記錄**：把校對最後印出的那一行（日期｜誰｜裝置｜Flutter｜Dart｜Supabase CLI｜結果）填上身分，新增到 `工具包更新紀錄.md`「二、裝置對齊」表（只增不改）。
6. **說明**：告訴使用者對齊結果，並提醒提交 jingxuan-vault（`docs: 工具包對齊－<身分>－<裝置>`）。本指令不改 jingxuan-app 的程式。
