import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/access_denied_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/pending_approval_screen.dart';
import '../screens/reset_password_screen.dart';
import '../services/auth_status_service.dart';
import 'app_redirect.dart';
import 'app_routes.dart';

/// 守門規則導向時要跳的提示，暫存在這裡，由首頁外殼畫好後取出顯示。
/// （守門規則執行時還沒有畫面可以跳 Toast，所以要先存起來）
class RouteNotice {
  static String? _pendingWarning;

  static void setWarning(String message) {
    _pendingWarning = message;
  }

  /// 取出提示並清空，確保同一則提示只跳一次
  static String? takeWarning() {
    final String? message = _pendingWarning;
    _pendingWarning = null;
    return message;
  }
}

// 外殼內所有頁面共用同一個 key：切換網址時只換內容，側邊欄等外殼狀態不會被重建
const ValueKey<String> _homeShellPageKey = ValueKey<String>('home-shell');

/// 建立全站路由。網址表見 AppRoutes，守門規則見 decideRedirect。
GoRouter createAppRouter() {
  final AuthStatusService authStatus = AuthStatusService.instance;

  // 每次建立新的 App 都從登入頁開始（離線預覽要重新按「直接跳過登入」）
  authStatus.leaveOfflinePreview();

  return GoRouter(
    refreshListenable: authStatus,
    redirect: (BuildContext context, GoRouterState state) {
      final RedirectDecision decision = decideRedirect(state.uri, authStatus.snapshot);
      final String? warningMessage = decision.warningMessage;
      if (warningMessage != null) {
        RouteNotice.setWarning(warningMessage);
      }
      if (decision.hasFinishedSignIn) {
        authStatus.clearSavedReturnLocation();
      }
      return decision.location;
    },
    routes: [
      // 首頁網址一定會被守門規則導走（登入頁或今日行程），這裡只是讓網址有對應的路由
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (BuildContext context, GoRouterState state) {
          return ResetPasswordScreen(onCompleted: authStatus.finishPasswordRecovery);
        },
      ),
      GoRoute(
        path: AppRoutes.pending,
        builder: (BuildContext context, GoRouterState state) {
          return PendingApprovalScreen(
            userEmail: authStatus.currentUserEmail,
            onRefreshStatus: () {
              authStatus.refreshProfile();
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.denied,
        builder: (BuildContext context, GoRouterState state) => const AccessDeniedScreen(),
      ),
      // 客戶細節整頁（/customers/:id）：同一個外殼，內容顯示那位客戶
      GoRoute(
        path: '${AppRoutes.customers}/:id',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return NoTransitionPage<void>(
            key: _homeShellPageKey,
            child: HomeScreen(activeMenu: '客戶管理', customerId: state.pathParameters['id']),
          );
        },
      ),
      // 單篇拜訪紀錄（/visit-records/:id）：同一個外殼，內容顯示那一篇
      GoRoute(
        path: '${AppRoutes.visitRecords}/:id',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return NoTransitionPage<void>(
            key: _homeShellPageKey,
            child: HomeScreen(activeMenu: '拜訪紀錄', visitRecordId: state.pathParameters['id']),
          );
        },
      ),
      // 外殼內的頁面（/schedule、/customers…）：同一個外殼，依網址顯示不同內容
      GoRoute(
        path: '/:page',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return NoTransitionPage<void>(
            key: _homeShellPageKey,
            child: HomeScreen(activeMenu: AppRoutes.menuForPath(state.uri.path)),
          );
        },
      ),
    ],
    // 多層的未知網址（例如 /a/b）也放進外殼，顯示「找不到頁面」
    errorPageBuilder: (BuildContext context, GoRouterState state) {
      return const NoTransitionPage<void>(
        key: _homeShellPageKey,
        child: HomeScreen(activeMenu: AppRoutes.notFoundMenu),
      );
    },
  );
}
