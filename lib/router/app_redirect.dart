import '../models/user_role.dart';
import '../services/auth_status_service.dart';
import 'app_routes.dart';

/// 守門規則的判斷結果
class RedirectDecision {
  /// 要導去的網址；null 代表留在原本的網址
  final String? location;

  /// 導向時要跳的警告提示（規則 6：沒有權限開啟此頁）
  final String? warningMessage;

  /// 是否已登入完成並導向（規則 5）；是的話，Google 登入前存下的網址用過了要清掉
  final bool hasFinishedSignIn;

  const RedirectDecision.stay()
      : location = null,
        warningMessage = null,
        hasFinishedSignIn = false;

  const RedirectDecision.goTo(
    this.location, {
    this.warningMessage,
    this.hasFinishedSignIn = false,
  });
}

/// Supabase 驗證連結失效時，會把錯誤放在這些參數帶回來；導去登入頁時要保留，登入頁才會跳提示
const List<String> _authErrorParameterNames = ['error', 'error_code', 'error_description'];

/// 網址守門規則（依序判斷，第一個符合就導向）。規格見全景地圖 4-A ④。
/// 注意：這裡只決定「畫面給不給看」，真正的資料保護是 Supabase RLS。
RedirectDecision decideRedirect(Uri uri, AuthSnapshot auth) {
  final String path = uri.path;

  // 規則 1：收到重設密碼通知，只能停在重設密碼頁
  if (auth.isPasswordRecovery) {
    if (path == AppRoutes.resetPassword) return const RedirectDecision.stay();
    return const RedirectDecision.goTo(AppRoutes.resetPassword);
  }

  // 離線預覽按過「直接跳過登入」，視同已登入的業務員
  final bool isOfflinePreview = auth.isOffline && auth.hasEnteredOfflinePreview;
  final bool canUseApp = auth.isSignedIn || isOfflinePreview;

  // 規則 2：沒有登入 → 登入頁，並記住原本要去的網址
  if (!canUseApp) {
    if (path == AppRoutes.login) return const RedirectDecision.stay();
    return RedirectDecision.goTo(_loginLocation(uri));
  }

  if (!isOfflinePreview) {
    final String? status = auth.profileStatus;

    // 規則 3：查不到 profile，或帳號已停用／刪除 → 無法使用頁
    final bool isBlocked = status == null || status == 'deleted' || status == 'suspended';
    if (isBlocked) {
      if (path == AppRoutes.denied) return const RedirectDecision.stay();
      return const RedirectDecision.goTo(AppRoutes.denied);
    }

    // 規則 4：待審核（開發者例外）→ 待審核頁
    if (status == 'pending' && auth.profileRole != 'dev') {
      if (path == AppRoutes.pending) return const RedirectDecision.stay();
      return const RedirectDecision.goTo(AppRoutes.pending);
    }
  }

  // 規則 5：已登入卻開首頁或驗證流程頁 → 原本要去的網址，沒有就到今日行程
  if (path == '/' || AppRoutes.authFlowPaths.contains(path)) {
    return RedirectDecision.goTo(
      _returnLocation(uri, auth.savedReturnLocation),
      hasFinishedSignIn: true,
    );
  }

  // 規則 6：主管／開發者頁，角色不符 → 今日行程並提示
  if (!_canOpenRolePage(path, auth.profileRole)) {
    return const RedirectDecision.goTo(
      AppRoutes.schedule,
      warningMessage: '沒有權限開啟此頁',
    );
  }

  // 規則 7：不存在的網址交給外殼顯示「找不到頁面」；其餘照常顯示
  return const RedirectDecision.stay();
}

// 組出登入頁網址：帶上原本要去的網址（from）與驗證錯誤參數
String _loginLocation(Uri uri) {
  final Map<String, String> loginParameters = {};

  final bool isAuthFlowPage = uri.path == '/' || AppRoutes.authFlowPaths.contains(uri.path);
  if (!isAuthFlowPage) {
    loginParameters['from'] = uri.toString();
  }

  for (final String parameterName in _authErrorParameterNames) {
    final String? value = uri.queryParameters[parameterName];
    if (value != null) loginParameters[parameterName] = value;
  }

  if (loginParameters.isEmpty) return AppRoutes.login;
  return Uri(path: AppRoutes.login, queryParameters: loginParameters).toString();
}

// 登入後要回去的網址：先看網址上的 from（Email 登入），沒有再看 Google 登入前存下的網址。
// 只接受安全的站內網址，而且不能又是驗證流程頁
String _returnLocation(Uri uri, String? savedReturnLocation) {
  String? fromLocation = uri.queryParameters['from'];
  fromLocation ??= savedReturnLocation;
  if (!AppRoutes.isSafeReturnPath(fromLocation)) return AppRoutes.schedule;

  final String fromPath = Uri.parse(fromLocation!).path;
  if (fromPath == '/' || AppRoutes.authFlowPaths.contains(fromPath)) {
    return AppRoutes.schedule;
  }
  return fromLocation;
}

// 主管頁：主管與開發者可開；開發者頁：只有開發者可開；其他頁不限角色
bool _canOpenRolePage(String path, String role) {
  final UserRole userRole = UserRole.fromString(role);
  if (path == AppRoutes.admin) return userRole == UserRole.admin || userRole == UserRole.dev;
  if (path == AppRoutes.dev) return userRole == UserRole.dev;
  return true;
}
