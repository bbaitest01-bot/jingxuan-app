# jingxuan-app（經選助手）程式規則

純 Flutter Web 專案。三大核心：**客戶管理（CRM）**、**保單條款比價**、**語音拜訪紀錄**。
本專案只放程式碼與程式規則；文件、進度表、開發日誌、規格書一律在同層的 **`../jingxuan-vault`**（已透過 `.claude/settings.json` 的 `additionalDirectories` 開放讀寫，首次開啟需「信任此資料夾」）。

| 要找的東西 | 位置 |
|---|---|
| 進度表 / 工具包 | `../jingxuan-vault/進度.md`、`工具包.md` |
| 系統「應該長怎樣」（目的、模組邊界、原則） | `../jingxuan-vault/00_公共規格/main_spec.md` |
| 系統「現在長怎樣」（資料表、權限、畫面動線） | `../jingxuan-vault/03_蘿蔔_工作區/想法存放區/專案全景地圖_草稿.md`；資料庫以本專案 `supabase/migrations/` 為準 |
| 開發日誌（規範與存放） | `../jingxuan-vault/01_開發日誌/` |
| Git 提交訊息規範 | `../jingxuan-vault/00_公共規格/Git提交訊息規範.md` |
| 問題修復（問題總表、修復工作單、測試總表）與其規則 | `../jingxuan-vault/05_沛沛_工作區/問題修復/README.md`（見第 9 節） |
| 各文件的分工（哪份文件回答什麼） | `../jingxuan-vault/CLAUDE.md`「文件分工」 |

成員：蘿蔔 (lobo)、巨獸 (beast)、沛沛 (peihan, Mac)、小陳 (chen)。其餘成員使用 Windows + puro。

GitHub：app → https://github.com/bbaitest01-bot/jingxuan-app ｜ vault → https://github.com/bbaitest01-bot/jingxuan-vault

## 1. 技術棧與常用指令

- Flutter（Dart SDK `>=3.0.0 <4.0.0`）＋ Supabase（`supabase_flutter`）；部署 Vercel（`.github/workflows/deploy.yml`）
- 後端：`supabase/functions/`（`transcribe-voice`、`voice-scheduler`、`organize-visit-record`、`scan-policy`、`fetch-insurance-news`、`import-product-catalog`）、`supabase/migrations/`、`supabase_schema.sql`

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
- 顏色用 `context.appColors.xxx`（`lib/theme/app_theme.dart`，token：bg、surface、surface2、line、ink、ink2、ink3、ok、okSoft、warn、warnSoft、acc、accSoft、onAcc），不要寫死 `Colors.xxx` 或色碼；放在主題色上的字用 `onAcc`。主題色定義在 `lib/theme/app_accent.dart`（`AppThemeColors`）。
- 圓角：按鈕、輸入框 `AppRadius.control`（8）；卡片、對話框 `AppRadius.card`（12）；Chip `AppRadius.pill`（999）。
- 字體：標題自動用宋體；數字、時間用 `AppTextStyles.mono()`；刪除等危險按鈕用 `AppButtonStyles.danger(context)`。
- UI 工作可參考 `.claude/skills/` 的設計類 skills（impeccable-design、taste-skill、ui-ux-pro-max 等）；資料庫工作先讀 `supabase`、`supabase-postgres-best-practices`。

## 3. 架構紅線

- **新寫或新拆出的 Widget 檔不得超過 500 行**；既有超標檔案（如 `customer_management_tab.dart`、`home_screen.dart`、`profile_screen.dart`）列入重構清單，修改時順手拆分，不要一次大改。
- 業務邏輯（Supabase 查詢、資料轉換、外部 API）寫在 `lib/services/`，Widget 只負責畫面與狀態。
- 平台差異用條件匯入（參考 `voice_web_helper*.dart`、`platform_file_helper*.dart`），不要在共用程式碼直接 `import 'dart:html'`。
- 資料庫變更一律新增 `supabase/migrations/YYYYMMDD_說明.sql`，不要直接改舊 migration；新表必須設定 RLS。
- 新增或升級套件後，同步更新 `../jingxuan-vault/工具包.md`（格式：**`套件名`** (`版本`)）並在 `../jingxuan-vault/工具包更新紀錄.md` 新增一列，再跑一次工具包校對。Flutter 版本升級要同時改 `.github/workflows/deploy.yml` 的 `flutter-version`。

