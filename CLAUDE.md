# jingxuan-app（經選助手）程式規則

純 Flutter Web 專案。三大核心：**客戶管理（CRM）**、**保單條款比價**、**語音拜訪紀錄**。
本專案只放程式碼與程式規則；文件、進度表、開發日誌、規格書一律在同層的 **`../jingxuan-vault`**（已透過 `.claude/settings.json` 的 `additionalDirectories` 開放讀寫，首次開啟需「信任此資料夾」）。

| 要找的東西 | 位置 |
|---|---|
| 進度表 / 工具包 / 主規格書 | `../jingxuan-vault/進度.md`、`工具包.md`、`00_公共規格/main_spec.md` |
| 開發日誌（規範與存放） | `../jingxuan-vault/01_開發日誌/` |
| Git 提交訊息規範 | `../jingxuan-vault/00_公共規格/Git提交訊息規範.md` |

成員：蘿蔔 (lobo)、巨獸 (beast)、沛沛 (peihan, Mac)、小陳 (chen)。其餘成員使用 Windows + puro。

GitHub：app → https://github.com/bbaitest01-bot/jingxuan-app ｜ vault → https://github.com/bbaitest01-bot/jingxuan-vault

## 1. 技術棧與常用指令

- Flutter（Dart SDK `>=3.0.0 <4.0.0`）＋ Supabase（`supabase_flutter`）；部署 Vercel（`.github/workflows/deploy.yml`）
- 後端：`supabase/functions/`（`transcribe-voice`、`voice-scheduler`、`crawl-insurance-products`）、`supabase/migrations/`、`supabase_schema.sql`

| 動作 | Windows（puro） | Mac |
|---|---|---|
| 本機預覽 | 雙擊 `run_local_web.bat`（release build + http-server，port 8080） | 雙擊 `run_local_web.command`（`flutter run -d web-server`，port 8080） |
| 工具包校對 | 雙擊 `verify_toolpack.bat` | 雙擊 `verify_toolpack.command` |
| 指令列 | `puro flutter analyze` / `puro flutter test` | `flutter analyze` / `flutter test` |

- `tool/verify_toolpack.dart` 比對 `pubspec.yaml` 與 `../jingxuan-vault/工具包.md` 的版本；兩個專案必須放在同一個上層資料夾。
- 金鑰：**不要**把 `.env` 加回 `pubspec.yaml` 的 `assets`（Web 版會被公開下載）。需指定時用 `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`。
- 已知：`flutter analyze` 目前有 35 個舊有 warning（0 error），修改到相關檔案時順手清除，不得新增。

## 2. UI 視覺規範

- 提示訊息一律用 `CustomToast.show(context, message, ToastType.success|warning|error)`（`lib/widgets/custom_toast.dart`），不要直接用 `ScaffoldMessenger` / `SnackBar`。
- 顏色取 `Theme.of(context).colorScheme.primary` 或 `AppSettings.instance.primaryColor`，不要寫死色碼；主題色定義在 `lib/services/app_settings.dart`（`AppThemeColors`）。
- 卡片、對話框、按鈕圓角統一 `BorderRadius.circular(12)`。
- UI 工作可參考 `.claude/skills/` 的設計類 skills（impeccable-design、taste-skill、ui-ux-pro-max 等）；資料庫工作先讀 `supabase`、`supabase-postgres-best-practices`。

## 3. 架構紅線

- **新寫或新拆出的 Widget 檔不得超過 500 行**；既有超標檔案（如 `customer_management_tab.dart`、`home_screen.dart`、`profile_screen.dart`）列入重構清單，修改時順手拆分，不要一次大改。
- 業務邏輯（Supabase 查詢、資料轉換、外部 API）寫在 `lib/services/`，Widget 只負責畫面與狀態。
- 平台差異用條件匯入（參考 `voice_web_helper*.dart`、`platform_file_helper*.dart`），不要在共用程式碼直接 `import 'dart:html'`。
- 資料庫變更一律新增 `supabase/migrations/YYYYMMDD_說明.sql`，不要直接改舊 migration；新表必須設定 RLS。
- 新增或升級套件後，同步更新 `../jingxuan-vault/工具包.md`（格式：**`套件名`** (`版本`)），並跑一次工具包校對。

## 4. 架構嚴謹協定（沿用自舊專案 AGENTS.md）

1. **禁止敷衍捷徑**：不得為了快速展示而硬塞違背真實架構的寫法；角色權限（RBAC）、資料存取與路由必須符合真實商業系統的權限隔離。
2. **主動質疑**：主動提出邊界漏洞、使用情境與安全風險（真正的使用者是誰？有何資安或邏輯漏洞？有無未考慮的 RLS 問題？），不盲目照做。
3. **規劃優先**：大型或涉及權限、資料庫的變更，先在 `../jingxuan-vault/03_蘿蔔_工作區/想法存放區/專案全景地圖_草稿.md` 的未來藍圖區產出角色/功能對照與路由分流，確認後才開發。
4. **不幻想未實作功能**：只依實際程式碼與已確定規格回答與設計。
5. **全域思考**：從角色、目的、功能性、完整性、正確性與雙向邏輯整體思考。
6. **雙向邏輯**：考量新功能與既有模組的雙向連動（例如新增角色時彼此的權限與視圖差異）。

## 5. Quality Gate（「收工」(`/finish`) 前必過）

- [ ] Supabase RLS：SQL/Table 改動已設定安全政策，且以新 migration 呈現
- [ ] UI 規範：CustomToast、主題色、12px 圓角
- [ ] 工具包同步：`pubspec.yaml` 異動已更新 `../jingxuan-vault/工具包.md`
- [ ] Null-Safety：核心流程有例外捕獲與空值防護
- [ ] `flutter analyze` 0 error 且未新增 warning；`flutter test` 全過

## 6. 快捷指令

「開工」(`/start`)、「收工」(`/finish`)、「回報」(`/report`)、「讓我看看」(`/preview`)、「確認狀況」(`/status`)、「精簡模式」(`/brief`)、「詳細模式」(`/verbose`)（`.claude/commands/`）。
純文件工作請在 `jingxuan-vault` 開啟，另有 「對齊」(`/align`)、「book」(`/book`)、「自我修復」(`/self-repair`)。

## 中文觸發詞（沿用舊習慣）
使用者在對話中說出下列中文指令時，等同執行對應的 `.claude/commands/` 檔案（也可直接輸入斜線指令）：
「開工」→ `start.md`｜「收工」→ `finish.md`｜「回報」（可加 人類／AI／雙軌）→ `report.md`｜「讓我看看」→ `preview.md`｜「確認狀況」→ `status.md`｜「精簡模式」／caveman → `brief.md`｜「詳細模式」→ `verbose.md`
