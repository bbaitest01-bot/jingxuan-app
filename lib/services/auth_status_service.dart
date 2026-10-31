import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../router/app_routes.dart';
import 'app_settings.dart';
import 'customer_service.dart';
import 'google_calendar_sync_service.dart';
import 'tag_categorizer.dart';
import 'tag_manager_service.dart';

/// 某一個時間點的登入狀態快照，給網址守門規則判斷要不要導向。
/// 只放判斷需要的資料，方便在測試裡直接建立各種情境。
class AuthSnapshot {
  /// 是否為離線預覽模式（沒有 Supabase 連線）
  final bool isOffline;

  /// 離線模式下，使用者是否已按過「直接跳過登入」
  final bool hasEnteredOfflinePreview;

  /// 是否收到「重設密碼」通知（從重設密碼信的連結回來）
  final bool isPasswordRecovery;

  /// 是否已登入
  final bool isSignedIn;

  /// profiles 表的 status（active／pending／suspended／deleted）；查不到時是 null
  final String? profileStatus;

  /// profiles 表的 role（agent／admin／dev）
  final String profileRole;

  /// Google 登入前存下的「原本要去的網址」；Google 登入回來時網址上的 from 已經不見，改用這個
  final String? savedReturnLocation;

  const AuthSnapshot({
    required this.isOffline,
    required this.hasEnteredOfflinePreview,
    required this.isPasswordRecovery,
    required this.isSignedIn,
    required this.profileStatus,
    required this.profileRole,
    this.savedReturnLocation,
  });
}

/// 統一管理「有沒有登入、帳號狀態、角色」的服務。
/// 原本寫在 main.dart 的 AuthGateway；改成服務後，網址守門規則與各畫面共用同一份狀態。
/// 狀態一變就通知路由重新檢查目前網址（GoRouter 的 refreshListenable）。
class AuthStatusService extends ChangeNotifier {
  static final AuthStatusService instance = AuthStatusService._internal();
  AuthStatusService._internal();

  StreamSubscription<AuthState>? _authSubscription;
  bool _hasEnteredOfflinePreview = false;
  bool _isPasswordRecovery = false;
  Session? _session;
  String? _profileUserId;
  String? _profileStatus;
  String _profileRole = 'agent';
  String? _savedReturnLocation;

  // 存在瀏覽器裡的 key：Google 登入會離開網站再回來，記憶體裡的資料會不見，所以要存起來
  static const String _returnLocationKey = 'return_location_after_sign_in';

  AuthSnapshot get snapshot {
    return AuthSnapshot(
      isOffline: isOfflineMode,
      hasEnteredOfflinePreview: _hasEnteredOfflinePreview,
      isPasswordRecovery: _isPasswordRecovery,
      isSignedIn: _session != null,
      profileStatus: _profileStatus,
      profileRole: _profileRole,
      savedReturnLocation: _savedReturnLocation,
    );
  }

  String get currentUserEmail => _session?.user.email ?? '';

  /// App 啟動時呼叫一次：先讀目前的登入狀態與 profile，再持續監聽登入／登出。
  /// 要等 Supabase.initialize 完成後才能呼叫（Supabase 會先把網址裡的登入資料讀走）。
  Future<void> start() async {
    if (isOfflineMode) return;

    await _loadSavedReturnLocation();

    final SupabaseClient supabase = Supabase.instance.client;
    await _applySession(supabase.auth.currentSession);

    await _authSubscription?.cancel();
    _authSubscription = supabase.auth.onAuthStateChange.listen(_handleAuthChange);
  }

  Future<void> _handleAuthChange(AuthState authState) async {
    if (authState.event == AuthChangeEvent.passwordRecovery) {
      _isPasswordRecovery = true;
    }
    await _applySession(authState.session);
    notifyListeners();
  }

