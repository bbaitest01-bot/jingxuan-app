/// 全站網址表：網址 ↔ 側邊欄選單名稱。
/// 側邊欄與頂欄仍用中文選單名稱（例如「客戶管理」）判斷，這裡負責兩者互相轉換。
class AppRoutes {
  // 驗證流程頁（不顯示側邊欄）
  static const String login = '/login';
  static const String resetPassword = '/reset-password';
  static const String pending = '/pending';
  static const String denied = '/denied';

  // 業務員主頁（顯示在側邊欄外殼裡）
  static const String schedule = '/schedule';
  static const String customers = '/customers';
  static const String projects = '/projects';
  static const String visitRecords = '/visit-records';
  static const String network = '/network';
  static const String insights = '/insights';
  static const String news = '/news';
  static const String trash = '/trash';
  static const String profile = '/profile';
  static const String settings = '/settings';

  // 主管／開發者頁（只有對應角色能開）
  static const String admin = '/admin';
  static const String dev = '/dev';

  /// 客戶細節整頁的網址，例：/customers/1234-…
  static String customerPath(String id) => '$customers/$id';

  /// 單篇拜訪紀錄的網址，例：/visit-records/1234-…
  static String visitRecordPath(String id) => '$visitRecords/$id';

  /// 網址對不到任何頁面時，外殼顯示的選單名稱
  static const String notFoundMenu = '找不到頁面';

  /// 外殼裡每個頁面的網址與選單名稱
  static const Map<String, String> menuByPath = {
    schedule: '今日行程',
    customers: '客戶管理',
    projects: '專案拜訪',
    visitRecords: '拜訪紀錄',
    network: '人脈拓撲',
    insights: '數據戰情',
    news: '新聞頭條',
    trash: '垃圾桶',
    profile: '個人帳號',
    settings: '系統設定',
    admin: '👑 團隊戰情室',
    dev: '🛠️ 實體服務診斷',
  };

  /// 驗證流程頁：已登入且帳號正常時，開這些網址會被帶回首頁
  static const List<String> authFlowPaths = [login, resetPassword, pending, denied];

  /// 網址 → 選單名稱；對不到就回傳「找不到頁面」
  static String menuForPath(String path) {
    return menuByPath[path] ?? notFoundMenu;
  }

  /// 選單名稱 → 網址；對不到就回今日行程
  static String pathForMenu(String menu) {
    for (final MapEntry<String, String> entry in menuByPath.entries) {
      if (entry.value == menu) return entry.key;
    }
    return schedule;
  }

  /// 判斷登入後要導回的網址是否安全：只接受站內網址（/ 開頭），
  /// 擋掉 //example.com 這類會被瀏覽器當成外部網站的寫法
  static bool isSafeReturnPath(String? location) {
    if (location == null || location.isEmpty) return false;
    if (!location.startsWith('/')) return false;
    if (location.startsWith('//')) return false;
    if (location.contains('\\')) return false;
    return true;
  }
}
