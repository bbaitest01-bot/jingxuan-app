import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'onboarding_tour_steps.dart';

/// 新手大導覽的進度（2026-11-01 重做，取代舊的 SpotlightTourService）
///
/// - 第一次登入自動跳出一次（記在帳號資料 `onboarding_tour_seen`，換電腦也不會再跳）
/// - 網址加 `?tour=first` 可以假裝第一次登入，測試用
/// - 系統設定 → 教學中心「開始導覽」隨時重看
/// 畫面怎麼畫在 `widgets/onboarding_tour_overlay.dart`，每一步的內容在 [onboardingTourSteps]。
class OnboardingTourService extends ChangeNotifier {
  static final OnboardingTourService instance = OnboardingTourService._internal();
  OnboardingTourService._internal();

  /// 帳號資料裡記「看過導覽」的欄位名稱
  static const String seenMetadataKey = 'onboarding_tour_seen';

  bool _isActive = false;
  int _stepIndex = 0;

  /// 最後一次是往前還是往後：某一步找不到東西要跳過時，照同一個方向跳
  bool _isMovingForward = true;

  /// 這次開 App 已經檢查過要不要自動跳出（避免換頁時重複檢查）
  bool _hasCheckedFirstTime = false;

  bool get isActive => _isActive;
  int get stepIndex => _stepIndex;
  int get stepCount => onboardingTourSteps.length;
  OnboardingTourStep get currentStep => onboardingTourSteps[_stepIndex];
  bool get isFirstStep => _stepIndex == 0;
  bool get isLastStep => _stepIndex == stepCount - 1;

  /// 從第一步開始
  void start() {
    _stepIndex = 0;
    _isMovingForward = true;
    _isActive = true;
    notifyListeners();
  }

  void next() {
    if (isLastStep) {
      finish();
      return;
    }
    _stepIndex++;
    _isMovingForward = true;
    notifyListeners();
  }

  void previous() {
    if (isFirstStep) return;
    _stepIndex--;
    _isMovingForward = false;
    notifyListeners();
  }

  /// 這一步畫面上找不到要指的東西（例如沒有客戶）：照剛剛的方向跳過
  void skipCurrent() {
    if (_isMovingForward) {
      next();
      return;
    }
    if (isFirstStep) {
      next();
      return;
    }
    previous();
  }

  /// 看完或按「略過導覽」：關掉，並記在帳號裡下次不再自動跳出
  Future<void> finish() async {
    _isActive = false;
    notifyListeners();
    await _markSeen();
  }

  /// 登入後呼叫一次：網址有 `?tour=first`，或帳號還沒看過導覽，就自動開始
  void startIfFirstTime() {
    if (_hasCheckedFirstTime || _isActive) return;
    _hasCheckedFirstTime = true;
    // 支援一般網址 (?tour=first) 與 Flutter Web 雜湊網址 (/#/?tour=first)
    final bool isForcedByUrl = Uri.base.queryParameters['tour'] == 'first' ||
        (Uri.base.hasFragment && Uri.parse(Uri.base.fragment).queryParameters['tour'] == 'first');
    if (isForcedByUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) => start());
      return;
    }
    if (isOfflineMode) return;
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final Object? seen = user.userMetadata?[seenMetadataKey];
    if (seen == true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  Future<void> _markSeen() async {
    if (isOfflineMode) return;
    try {
      final SupabaseClient supabase = Supabase.instance.client;
      final User? user = supabase.auth.currentUser;
      if (user == null) return;
      await supabase.auth.updateUser(
        UserAttributes(data: {...?user.userMetadata, seenMetadataKey: true}),
      );
    } catch (error) {
      // 記不起來只會讓下次再跳一次，不影響使用
      if (kDebugMode) print('記錄看過新手導覽失敗: $error');
    }
  }
}
