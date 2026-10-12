import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/router/app_redirect.dart';
import 'package:insurance_helper/router/app_routes.dart';
import 'package:insurance_helper/services/auth_status_service.dart';

// 建立測試用的登入狀態；沒指定的欄位預設為「已登入、帳號正常的業務員」
AuthSnapshot buildSnapshot({
  bool isOffline = false,
  bool hasEnteredOfflinePreview = false,
  bool isPasswordRecovery = false,
  bool isSignedIn = true,
  String? profileStatus = 'active',
  String profileRole = 'agent',
}) {
  return AuthSnapshot(
    isOffline: isOffline,
    hasEnteredOfflinePreview: hasEnteredOfflinePreview,
    isPasswordRecovery: isPasswordRecovery,
    isSignedIn: isSignedIn,
    profileStatus: profileStatus,
    profileRole: profileRole,
  );
}

String? redirectFor(String location, AuthSnapshot auth) {
  return decideRedirect(Uri.parse(location), auth).location;
}

void main() {
  group('規則 1：重設密碼', () {
    test('收到重設密碼通知時，任何網址都導到重設密碼頁', () {
      final AuthSnapshot auth = buildSnapshot(isPasswordRecovery: true);
      expect(redirectFor('/customers', auth), AppRoutes.resetPassword);
      expect(redirectFor(AppRoutes.resetPassword, auth), isNull);
    });
  });

  group('規則 2：未登入', () {
    final AuthSnapshot signedOut = buildSnapshot(isSignedIn: false, profileStatus: null);

    test('開內部網址會導到登入頁並記住原網址（X-05）', () {
      expect(redirectFor('/customers', signedOut), '/login?from=%2Fcustomers');
    });

    test('開首頁導到登入頁，不帶 from', () {
      expect(redirectFor('/', signedOut), AppRoutes.login);
    });

    test('登入頁本身不再導向', () {
      expect(redirectFor(AppRoutes.login, signedOut), isNull);
    });

    test('驗證連結失效的錯誤參數會保留到登入頁', () {
      final String? location = redirectFor('/?error=access_denied&error_code=otp_expired', signedOut);
      final Uri loginUri = Uri.parse(location!);
      expect(loginUri.path, AppRoutes.login);
      expect(loginUri.queryParameters['error_code'], 'otp_expired');
    });

    test('離線模式未按「直接跳過登入」也要先到登入頁', () {
      final AuthSnapshot offline = buildSnapshot(isOffline: true, isSignedIn: false, profileStatus: null);
      expect(redirectFor('/schedule', offline), '/login?from=%2Fschedule');
    });

    test('離線模式按過「直接跳過登入」可以進入外殼頁面', () {
      final AuthSnapshot offlinePreview = buildSnapshot(
        isOffline: true,
        hasEnteredOfflinePreview: true,
        isSignedIn: false,
        profileStatus: null,
      );
      expect(redirectFor('/schedule', offlinePreview), isNull);
      expect(redirectFor(AppRoutes.login, offlinePreview), AppRoutes.schedule);
    });
  });

  group('規則 3、4：帳號狀態', () {
    test('查不到 profile 導到無法使用頁', () {
      expect(redirectFor('/schedule', buildSnapshot(profileStatus: null)), AppRoutes.denied);
    });

    test('停用或刪除導到無法使用頁', () {
      expect(redirectFor('/schedule', buildSnapshot(profileStatus: 'suspended')), AppRoutes.denied);
      expect(redirectFor('/schedule', buildSnapshot(profileStatus: 'deleted')), AppRoutes.denied);
    });

    test('待審核導到待審核頁，開發者例外', () {
      expect(redirectFor('/schedule', buildSnapshot(profileStatus: 'pending')), AppRoutes.pending);
      expect(redirectFor('/schedule', buildSnapshot(profileStatus: 'pending', profileRole: 'dev')), isNull);
    });

    test('帳號開通後，停在待審核頁會被帶回今日行程', () {
      expect(redirectFor(AppRoutes.pending, buildSnapshot()), AppRoutes.schedule);
    });
  });

  group('規則 5：已登入開首頁或登入頁', () {
    test('開首頁或登入頁導到今日行程', () {
      expect(redirectFor('/', buildSnapshot()), AppRoutes.schedule);
      expect(redirectFor(AppRoutes.login, buildSnapshot()), AppRoutes.schedule);
    });

    test('登入後導回原本要去的網址', () {
      expect(redirectFor('/login?from=%2Fcustomers', buildSnapshot()), AppRoutes.customers);
    });

    test('Google 登入回到首頁時，導回登入前存下的網址', () {
      const AuthSnapshot authWithSaved = AuthSnapshot(
        isOffline: false,
        hasEnteredOfflinePreview: false,
        isPasswordRecovery: false,
        isSignedIn: true,
        profileStatus: 'active',
        profileRole: 'agent',
        savedReturnLocation: '/customers',
      );
      final RedirectDecision decision = decideRedirect(Uri.parse('/'), authWithSaved);
      expect(decision.location, AppRoutes.customers);
      expect(decision.hasFinishedSignIn, isTrue);
    });

    test('存下的網址如果是外部網址，不導過去', () {
      const AuthSnapshot authWithUnsafe = AuthSnapshot(
        isOffline: false,
        hasEnteredOfflinePreview: false,
        isPasswordRecovery: false,
        isSignedIn: true,
        profileStatus: 'active',
        profileRole: 'agent',
        savedReturnLocation: '//evil.example.com',
      );
      expect(redirectFor('/', authWithUnsafe), AppRoutes.schedule);
    });

    test('from 是外部網址時不導過去，改回今日行程', () {
      expect(redirectFor('/login?from=%2F%2Fevil.example.com', buildSnapshot()), AppRoutes.schedule);
      expect(redirectFor('/login?from=https%3A%2F%2Fevil.example.com', buildSnapshot()), AppRoutes.schedule);
    });
  });

  group('規則 6：角色頁', () {
    test('業務員開主管頁或開發者頁，導回今日行程並提示', () {
      final RedirectDecision adminDecision = decideRedirect(Uri.parse(AppRoutes.admin), buildSnapshot());
      expect(adminDecision.location, AppRoutes.schedule);
      expect(adminDecision.warningMessage, '沒有權限開啟此頁');
      expect(redirectFor(AppRoutes.dev, buildSnapshot()), AppRoutes.schedule);
    });

    test('主管可開主管頁，不可開開發者頁', () {
      expect(redirectFor(AppRoutes.admin, buildSnapshot(profileRole: 'admin')), isNull);
      expect(redirectFor(AppRoutes.dev, buildSnapshot(profileRole: 'admin')), AppRoutes.schedule);
    });

    test('開發者兩頁都可開', () {
      expect(redirectFor(AppRoutes.admin, buildSnapshot(profileRole: 'dev')), isNull);
      expect(redirectFor(AppRoutes.dev, buildSnapshot(profileRole: 'dev')), isNull);
    });
  });

  group('規則 7 與網址表', () {
    test('一般頁面與不存在的網址都不導向（不存在的由外殼顯示找不到頁面）', () {
      expect(redirectFor(AppRoutes.customers, buildSnapshot()), isNull);
      expect(redirectFor('/no-such-page', buildSnapshot()), isNull);
      expect(AppRoutes.menuForPath('/no-such-page'), AppRoutes.notFoundMenu);
    });

    test('網址與選單名稱可以互相轉換', () {
      expect(AppRoutes.menuForPath(AppRoutes.trash), '垃圾桶');
      expect(AppRoutes.pathForMenu('客戶管理'), AppRoutes.customers);
    });
  });
}
