import '../router/app_routes.dart';

/// 新手大導覽的一步
class OnboardingTourStep {
  /// 這一步屬於哪一區（說明卡左上角顯示，例：今日行程）
  final String section;
  final String title;
  final String body;

  /// 畫面上找不到要指的東西時改說這段（例如還沒有客戶）；沒寫就用 [body]
  final String? emptyBody;

  /// 這一步要先切到哪一頁；null＝留在目前這頁
  final String? route;

  /// 下一步按鈕的自訂文字（例：「進去看 👉」；沒寫就預設「下一步」，最後一步「開始使用」）
  final String? nextButtonLabel;

  /// 要切到的頁面得看另一個亮點記下的資料（例如第一位客戶的編號）時用：
  /// 先讀 [payloadTargetId] 記的資料，再用 [routeFromPayload] 組出網址
  final String? payloadTargetId;
  final String Function(String payload)? routeFromPayload;

  /// 要亮起來的地方（`TourTarget` 的 id）；好幾個時把它們框成一塊；空的＝畫面正中間一張卡
  final List<String> targetIds;

  /// 沒有資料時頁面上的「空白提示」：一出現就不用再等，直接亮它並改說 [emptyBody]
  /// （2026-11-01 沛沛反映空帳號換頁時要等好幾秒）
  final List<String> emptyTargetIds;

  /// 找不到要指的東西時整步跳過（不顯示 [emptyBody]）
  final bool skipWhenMissing;

  /// 換到新的一區前，先在左邊選單亮一下「接下來：某某頁」（2026-11-01 沛沛：換頁太突然）
  final bool showsSectionIntro;

  const OnboardingTourStep({
    required this.section,
    required this.title,
    required this.body,
    this.emptyBody,
    this.route,
    this.nextButtonLabel,
    this.payloadTargetId,
    this.routeFromPayload,
    this.targetIds = const [],
    this.emptyTargetIds = const [],
    this.skipWhenMissing = false,
    this.showsSectionIntro = true,
  });
}

