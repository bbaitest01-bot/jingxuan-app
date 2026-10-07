---
description: 結束寫程式：Quality Gate、寫開發日誌與 Handoff、更新進度表、產出兩個專案的 commit 清單
---
執行「收工」流程。程式在本專案，日誌與進度在 `../jingxuan-vault`。

1. **盤點兩邊變更**：分別在本專案與 `../jingxuan-vault` 執行 `git status`，列出兩邊各有哪些檔案變更。
   - 本專案有程式變更 → 應在 `feature/<身分>-<功能>`；若不在，提示並提供建立/切換指令，經使用者同意才執行。
   - 本專案沒有任何變更、只有 vault 文件變更 → 告知使用者改到 `jingxuan-vault` 執行「收工」(`/finish`)，在此結束。
2. **Quality Gate**：逐項檢查 `CLAUDE.md` 第 5 節，實際執行 `flutter analyze` 與 `flutter test`（Windows 用 `puro flutter ...`）。未通過的項目列出原因，不得勾選。
3. **寫開發日誌**：在 `../jingxuan-vault/01_開發日誌/YYYY-MM/` 新增 `YYYYMMDD_功能標題.md`（同日多篇用不同功能標題，不用流水號），嚴格依 `../jingxuan-vault/01_開發日誌/開發日誌規範.md` 模板；文末必須有 `## 🤝 [Handoff 狀態條言]`：會話脈絡、目前狀態、關鍵決策、建議下一步。日誌中註明對應的 app 分支名稱。
4. **更新進度（Dual-Sync）**：在 `../jingxuan-vault/進度.md` 勾選完成項目；把今日完成的功能同步到 `../jingxuan-vault/03_蘿蔔_工作區/想法存放區/專案全景地圖_草稿.md` 的【現況實體區】與【角色權限與操作旅程】（唯一允許 AI 修改的人類工作區檔案，僅限這兩區）。若 `pubspec.yaml` 有異動，確認 `../jingxuan-vault/工具包.md` 已更新。
5. **再次盤點**：完成第 3、4 步後，重新對兩邊執行 `git status`，以最新結果產出下一步的檔案清單（不可憑記憶列檔案）。
6. **產出提交清單**：依 `../jingxuan-vault/00_公共規格/Git提交訊息規範.md` 的「雙專案提交」格式，輸出：
   - **📦 第 1 份：jingxuan-app**：分支名稱、本次包含的檔案（逐一列出）、Summary、Description（最後一行寫 `📝 日誌：01_開發日誌/YYYY-MM/檔名.md`）。
   - **📚 第 2 份：jingxuan-vault**：分支 `main`、本次包含的檔案（逐一列出）、Summary 固定為 `docs: 收工日誌－<功能>`、Description（最後一行寫 `🔗 對應 app 分支：feature/...`）。
   - **✅ 操作步驟**：
     1. GitHub Desktop 左上角 Current Repository 選 **jingxuan-app** → 貼上第 1 份 → Commit → Push → 開 PR 並 Merge。
     2. 左上角切到 **jingxuan-vault** → 貼上第 2 份 → Commit to main → Push origin。
   - 某一邊沒有變更時，明確寫「本次不需提交」，只輸出另一份。
