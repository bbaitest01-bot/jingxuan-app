import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show isOfflineMode;

/// Google 日曆通行證（access token）管理（L4 再次發生，2026-11-08，設計見全景地圖 4-P）
///
/// 用比喻說：Google 給的通行證只能用約 1 小時；登入時另外給一張「換證單」（refresh token）。
/// - 登入時：把換證單交給資料庫保管（[saveRefreshToken]），App 自己不留
/// - 要推送行程時：通行證拿到不到 50 分鐘就直接用；太舊或被 Google 退回，
///   就請雲端函式 `refresh-google-token` 用換證單換一張新的（[getValidAccessToken]）
class GoogleAccessTokenService {
  static final GoogleAccessTokenService instance = GoogleAccessTokenService._internal();
  GoogleAccessTokenService._internal();

  // 沿用原本的快取名稱，舊版存的通行證也讀得到（沒有拿到時間的一律當作過期）
  static const String _prefTokenKey = 'google_oauth_provider_token';
  static const String _prefSavedAtKey = 'google_oauth_provider_token_saved_at';
  // Google 通行證約 60 分鐘過期，提早 10 分鐘換新
  static const Duration freshDuration = Duration(minutes: 50);

  String? _lastErrorMessage;

  /// 最近一次拿不到通行證的原因（給畫面顯示）
  String? get lastErrorMessage => _lastErrorMessage;

  /// 記下登入連線帶來的通行證；和已存的一樣就不更新時間（重新整理頁面時連線會帶著舊的通行證）
  Future<void> rememberSessionToken(String token) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedToken = prefs.getString(_prefTokenKey);
      if (savedToken == token) return;
      await _saveToken(prefs, token);
    } catch (error) {
      debugPrint('⚠️ [GoogleAccessTokenService] 記下通行證失敗：$error');
    }
  }

  /// Google 說通行證失效（401）：留著通行證本身，但把時間歸零，下次一定先換新
  Future<void> markExpired() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefSavedAtKey, 0);
    } catch (_) {}
  }

  /// 登出時清掉
  Future<void> clear() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTokenKey);
      await prefs.remove(_prefSavedAtKey);
    } catch (_) {}
  }

  /// 取得能用的通行證：還新鮮就直接用，否則請雲端函式換新；都不行回傳 null（原因在 [lastErrorMessage]）
  Future<String?> getValidAccessToken() async {
    _lastErrorMessage = null;
    if (isOfflineMode) {
      _lastErrorMessage = '離線預覽模式無法連線 Google';
      return null;
    }

    // 剛用 Google 登入時，連線本身帶著最新的通行證
    final String? sessionToken = Supabase.instance.client.auth.currentSession?.providerToken;
    if (sessionToken != null && sessionToken.isNotEmpty) {
      await rememberSessionToken(sessionToken);
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedToken = prefs.getString(_prefTokenKey);
      final int savedAtMilliseconds = prefs.getInt(_prefSavedAtKey) ?? 0;
      final bool isFresh = isTokenFresh(savedAtMilliseconds, DateTime.now());
      if (savedToken != null && savedToken.isNotEmpty && isFresh) return savedToken;
    } catch (error) {
      debugPrint('⚠️ [GoogleAccessTokenService] 讀取通行證失敗：$error');
    }

    return _refreshFromServer();
  }

  /// 通行證是不是還新鮮（拿到不到 50 分鐘）；時間是 0（沒記過或被標成過期）一律不新鮮
  static bool isTokenFresh(int savedAtMilliseconds, DateTime now) {
    if (savedAtMilliseconds <= 0) return false;
    final DateTime savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMilliseconds);
    return now.difference(savedAt) < freshDuration;
  }

  /// 登入後把換證單交給資料庫保管（只有剛用 Google 登入的那一次連線會帶換證單）
  Future<void> saveRefreshToken(String refreshToken) async {
    if (isOfflineMode) return;
    try {
      await Supabase.instance.client.rpc(
        'save_google_refresh_token',
        params: {'p_refresh_token': refreshToken},
      );
      debugPrint('🔑 [GoogleAccessTokenService] 已保存 Google 換證單');
    } catch (error) {
      debugPrint('⚠️ [GoogleAccessTokenService] 保存換證單失敗：$error');
    }
  }

  // 請雲端函式用換證單換一張新的通行證
  Future<String?> _refreshFromServer() async {
    try {
      final FunctionResponse response = await Supabase.instance.client.functions.invoke('refresh-google-token');
      final Object? data = response.data;
      if (data is Map && data['access_token'] is String) {
        final String newToken = data['access_token'] as String;
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await _saveToken(prefs, newToken);
        debugPrint('🔄 [GoogleAccessTokenService] 已換新 Google 通行證');
        return newToken;
      }
      _lastErrorMessage = 'Google 授權已過期，請登出後再用 Google 登入一次';
      return null;
    } on FunctionException catch (error) {
      final Object? details = error.details;
      String message = 'Google 授權已過期，請登出後再用 Google 登入一次';
      if (details is Map && details['error'] is String) message = details['error'] as String;
      _lastErrorMessage = message;
      debugPrint('⚠️ [GoogleAccessTokenService] 換新通行證失敗：${error.status} $details');
      return null;
    } catch (error) {
      _lastErrorMessage = '換新 Google 通行證失敗：$error';
      debugPrint('⚠️ [GoogleAccessTokenService] 換新通行證失敗：$error');
      return null;
    }
  }

  Future<void> _saveToken(SharedPreferences prefs, String token) async {
    await prefs.setString(_prefTokenKey, token);
    await prefs.setInt(_prefSavedAtKey, DateTime.now().millisecondsSinceEpoch);
  }
}
