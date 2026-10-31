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
  ),
  OnboardingTourStep(
    section: '今日行程',
    title: '今天要做什麼',
    body: '今天要拜訪誰、幾點，都排在這裡。右上角可以切換月曆、時間軸、清單三種看法。',
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
    body: '每位客戶是一張卡片。點一下，右邊會打開他的完整資料。',
    emptyBody: '加了客戶之後，每位客戶會變成一張卡片，點一下就能看他的完整資料。',
    targetIds: ['customers.first'],
    emptyTargetIds: ['customers.empty'],
  ),
  OnboardingTourStep(
    section: '客戶管理',
    title: '一位客戶的全部資料',
    body: '每位客戶都有自己的資料頁：保障健檢看出缺口，保單、拜訪紀錄也都整理在這裡。',
    payloadTargetId: 'customers.first',
    routeFromPayload: AppRoutes.customerPath,
    targetIds: ['customerDetail.policies'],
    skipWhenMissing: true,
  ),
  // 換類別前，先亮左側選單「拜訪紀錄」
  OnboardingTourStep(
    section: '拜訪紀錄',
    title: '接下來：拜訪紀錄',
    body: '拜訪客戶結束後，用說的就能記錄，AI 自動幫你整理重點與待辦。我們進去看看！',
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
    title: 'AI 自動整理',
    body: '錄音會自動整理成拜訪重點和下次要做的事，點進去就能看。',
    emptyBody: '錄完之後，AI 會自動整理成拜訪重點和下次要做的事，出現在這個列表。',
    targetIds: ['visitRecords.first'],
    emptyTargetIds: ['visitRecords.empty'],
  ),
  OnboardingTourStep(
    section: '其他頁面',
    title: '其他好用的頁面',
    body: '專案拜訪：一次規劃一批客戶。人脈拓撲：看誰介紹誰。數據戰情：客戶與保單統計。新聞頭條：每天的保險業重點。',
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
    body: '之後在「系統設定 → 教學中心」可以重看這段導覽。',
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
