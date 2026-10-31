import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// 每日行程提醒信服務 (Singleton)
/// 規則：預設關閉（避免打擾），由業務員在設定頁自行開啟並選擇寄信時段
class ScheduleReminderService {
  static final ScheduleReminderService instance = ScheduleReminderService._internal();
  ScheduleReminderService._internal();

  static const String _prefEnabledKey = 'prefs_schedule_reminder_enabled';
  static const String _prefTimeKey = 'prefs_schedule_reminder_time';

  /// 可選的寄信時段清單
  static const List<Map<String, String>> timeOptions = [
    {'value': '06:00', 'label': '☀️ 早上 06:00（寄今日行程）'},
    {'value': '07:00', 'label': '☀️ 早上 07:00（寄今日行程，預設）'},
    {'value': '08:00', 'label': '☀️ 早上 08:00（寄今日行程）'},
    {'value': '20:00', 'label': '🌙 前晚 20:00（寄明日行程）'},
    {'value': '21:00', 'label': '🌙 前晚 21:00（寄明日行程）'},
  ];

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  String _reminderTime = '07:00';
  String get reminderTime => _reminderTime;

  /// 取得目前時間標籤文字
  String get reminderTimeLabel {
    for (final option in timeOptions) {
      if (option['value'] == _reminderTime) {
        return option['label'] ?? _reminderTime;
      }
    }
    return _reminderTime;
  }

  /// 載入提醒信設定（優先從 profiles 讀取，並快取至本機）
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefEnabledKey) ?? false;
      _reminderTime = prefs.getString(_prefTimeKey) ?? '07:00';

      if (isOfflineMode) return;

      try {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user != null) {
          final Map<String, dynamic>? data = await supabase
              .from('profiles')
              .select('schedule_reminder_enabled, schedule_reminder_time')
              .eq('id', user.id)
              .maybeSingle();

          if (data != null) {
            if (data['schedule_reminder_enabled'] != null) {
              _isEnabled = data['schedule_reminder_enabled'] == true;
              await prefs.setBool(_prefEnabledKey, _isEnabled);
            }
            if (data['schedule_reminder_time'] != null) {
              _reminderTime = data['schedule_reminder_time'] as String;
              await prefs.setString(_prefTimeKey, _reminderTime);
            }
          }
        }
      } catch (e) {
        if (e is! AssertionError) {
          debugPrint('⚠️ [ScheduleReminderService] 載入設定失敗: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ScheduleReminderService] 載入本機快取失敗: $e');
    }
  }

  /// 儲存提醒信開關與時間設定
  Future<void> saveSettings({
    required bool isEnabled,
    required String reminderTime,
  }) async {
    _isEnabled = isEnabled;
    _reminderTime = reminderTime;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefEnabledKey, isEnabled);
      await prefs.setString(_prefTimeKey, reminderTime);
    } catch (e) {
      debugPrint('⚠️ [ScheduleReminderService] 快取至本機失敗: $e');
    }

    if (isOfflineMode) return;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('profiles').update({
          'schedule_reminder_enabled': isEnabled,
          'schedule_reminder_time': reminderTime,
        }).eq('id', user.id);
      }
    } catch (e) {
      if (e is! AssertionError) {
        debugPrint('⚠️ [ScheduleReminderService] 儲存至資料庫失敗: $e');
        rethrow;
      }
    }
  }

  /// 立即寄送一封測試提醒信給目前登入的業務員
  Future<void> sendTestEmail() async {
    if (isOfflineMode) {
      throw Exception('離線預覽模式無法發送信件');
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final email = user?.email;

    final FunctionResponse response = await supabase.functions.invoke(
      'send-daily-schedule-reminder',
      body: {
        'action': 'test',
        if (email != null && email.isNotEmpty) 'test_email': email,
      },
    );

    if (response.status != 200) {
      throw Exception('寄送失敗 (狀態碼: ${response.status}): ${response.data}');
    }
  }
}
