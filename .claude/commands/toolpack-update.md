---
description: 專案升級工具包：檢查可升級版本、小版升級、測試、更新工具包.md 與更新紀錄
---
執行「更新工具包」（專案升級）。工具包文件在 `../jingxuan-vault/工具包.md`，紀錄在 `../jingxuan-vault/工具包更新紀錄.md`。

1. **前置**：確認在 `feature/<身分>-toolpack-YYYYMM` 分支且沒有其他未提交的程式變更；不在就提示建立分支，經使用者同意才執行 git 指令。口試、驗收前一週內只做檢查不升級（先問使用者）。
2. **盤點（唯讀）**：
   - Flutter：`flutter upgrade --verify-only`（Windows 用 `puro flutter ...`）看 stable 最新版。
   - 套件：`flutter pub outdated --no-dev-dependencies --no-transitive`，分成「小版／修正版（Upgradable／Resolvable 第一碼沒變）」與「大改版（第一碼變了）」。
   - Supabase CLI：`supabase --version`。
   - 用表格列出「目前 → 可升到」，**只建議小版與修正版**；大改版列出名稱與原因，不動。等使用者確認要升哪些。
3. **升級**：
   - Flutter：`flutter upgrade`；同時改 `.github/workflows/deploy.yml` 的 `flutter-version`。
   - 套件：改 `pubspec.yaml` 的下限版本，用 `flutter pub upgrade <套件名...>` 只升指定套件（不要整包 `pub upgrade`，避免帶進 `shared_preferences_foundation` 2.6 等需 Mac 原生編譯的版本，見紀錄注意事項）。
4. **檢查**：`flutter analyze`（0 error，issue 數不得比升級前多；`build/` 產生檔不算）、`flutter test` 全過、`flutter build web --release` 成功。失敗就退回該套件並說明原因。
5. **更新文件**：`工具包.md` 的 Flutter／Dart／套件版本（格式 **`套件名`** (`版本`)）；在 `工具包更新紀錄.md`「一、專案升級」新增列（日期、誰、裝置、項目、舊版→新版、原因、檢查結果、分支），沒升的大改版也寫下來。
6. **校對**：`dart tool/verify_toolpack.dart` 必須「校對成功」；把最後印出的裝置那一行加到「二、裝置對齊」（填上誰）。
7. **說明**：用三到五句白話告訴使用者升了什麼、組員要做什麼（說「對齊工具包」）。之後照常「收工」(`/finish`)。
