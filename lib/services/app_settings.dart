import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// Available primary theme colors for personalization
class AppThemeColors {
  static const Color tealCyan = Color(0xFF00ADB5);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color royalPurple = Color(0xFF8B5CF6);
  static const Color amberGold = Color(0xFFF59E0B);

  static const List<Map<String, dynamic>> palette = [
    {'name': '商務青藍', 'color': tealCyan},
    {'name': '皇家寶藍', 'color': royalBlue},
    {'name': '翡翠鮮綠', 'color': emeraldGreen},
    {'name': '高雅奢紫', 'color': royalPurple},
    {'name': '暖陽琥珀', 'color': amberGold},
  ];
}

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._internal();
  AppSettings._internal();

  // Settings State
  ThemeMode _themeMode = ThemeMode.dark;
  Color _primaryColor = AppThemeColors.tealCyan;
  String _defaultCustomerViewMode = 'card'; // 'card' or 'list'
  bool _isSidebarCollapsedByDefault = false;
  bool _isSidebarHoverExpandEnabled = false;
  String _language = 'zh_TW';

  // Getters
  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
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
      final themeStr = prefs.getString('prefs_theme_mode') ?? 'dark';
      if (themeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeStr == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.dark;
      }

      // Load Primary Color
      final colorInt = prefs.getInt('prefs_primary_color');
      if (colorInt != null) {
        _primaryColor = Color(colorInt);
      }

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
          final newTheme = cloudTheme == 'light'
              ? ThemeMode.light
              : cloudTheme == 'system'
                  ? ThemeMode.system
                  : ThemeMode.dark;
          if (_themeMode != newTheme) {
            _themeMode = newTheme;
            hasChanges = true;
          }
        }

        if (cloudData.containsKey('primary_color_value')) {
          final colorValue = cloudData['primary_color_value'] as int;
          if (_primaryColor.value != colorValue) {
            _primaryColor = Color(colorValue);
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

  /// Update Primary Accent Color
  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor.value == color.value) return;
    _primaryColor = color;
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
    _themeMode = ThemeMode.dark;
    _primaryColor = AppThemeColors.tealCyan;
    _defaultCustomerViewMode = 'card';
    _isSidebarCollapsedByDefault = false;
    _isSidebarHoverExpandEnabled = false;
    _language = 'zh_TW';
    notifyListeners();
    await _saveToLocalPrefs();
  }

  /// Reset to factory default settings
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.dark;
    _primaryColor = AppThemeColors.tealCyan;
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
      await prefs.setInt('prefs_primary_color', _primaryColor.value);
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
          'primary_color_value': _primaryColor.value,
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
