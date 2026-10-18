import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../theme/app_accent.dart';

export '../theme/app_accent.dart' show AppAccent, AppThemeColors;

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._internal();
  AppSettings._internal();

  // Settings State
  // 預設明亮（2026-10-18 沛沛決定，配合新設計的米白紙感底色）
  ThemeMode _themeMode = ThemeMode.light;
  AppAccent _accent = AppThemeColors.defaultAccent;
  String _defaultCustomerViewMode = 'card'; // 'card' or 'list'
  bool _isSidebarCollapsedByDefault = false;
  bool _isSidebarHoverExpandEnabled = false;
  String _language = 'zh_TW';

  // Getters
  ThemeMode get themeMode => _themeMode;
  /// 目前選的主題色（整組：明亮、深色各一組主色與淡底）
  AppAccent get accent => _accent;

  /// 目前畫面該用的主題色：深色模式回傳比較亮的那個，才看得清楚。
  /// 新寫的畫面請改用 `Theme.of(context).colorScheme.primary` 或 `context.appColors.acc`
  Color get primaryColor => _accent.accentFor(_effectiveBrightness());

  /// 依主題模式算出現在是明亮還是深色；「跟隨系統」時看裝置設定
  Brightness _effectiveBrightness() {
    if (_themeMode == ThemeMode.light) {
      return Brightness.light;
    }
    if (_themeMode == ThemeMode.dark) {
      return Brightness.dark;
    }
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }
  String get defaultCustomerViewMode => _defaultCustomerViewMode;
  bool get isSidebarCollapsedByDefault => _isSidebarCollapsedByDefault;
  bool get isSidebarHoverExpandEnabled => _isSidebarHoverExpandEnabled;
  String get language => _language;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// App 啟動時讀取這台裝置上的設定（瀏覽器本機）。
  /// 帳號裡的設定要等登入後由 AuthStatusService 呼叫 [applyCloudSettings] 套用（問題 G1）
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Theme Mode
      final themeStr = prefs.getString('prefs_theme_mode') ?? 'light';
      if (themeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (themeStr == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.light;
      }

      // Load Primary Color
      // 舊版存的顏色（例如商務青藍）會在這裡換成新的四種主題色之一
      final int? storedColorValue = prefs.getInt('prefs_primary_color');
      _accent = AppThemeColors.accentFromStoredValue(storedColorValue);

      // Load Customer View Mode
      _defaultCustomerViewMode = prefs.getString('prefs_customer_view_mode') ?? 'card';

      // Load Sidebar Preference
      _isSidebarCollapsedByDefault = prefs.getBool('prefs_sidebar_collapsed') ?? false;

      // Load Sidebar Hover Expand Preference
      _isSidebarHoverExpandEnabled = prefs.getBool('prefs_sidebar_hover_expand') ?? false;

      // Load Language
      _language = prefs.getString('prefs_language') ?? 'zh_TW';

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings from SharedPreferences: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// 登入（或換人登入）後，讀回存在帳號裡的設定並套用，讓不同裝置看到同一套設定。
  /// 以前在 App 啟動、還沒連上 Supabase 前就讀，所以每次都讀不到（問題 G1、A4）
  Future<void> applyCloudSettings() async {
    if (isOfflineMode) return;

    try {
      // 向伺服器要最新的帳號資料：瀏覽器自己存的登入資料是上次登入時的版本，
      // 另一台裝置改過的設定不會在裡面（只重新整理、沒重新登入時會讀到舊設定）
      final UserResponse latest = await Supabase.instance.client.auth.getUser();
      final User? user = latest.user;
      if (user != null && user.userMetadata != null && user.userMetadata!['app_settings'] != null) {
        final Map<String, dynamic> cloudData = Map<String, dynamic>.from(user.userMetadata!['app_settings']);
        
        bool hasChanges = false;

        if (cloudData.containsKey('theme_mode')) {
          final cloudTheme = cloudData['theme_mode'];
          final newTheme = cloudTheme == 'dark'
              ? ThemeMode.dark
              : cloudTheme == 'system'
                  ? ThemeMode.system
                  : ThemeMode.light;
          if (_themeMode != newTheme) {
            _themeMode = newTheme;
            hasChanges = true;
          }
        }

        if (cloudData.containsKey('primary_color_value')) {
          // 帳號裡可能還是舊版顏色，或不是數字的怪值，一律換成新的主題色
          final Object? cloudColorValue = cloudData['primary_color_value'];
          int? storedColorValue;
          if (cloudColorValue is int) {
            storedColorValue = cloudColorValue;
          }
          final AppAccent cloudAccent = AppThemeColors.accentFromStoredValue(storedColorValue);
          if (_accent.id != cloudAccent.id) {
            _accent = cloudAccent;
            hasChanges = true;
          }
        }

        if (cloudData.containsKey('customer_view_mode')) {
          final viewMode = cloudData['customer_view_mode'] as String;
          if (_defaultCustomerViewMode != viewMode) {
            _defaultCustomerViewMode = viewMode;
            hasChanges = true;
          }
        }

        if (cloudData.containsKey('sidebar_collapsed')) {
          final sidebarCol = cloudData['sidebar_collapsed'] as bool;
          if (_isSidebarCollapsedByDefault != sidebarCol) {
            _isSidebarCollapsedByDefault = sidebarCol;
            hasChanges = true;
          }
        }

        if (cloudData.containsKey('sidebar_hover_expand')) {
          final hoverExpand = cloudData['sidebar_hover_expand'] as bool;
          if (_isSidebarHoverExpandEnabled != hoverExpand) {
            _isSidebarHoverExpandEnabled = hoverExpand;
            hasChanges = true;
          }
        }

        if (cloudData.containsKey('language')) {
          final lang = cloudData['language'] as String;
          if (_language != lang) {
            _language = lang;
            hasChanges = true;
          }
        }

        if (hasChanges) {
          await _saveToLocalPrefs();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Cloud sync on startup failed: $e');
    }
  }

  /// Update Theme Mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _saveAndSync();
  }

  /// 換主題色
  Future<void> setAccent(AppAccent accent) async {
    if (_accent.id == accent.id) return;
    _accent = accent;
    notifyListeners();
    await _saveAndSync();
  }

  /// Update Customer View Mode Preference
  Future<void> setDefaultCustomerViewMode(String mode) async {
    if (_defaultCustomerViewMode == mode) return;
    _defaultCustomerViewMode = mode;
    notifyListeners();
    await _saveAndSync();
  }

  /// Update Sidebar Collapsed Preference
  /// Also syncs hover-expand: enabled when collapsed, disabled when not collapsed.
  Future<void> setSidebarCollapsedByDefault(bool collapsed) async {
    if (_isSidebarCollapsedByDefault == collapsed) return;
    _isSidebarCollapsedByDefault = collapsed;
    _isSidebarHoverExpandEnabled = collapsed; // 懸停展開與折疊偏好連動
    notifyListeners();
    await _saveAndSync();
  }

  /// Update Sidebar Hover Expand Preference
  Future<void> setSidebarHoverExpandEnabled(bool enabled) async {
    if (_isSidebarHoverExpandEnabled == enabled) return;
    _isSidebarHoverExpandEnabled = enabled;
    notifyListeners();
    await _saveAndSync();
  }

  /// Update Language
  Future<void> setLanguage(String lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    await _saveAndSync();
  }

  /// 登出時恢復預設設定（只改這台裝置，不動帳號裡存的設定），避免下一位登入的人沿用上一位的設定
  Future<void> clearForSignOut() async {
    _themeMode = ThemeMode.light;
    _accent = AppThemeColors.defaultAccent;
    _defaultCustomerViewMode = 'card';
    _isSidebarCollapsedByDefault = false;
    _isSidebarHoverExpandEnabled = false;
    _language = 'zh_TW';
    notifyListeners();
    await _saveToLocalPrefs();
  }

  /// Reset to factory default settings
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.light;
    _accent = AppThemeColors.defaultAccent;
    _defaultCustomerViewMode = 'card';
    _isSidebarCollapsedByDefault = false;
    _isSidebarHoverExpandEnabled = false;
    _language = 'zh_TW';
    notifyListeners();
    await _saveAndSync();
  }

  /// Save settings to SharedPreferences
  Future<void> _saveToLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('prefs_theme_mode', _themeMode.name);
      await prefs.setInt('prefs_primary_color', _accent.storedValue);
      await prefs.setString('prefs_customer_view_mode', _defaultCustomerViewMode);
      await prefs.setBool('prefs_sidebar_collapsed', _isSidebarCollapsedByDefault);
      await prefs.setBool('prefs_sidebar_hover_expand', _isSidebarHoverExpandEnabled);
      await prefs.setString('prefs_language', _language);
    } catch (e) {
      debugPrint('Error saving settings to SharedPreferences: $e');
    }
  }

  /// Save to local prefs AND sync with Supabase User Metadata
  Future<void> _saveAndSync() async {
    await _saveToLocalPrefs();

    if (isOfflineMode) return;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        final settingsJson = {
          'theme_mode': _themeMode.name,
          'primary_color_value': _accent.storedValue,
          'customer_view_mode': _defaultCustomerViewMode,
          'sidebar_collapsed': _isSidebarCollapsedByDefault,
          'sidebar_hover_expand': _isSidebarHoverExpandEnabled,
          'language': _language,
          'updated_at': DateTime.now().toIso8601String(),
        };

        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              ...?user.userMetadata,
              'app_settings': settingsJson,
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Error syncing settings to Supabase: $e');
    }
  }
}
