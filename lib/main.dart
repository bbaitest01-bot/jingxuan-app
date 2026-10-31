// Force Vercel rebuild - 2026-07-15 17:38
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'router/app_router.dart';
import 'services/app_settings.dart';
import 'services/auth_status_service.dart';
import 'services/google_calendar_sync_service.dart';
import 'services/app_localizations.dart';
import 'theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

// Global flag to track if we are in offline preview mode
bool isOfflineMode = false;
String offlineReason = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 網址不帶 #（/customers 而不是 /#/customers）
  usePathUrlStrategy();
  await initializeDateFormatting('zh_TW', null);
  await initializeDateFormatting('en_US', null);

  // Load AppSettings & Calendar Sync Settings
  await AppSettings.instance.loadSettings();
  await GoogleCalendarSyncService.instance.init();

  // Try loading dotenv
  try {
    await dotenv.load(fileName: ".env", isOptional: true);
  } catch (e) {
    // If dotenv.load fails, it might still have environment defines
  }

  // Dual-track fallback: check dotenv first, then const String.fromEnvironment, then project defaults
  String? supabaseUrl = dotenv.maybeGet('SUPABASE_URL');
  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  }
  if (supabaseUrl.isEmpty) {
    supabaseUrl = 'https://algufuoxkeizxwkofmmp.supabase.co';
  }

  String? supabaseKey = dotenv.maybeGet('SUPABASE_ANON_KEY');
  if (supabaseKey == null || supabaseKey.isEmpty) {
    supabaseKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  }
  if (supabaseKey.isEmpty) {
    supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsZ3VmdW94a2Vpenh3a29mbW1wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0OTU2NzgsImV4cCI6MjA5OTA3MTY3OH0.QMEU47EHuLwEr7ok7O28h6U7Sh-geldoTQ5eZfI5tBA';
  }

  // If placeholders or empty values are detected, fall back to offline preview
  if (supabaseUrl.isEmpty ||
      supabaseKey.isEmpty ||
      supabaseUrl.contains('your-project-id')) {
    isOfflineMode = true;
    offlineReason = '未檢測到有效的 Supabase URL 或 ANON KEY';
  } else {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      isOfflineMode = false;
    } catch (e) {
      isOfflineMode = true;
      offlineReason = 'Supabase 初始化連線失敗: $e';
    }
  }

  // 先讀好登入狀態與帳號狀態，路由守門才能在第一個畫面就判斷正確
  await AuthStatusService.instance.start();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 路由只建立一次；切換主題或語言重畫時沿用同一個，才不會跳回登入頁
  late final GoRouter _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, child) {
        // 主題集中在 lib/theme/app_theme.dart：明亮、深色兩套，顏色跟著選的主題色
        final AppAccent accent = AppSettings.instance.accent;
        final ThemeData lightTheme = AppTheme.light(accent);
        final ThemeData darkTheme = AppTheme.dark(accent);

        return MaterialApp.router(
          routerConfig: _router,
          title: '經選助手',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: AppSettings.instance.themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'TW'),
            Locale('en', 'US'),
          ],
          locale: AppSettings.instance.language == 'zh_TW'
              ? const Locale('zh', 'TW')
              : const Locale('en', 'US'),
          localeResolutionCallback: (locale, supportedLocales) {
            return AppSettings.instance.language == 'zh_TW'
                ? const Locale('zh', 'TW')
                : const Locale('en', 'US');
          },
        );
      },
    );
  }
}

class OfflineDataStore {
  static String? _ownerId;
  static List<Map<String, dynamic>> customers = [];
  static List<Map<String, dynamic>> customerRelationships = [];
  static List<Map<String, dynamic>> scheduleEvents = [];

  static void ensureOwner(String ownerId) {
    if (_ownerId != ownerId) {
      clear();
      _ownerId = ownerId;
    }
  }

  static void clear() {
    _ownerId = null;
    customers = [];
    customerRelationships = [];
    scheduleEvents = [];
  }
}