/// 大導覽步驟（2026-11-01 沛沛定案：換大類別前先亮左邊選單，銜接更順暢）
const List<OnboardingTourStep> onboardingTourSteps = [
  OnboardingTourStep(
    section: '開始',
    title: '歡迎使用經選助手',
    body: '花一分鐘，帶你看最常用的三件事：排行程、管客戶、記拜訪。隨時可以按「略過導覽」。',
    route: AppRoutes.schedule,
  ),
  OnboardingTourStep(
    section: '今日行程',
    title: '今天要做什麼',
    // 2026-11-09 G5：亮的是整個行程區，原本說「右上角可以切換…」指不到，手機上還被說明卡蓋住
    body: '今天要拜訪誰、幾點，都排在這裡。也可以按「路線規劃」排出順路的拜訪順序。',
    route: AppRoutes.schedule,
    targetIds: ['schedule.main'],
  ),
  OnboardingTourStep(
    section: '今日行程',
    title: '用說的排行程',
    body: '按這顆，直接用說的就能排行程，說完會幫你填好時間和客戶。',
    route: AppRoutes.schedule,
    targetIds: ['schedule.voice'],
    skipWhenMissing: true,
  ),
  // 換類別前，先亮左側選單「客戶管理」
  OnboardingTourStep(
    section: '客戶管理',
    title: '接下來：客戶管理',
    body: '業務員最常用的核心功能：所有客戶名單、保單狀況、家庭關係都在這裡。我們進去看看！',
    targetIds: ['menu.客戶管理'],
    nextButtonLabel: '進去看 👉',
  ),
  OnboardingTourStep(
    section: '客戶管理',
    title: '新增客戶',
    body: '從這裡一位一位新增，也可以用「批次匯入」從 Excel 一次匯入。',
    route: AppRoutes.customers,
    targetIds: ['customers.add'],
  ),
  OnboardingTourStep(
    section: '客戶管理',
    title: '點卡片看客戶',
    body: '每位客戶是一張卡片。點一下，就會打開他的完整資料。',
    emptyBody: '加了客戶之後，每位客戶會變成一張卡片，點一下就能看他的完整資料。',
    targetIds: ['customers.first'],
    emptyTargetIds: ['customers.empty'],
  ),
  OnboardingTourStep(
    section: '客戶管理',
    title: '客戶資料一次看完',
    // 2026-11-09 G5：加入保費、要保人／被保險人／受益人
    body: '保單可以記保費和繳別，也分得清要保人、被保險人、受益人；「保單健檢」幫你找出保障缺口。點右上角的展開圖示能放大成完整頁面。',
    route: AppRoutes.customers,
    targetIds: ['customerDetail.sideSheet'],
    skipWhenMissing: true,
  ),
  // 換類別前，先亮左側選單「拜訪紀錄」
  OnboardingTourStep(
    section: '拜訪紀錄',
    title: '接下來：拜訪紀錄',
    // 2026-11-10：AI 只做「錄音轉文字＋修錯字、修順句子」（organize-visit-record 回傳一段 refined_text），沒有分重點與待辦
    body: '拜訪客戶結束後，用說的就能記錄，AI 會把錄音轉成文字並修順句子。我們進去看看！',
    targetIds: ['menu.拜訪紀錄'],
    nextButtonLabel: '進去看 👉',
  ),
  OnboardingTourStep(
    section: '拜訪紀錄',
    title: '拜訪完錄一段話',
    body: '拜訪完按「錄音新增」，把重點講出來就好，不用打字。',
    route: AppRoutes.visitRecords,
    targetIds: ['visitRecords.add'],
  ),
  OnboardingTourStep(
    section: '拜訪紀錄',
    title: 'AI 轉成文字、修順句子',
    body: '錄音會自動轉成文字，AI 再修正錯字、把句子修順；點進去就能看，也可以自己再改。',
    emptyBody: '錄完之後，AI 會把錄音轉成文字、修正錯字並把句子修順，出現在這個列表。',
    targetIds: ['visitRecords.first'],
    emptyTargetIds: ['visitRecords.empty'],
  ),
  // 2026-11-09 G5：數據戰情（情境試算）、人脈拓撲（管理關係）各自一步，只亮選單、不切頁
  OnboardingTourStep(
    section: '其他頁面',
    title: '人脈拓撲：管理關係',
    body: '一眼看出誰介紹誰；按「管理關係」就能加上家人或介紹人。',
    targetIds: ['menu.人脈拓撲'],
  ),
  OnboardingTourStep(
    section: '其他頁面',
    title: '數據戰情：情境試算',
    body: '挑幾款商品並排比較，用「情境試算」看住院、癌症時大約能拿多少。',
    targetIds: ['menu.數據戰情'],
  ),
  OnboardingTourStep(
    section: '其他頁面',
    title: '其他好用的頁面',
    body: '專案拜訪：一次規劃一批客戶，記錄拜訪結果。新聞頭條：每天的保險業重點。',
    targetIds: ['menu.專案拜訪', 'menu.新聞頭條'],
  ),
  OnboardingTourStep(
    section: '其他頁面',
    title: '你的電子名片',
    body: '在個人帳號挑一款名片模板，下載下來就能傳給客戶。',
    targetIds: ['menu.個人帳號'],
  ),
  OnboardingTourStep(
    section: '系統設定',
    title: '忘了可以回來看',
    body: '之後在「系統設定 → 教學中心」可以重看這段導覽；每個功能也都有「觀看教學」，示範一步一步怎麼操作。',
    route: AppRoutes.settings,
    targetIds: ['settings.tutorial'],
  ),
  // 最後回到客戶管理，按「開始使用」就能直接新增客戶
  OnboardingTourStep(
    section: '完成',
    title: '準備好了',
    body: '從新增第一位客戶開始吧！',
    route: AppRoutes.customers,
    showsSectionIntro: false,
  ),
];