## 4. 架構嚴謹協定（沿用自舊專案 AGENTS.md）

1. **禁止敷衍捷徑**：不得為了快速展示而硬塞違背真實架構的寫法；角色權限（RBAC）、資料存取與路由必須符合真實商業系統的權限隔離。
2. **主動質疑**：主動提出邊界漏洞、使用情境與安全風險（真正的使用者是誰？有何資安或邏輯漏洞？有無未考慮的 RLS 問題？），不盲目照做。
3. **規劃優先**：大型或涉及權限、資料庫的變更，先在 `../jingxuan-vault/03_蘿蔔_工作區/想法存放區/專案全景地圖_草稿.md` 的未來藍圖區產出角色/功能對照與路由分流，確認後才開發。
4. **不幻想未實作功能**：只依實際程式碼與已確定規格回答與設計。
5. **全域思考**：從角色、目的、功能性、完整性、正確性與雙向邏輯整體思考。
6. **雙向邏輯**：考量新功能與既有模組的雙向連動（例如新增角色時彼此的權限與視圖差異）。

## 5. Quality Gate（「收工」(`/finish`) 前必過）

- [ ] Supabase RLS：SQL/Table 改動已設定安全政策，且以新 migration 呈現
- [ ] UI 規範：CustomToast、顏色用 `context.appColors`、圓角 8／12
- [ ] 工具包同步：`pubspec.yaml` 異動已更新 `../jingxuan-vault/工具包.md`
- [ ] Null-Safety：核心流程有例外捕獲與空值防護
- [ ] `flutter analyze` 0 error 且未新增 warning；`flutter test` 全過
- [ ] 檔案行數：本次新增或修改的 `.dart` 檔不超過 500 行（用 `wc -l` 實測）；既有超標檔若本次有修改，列出行數並說明是否已順手拆分
- [ ] 學習筆記：本次改動影響的功能導讀與語法小抄已更新（見第 7 節）
- [ ] 問題修復紀錄：今天新增的問題都有「發現標記」；今天的測試結果都已新增到測試總表「紀錄」分頁（見第 9 節）

## 6. 快捷指令

「開工」(`/start`)、「收工」(`/finish`)、「回報」(`/report`)、「讓我看看」(`/preview`)、「確認狀況」(`/status`)、「精簡模式」(`/brief`)、「詳細模式」(`/verbose`)、「更新工具包」(`/toolpack-update`)、「對齊工具包」(`/toolpack-align`)（`.claude/commands/`）。
純文件工作請在 `jingxuan-vault` 開啟，另有 「對齊」(`/align`)、「book」(`/book`)、「自我修復」(`/self-repair`)。

## 7. 學習筆記（給新手組員看懂程式）

筆記放在 `../jingxuan-vault/07_學習筆記/`，格式見該資料夾的 `README.md`。分工：**開發日誌記「改了什麼」，學習筆記記「怎麼看懂」**，不要重複寫。

- **功能導讀**（`07_學習筆記/功能導讀/<功能名稱>.md`）：一個功能一份。用白話說明流程，並列出「檔案 + 函式名稱」對照（不寫行號，行號會跑掉）。
- **語法小抄**（`07_學習筆記/語法小抄.md`）：全組共用一份。程式中用到新手可能看不懂的 Dart / Flutter 語法時，補一條：語法、意思、簡單例子。
- **何時更新**：修改程式後，若影響某功能的流程、檔案或函式名稱，更新該功能導讀與「最後更新」日期；若該功能還沒有導讀，新增一份。「收工」(`/finish`) 時檢查。
- 筆記用繁體中文、寫給程式新手看；程式碼片段只節錄關鍵幾行並逐行白話解釋。
- **每次改完程式就在對話中說明**：完成一次修改後，用三到五句繁體中文白話告訴使用者：這次做了什麼、改了哪些檔案（與函式名稱）、怎麼確認結果。這是當下的說明，收工時再整理進學習筆記。

