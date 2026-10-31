import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'auth_status_service.dart';

/// 刪除帳號時，要讓使用者看到「會被刪掉的資料有多少」
class AccountDataSummary {
  final int customerCount;
  final int scheduleCount;
  final int visitRecordCount;
  final int visitProjectCount;

  const AccountDataSummary({
    required this.customerCount,
    required this.scheduleCount,
    required this.visitRecordCount,
    required this.visitProjectCount,
  });
}

/// 刪除失敗時丟出的錯誤，message 可以直接顯示給使用者
class AccountDeletionException implements Exception {
  final String message;
  const AccountDeletionException(this.message);

  @override
  String toString() => message;
}

/// 業務員自己刪除自己的帳號（全景地圖 4-N）。
/// 真正的刪除在雲端函式 delete-account 做；這裡只負責事前檢查、查筆數、呼叫函式、登出。
class AccountDeletionService {
  static final AccountDeletionService instance = AccountDeletionService._internal();
  AccountDeletionService._internal();

  /// 使用者要輸入這四個字才能刪除（雲端函式也會再檢查一次）
  static const String confirmText = '刪除帳號';
  static const String _demoEmailSuffix = '@jingxuan.test';

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 不能刪除時回傳原因；可以刪除時回傳 null。
  /// 只是畫面提示，真正的把關在雲端函式。
  String? deletionBlockedReason() {
    if (isOfflineMode) return '離線預覽模式沒有帳號可以刪除';
    final String email = AuthStatusService.instance.currentUserEmail.toLowerCase();
    if (email.endsWith(_demoEmailSuffix)) return '示範帳號不能刪除';
    final String role = AuthStatusService.instance.snapshot.profileRole;
    if (role != 'agent') return '管理者與開發者帳號不能從這裡刪除';
    return null;
  }

  /// 查出這個帳號底下的主要資料筆數（資料庫權限只會算到自己的）
  Future<AccountDataSummary> fetchDataSummary() async {
    final int customerCount = await _countRows('customers');
    final int scheduleCount = await _countRows('schedule_events');
    final int visitRecordCount = await _countRows('visit_records');
    final int visitProjectCount = await _countRows('visit_projects');
    return AccountDataSummary(
      customerCount: customerCount,
      scheduleCount: scheduleCount,
      visitRecordCount: visitRecordCount,
      visitProjectCount: visitProjectCount,
    );
  }

  Future<int> _countRows(String tableName) async {
    final String? userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    final PostgrestResponse<dynamic> response =
        await _supabase.from(tableName).select('id').eq('profile_id', userId).count(CountOption.exact);
    return response.count;
  }

  /// 呼叫雲端函式刪除帳號；成功後在這台裝置登出
  Future<void> deleteMyAccount(String typedConfirmText) async {
    if (typedConfirmText.trim() != confirmText) {
      throw const AccountDeletionException('請輸入「$confirmText」確認');
    }

    try {
      await _supabase.functions.invoke('delete-account', body: {'confirmText': confirmText});
    } on FunctionException catch (error) {
      throw AccountDeletionException(_errorMessageFrom(error.details));
    } catch (error) {
      if (kDebugMode) debugPrint('刪除帳號失敗: $error');
      throw const AccountDeletionException('連線失敗，帳號沒有被刪除，請檢查網路後再試');
    }

    // 帳號在伺服器上已經不存在，只清掉這台裝置的登入狀態
    try {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      if (kDebugMode) debugPrint('刪除帳號後登出失敗: $error');
    }
  }

  String _errorMessageFrom(dynamic details) {
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return '刪除帳號失敗，帳號沒有被刪除，請稍後再試';
  }
}