  // 更新登入者；換了一個人（或剛登入）才重新讀 profile，避免每次換 token 都查資料庫
  Future<void> _applySession(Session? session) async {
    _session = session;
    if (session == null) {
      _clearProfile();
      OfflineDataStore.clear();
      // 登出時清掉暫存的客戶名單，下一個登入的人看不到
      CustomerService.instance.clearCache();
      // 設定恢復預設，下一個登入的人不會沿用上一位的主題色等（問題 G1）
      await AppSettings.instance.clearForSignOut();
      // 清掉上一位的自訂標籤顏色
      TagCategorizer.clearCustomColors();
      return;
    }

    OfflineDataStore.ensureOwner(session.user.id);
    if (_profileUserId != session.user.id) {
      CustomerService.instance.clearCache();
      await _loadProfile(session.user.id);
      // 剛登入或換人：套用這個帳號存的設定（主題色、深淺模式、檢視模式、側邊欄、語言、日曆同步）
      await AppSettings.instance.applyCloudSettings();
      await GoogleCalendarSyncService.instance.applyCloudSettings();
      // 讀回這個帳號的標籤，客戶卡片、行程上的自訂標籤顏色才會一致（問題 S13）；
      // 第一次使用時也會在這裡把瀏覽器本機的標籤搬進資料庫
      TagCategorizer.clearCustomColors();
      await TagManagerService.getTags();
    }
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final Map<String, dynamic>? profileData = await Supabase.instance.client
          .from('profiles')
          .select('status, role')
          .eq('id', userId)
          .maybeSingle();
      _profileUserId = userId;
      _profileStatus = profileData?['status'] as String?;
      _profileRole = profileData?['role'] as String? ?? 'agent';
    } catch (error) {
      // 讀不到 profile 時一律視為無法使用（守門規則 3），不可放行
      debugPrint('⚠️ [AuthStatusService] 讀取 profile 失敗: $error');
      _profileUserId = userId;
      _profileStatus = null;
      _profileRole = 'agent';
    }
  }

  void _clearProfile() {
    _profileUserId = null;
    _profileStatus = null;
    _profileRole = 'agent';
  }

  Future<void> _loadSavedReturnLocation() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _savedReturnLocation = prefs.getString(_returnLocationKey);
    } catch (error) {
      debugPrint('⚠️ [AuthStatusService] 讀取登入後導回網址失敗: $error');
    }
  }

  /// 按 Google 登入前呼叫：存下登入後要回去的網址（只存安全的站內網址；沒有就清掉舊的）
  Future<void> saveReturnLocation(String? location) async {
    if (!AppRoutes.isSafeReturnPath(location)) {
      await clearSavedReturnLocation();
      return;
    }
    _savedReturnLocation = location;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_returnLocationKey, location!);
    } catch (error) {
      debugPrint('⚠️ [AuthStatusService] 儲存登入後導回網址失敗: $error');
    }
  }

  /// 導回過一次就清掉，避免下次登入又被帶去同一頁
  Future<void> clearSavedReturnLocation() async {
    if (_savedReturnLocation == null) return;
    _savedReturnLocation = null;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_returnLocationKey);
    } catch (error) {
      debugPrint('⚠️ [AuthStatusService] 清除登入後導回網址失敗: $error');
    }
  }

  /// 待審核頁按「重新檢查」後呼叫：重新讀 profile，開通了就會自動進入首頁
  Future<void> refreshProfile() async {
    final Session? session = _session;
    if (session == null) return;
    await _loadProfile(session.user.id);
    notifyListeners();
  }

  /// 重設密碼完成後呼叫，解除「只能停在重設密碼頁」的限制
  void finishPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }

  /// 離線模式按「直接跳過登入」
  void enterOfflinePreview() {
    _hasEnteredOfflinePreview = true;
    notifyListeners();
  }

  /// 離線模式登出，或重新建立 App 時回到登入頁
  void leaveOfflinePreview() {
    _hasEnteredOfflinePreview = false;
    notifyListeners();
  }
}