## 8. 程式寫法規範（人看得懂優先）

本專案由程式新手維護，寫法以「人看得懂、好維護」優先於「精簡」。

- **適用範圍**：只套用在新寫的程式與本次修改到的部分；不要為了符合本節而一次改寫整個舊檔案（與第 3 節「順手拆分」同原則）。
- **命名完整**：變數、函式、類別用完整英文單字，例如 `customerList`、`loadCustomers()`；不要用 `cl`、`data2`、`tmp` 這類縮寫。
- **型別寫清楚**：宣告時寫出型別，例如 `String customerName`、`List<Customer> customers`、`final int totalCount`；少用 `var`，避免 `dynamic`（Supabase 回傳的 `Map<String, dynamic>` 除外）。
- **串接不超過兩步**：`.where().map()` 這類串接最多兩步；超過就拆成幾行、用中間變數或 for 迴圈分步驟寫。單步轉換如 `customers.map((customer) => CustomerCard(customer: customer)).toList()` 可以照用。
- **空值語法可以用，但不疊**：`?.`、`??` 是空值防護（Quality Gate 要求），照常使用；但同一行不要疊兩個以上，也不要把三元運算子 `a ? b : c` 巢狀寫在一起，改用 if / else。
- **畫面層級不要太深**：`build()` 裡縮排超過 4～5 層，就把那一塊拆成獨立的小 Widget，並取看得懂的名字（例如 `CustomerSearchBar`）。一般函式只做一件事，太長就拆成幾個小函式。
- **中文註解寫目的**：主要流程、不直觀的判斷或計算，在上方用一行繁體中文註解說明「這段在做什麼、為什麼」；名字已經一看就懂的函式不必重複註解。
- **不引入進階狀態管理與程式碼產生器**：維持 `setState`（與既有的 `AppSettings.instance` 等寫法）；不新增 Riverpod、Bloc、GetX、freezed、build_runner 等套件。
- **改完要說明**：依第 7 節，每次修改後在對話中用中文說明做了什麼。

## 9. 問題修復紀錄（登記問題、記錄測試結果時）

只要在對話中**登記新問題**、**記錄測試結果**，或更新問題總表、修復工作單、測試總表，**先讀 `../jingxuan-vault/05_沛沛_工作區/問題修復/README.md` 並照它的規則做**。最容易漏的三條：

- **發現標記當下就記**：新問題在問題總表說明欄最前面加 `【發現：怎麼發現的｜裝置｜日期】`，和登記同一次寫入；從當下對話判斷，判斷不出來先問使用者，不可留空、不可事後補（README 第五節「發現標記」）。
- **紀錄只增不改**：每次測試結果在 `測試總表.xlsx`「紀錄」分頁新增一列；工作單「結果」欄只往下追加（README 第四節「紀錄只增不改」）。
- **工作單測試欄必填**：新問題要填測試編號，不用測填「無（原因）」（README 第五節）。

用途：這些紀錄會匯入驗收網站，比較每一版快照的問題變化（`../jingxuan-vault/02_專題報告/視覺化測試工具_定案.md` 第十四節）。

## 中文觸發詞（沿用舊習慣）
使用者在對話中說出下列中文指令時，等同執行對應的 `.claude/commands/` 檔案（也可直接輸入斜線指令）：
「開工」→ `start.md`｜「收工」→ `finish.md`｜「回報」（可加 人類／AI／雙軌）→ `report.md`｜「讓我看看」→ `preview.md`｜「確認狀況」→ `status.md`｜「精簡模式」／caveman → `brief.md`｜「詳細模式」→ `verbose.md`｜「更新工具包」→ `toolpack-update.md`｜「對齊工具包」→ `toolpack-align.md`
