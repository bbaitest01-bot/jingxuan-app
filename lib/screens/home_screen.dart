import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/app_settings.dart';
import '../models/schedule_event.dart';
import '../widgets/custom_toast.dart';
import '../widgets/voice_scheduler_fab.dart';
import 'customer_management_tab.dart';
import 'visit_projects_tab.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'trash_bin_screen.dart';
import 'insurance_news_tab.dart';
import '../widgets/spotlight_tour_overlay.dart';
import '../models/user_role.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';
import '../services/auth_status_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/schedule_service.dart';
import 'admin_dashboard_tab.dart';
import 'dev_console_screen.dart';
import 'relationship_topology_tab.dart';
import 'data_dashboard_tab.dart';
import 'home/home_sidebar.dart';
import 'home/home_top_bar.dart';
import 'home/not_found_page.dart';
import 'home/schedule/schedule_dialogs.dart';
import 'home/schedule/schedule_page.dart';
import 'home/schedule/schedule_page_state.dart';

/// 登入後的外殼（側邊欄＋頂欄＋內容區）。
/// 目前顯示哪一頁由網址決定：路由把網址轉成選單名稱 [activeMenu] 傳進來。
class HomeScreen extends StatefulWidget {
  final String activeMenu;

  const HomeScreen({super.key, required this.activeMenu});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now(); // Default to dynamic current time
  String get _activeMenu => widget.activeMenu;

  bool _isSidebarCollapsed = false;
  bool _isSidebarHovered = false;

  bool get _effectiveSidebarCollapsed {
    final bool isHoverExpandActive = AppSettings.instance.isSidebarHoverExpandEnabled;
    return _isSidebarCollapsed && !(isHoverExpandActive && _isSidebarHovered);
  }

  String _userName = '載入中...';
  String _userEmail = '';
  String _userAvatarUrl = '';

  List<ScheduleEvent> _events = [];
  bool _isLoadingEvents = false;
  String _calendarViewMode = 'timeline'; // 'timeline' (日時間軸) 或 'month_grid' (月網格)

  UserRole _userRole = UserRole.agent;
  UserRole _activeViewRole = UserRole.agent;
  final NotificationService _notifService = NotificationService();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _isSidebarCollapsed = AppSettings.instance.isSidebarCollapsedByDefault;
    AppSettings.instance.addListener(_handleSettingsChanged);
    _notifService.addListener(_handleNotifChanged);
    if (!isOfflineMode) {
      try {
        _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          if (mounted) {
            _fetchEventsForSelectedDate(silent: true);
          }
        });
      } catch (e) {
        debugPrint('⚠️ [HomeScreen] Supabase 離線模式跳過 Auth 監聽: $e');
      }
    }
    _loadUserProfile();
    _loadSavedViewMode().then((_) {
      if (mounted) _fetchEventsForSelectedDate(silent: true);
    });
    _fetchEventsForSelectedDate();
    _showRouteNoticeAfterBuild();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 網址換頁時，守門規則可能留了提示（例如沒有權限開啟此頁）
    _showRouteNoticeAfterBuild();
  }

  void _showRouteNoticeAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? warningMessage = RouteNotice.takeWarning();
      if (warningMessage != null && mounted) {
        CustomToast.show(context, warningMessage, ToastType.warning);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _notifService.removeListener(_handleNotifChanged);
    AppSettings.instance.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  void _handleNotifChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchEventsForSelectedDate({bool silent = false}) async {
    if (isOfflineMode) {
      if (!silent && mounted) {
        CustomToast.show(context, '目前為離線預覽模式，無法讀取真實行程資料。', ToastType.warning);
      }
      setState(() {
        _events = [];
      });
      return;
    }

    if (!silent && _events.isEmpty) {
      setState(() => _isLoadingEvents = true);
    }
    try {
      final List<ScheduleEvent>? events = await ScheduleService.instance.fetchOwnEventsForView(
        selectedDate: _selectedDate,
        viewMode: _calendarViewMode,
      );
      // events 是 null 代表沒有登入者，保留畫面上原本的行程
      if (events != null && mounted) {
        setState(() {
          _events = events;
        });
      }
    } catch (e) {
      // 讀取失敗時保留畫面上原本的行程
      debugPrint('⚠️ [HomeScreen] 讀取行程失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  // 開啟行程編輯視窗；存檔、修改或刪除後重新讀取並顯示提示
  Future<void> _openAddEditEventDialog([ScheduleEvent? event]) async {
    final dynamic result = await showScheduleEventEditor(
      context,
      initialDate: _selectedDate,
      event: event,
    );
    if (result == null || !mounted) return;

    _fetchEventsForSelectedDate();
    if (result == 'created') {
      CustomToast.show(context, '行程已成功新增！', ToastType.success);
    } else if (result == 'updated') {
      CustomToast.show(context, '行程變更已儲存！', ToastType.success);
    } else if (result == 'deleted') {
      CustomToast.show(context, '行程已成功刪除！', ToastType.warning);
    }
  }

  void _openRoutePlannerDialog({required DateTime date, required List<ScheduleEvent> events}) {
    showRoutePlanner(context, date: date, events: events);
  }

  // 語音排程：錄音 → AI 解析 → 跳到該行程的日期 → 開啟編輯視窗讓使用者核對後儲存
  Future<void> _openVoiceSchedulerDialog() async {
    if (isOfflineMode) {
      CustomToast.show(context, '⚠️ 離線預覽模式：語音排程需要雲端 AI 連線，請在連線模式下使用。', ToastType.warning);
      return;
    }

    final Map<String, dynamic>? result = await showVoiceSchedulerOverlay(context);
    if (result == null || !mounted) return;

    final String status = result['status'] as String? ?? 'green';
    final Map<String, dynamic>? eventMap = result['event'] as Map<String, dynamic>?;

    ScheduleEvent? event;
    if (eventMap != null) {
      try {
        event = ScheduleEvent.fromJson(eventMap);
      } catch (e) {
        debugPrint('解析語音行程失敗，改用預設行程物件: $e');
      }
    }

    if (event != null) {
      final DateTime eventStart = event.startAt;
      setState(() {
        _selectedDate = DateTime(eventStart.year, eventStart.month, eventStart.day);
      });
    }

    // 黃燈：AI 覺得資訊不完整，列出缺漏提醒；綠燈：直接提示確認
    if (status == 'yellow') {
      final List<String> warnings = List<String>.from(result['warning_messages'] ?? []);
      String warningText = '行程資訊有所遺漏，請核對並補充細節！';
      if (warnings.isNotEmpty) {
        warningText = '⚠️ ${warnings.join('； ')}';
      }
      CustomToast.show(context, warningText, ToastType.warning);
    } else {
      CustomToast.show(context, '語音辨識完成，請確認並儲存行程！', ToastType.success);
    }
    // 不論綠燈、黃燈或解析例外，均一律開啟手動編輯視窗供專案人員最終核對與儲存
    await _openAddEditEventDialog(event);
  }

  // 「懸停自動展開」：側邊欄收合時，滑鼠移進去暫時展開，移出再收回
  void _handleSidebarPointerEnter() {
    final bool isHoverExpandActive = AppSettings.instance.isSidebarHoverExpandEnabled;
    if (isHoverExpandActive && _isSidebarCollapsed && !_isSidebarHovered) {
      setState(() {
        _isSidebarHovered = true;
      });
    }
  }

  void _handleSidebarPointerExit() {
    final bool isHoverExpandActive = AppSettings.instance.isSidebarHoverExpandEnabled;
    if (isHoverExpandActive && _isSidebarHovered) {
      setState(() {
        _isSidebarHovered = false;
      });
    }
  }

  void _handleSettingsChanged() {
    if (mounted) {
      setState(() {
        _isSidebarCollapsed = AppSettings.instance.isSidebarCollapsedByDefault;
      });
    }
  }

  // 讀回上次選的行事曆視圖（日／月／議程）；在哪一頁改由網址記住
  Future<void> _loadSavedViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedViewMode = prefs.getString('calendar_view_mode');
      if (savedViewMode != null && mounted) {
        setState(() {
          _calendarViewMode = savedViewMode;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _updateCalendarViewMode(String mode) {
    if (_calendarViewMode != mode) {
      setState(() {
        _calendarViewMode = mode;
      });
      _fetchEventsForSelectedDate(silent: true);
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('calendar_view_mode', mode);
      });
    }
  }

  // 換頁＝前往該選單的網址
  void _changeActiveMenu(String menu) {
    if (!mounted) return;
    context.go(AppRoutes.pathForMenu(menu));
  }

  Future<void> _loadUserProfile() async {
    final UserProfileSummary? profile = await ProfileService.instance.loadCurrentUserSummary();
    // profile 是 null 代表沒有登入者，保留畫面上原本的資料
    if (profile == null || !mounted) return;

    setState(() {
      _userName = profile.name;
      _userEmail = profile.email;
      _userAvatarUrl = profile.avatarUrl;
      // 有讀到角色才更新，讀取失敗時維持原本的角色
      final UserRole? fetchedRole = profile.role;
      if (fetchedRole != null) {
        _userRole = fetchedRole;
        _activeViewRole = fetchedRole;
      }
    });
  }

  // Sign out handler
  Future<void> _handleSignOut() async {
    // 離線預覽：結束預覽後，守門規則會自動帶回登入頁
    if (isOfflineMode) {
      AuthStatusService.instance.leaveOfflinePreview();
      return;
    }

    try {
      await Supabase.instance.client.auth.signOut();
      // 登出後守門規則會自動帶回登入頁
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '登出失敗: $e', ToastType.error);
      }
    }
  }

  // 點月份標題時開啟日期選擇器，選了不同日期才更新
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showScheduleDatePicker(context, _selectedDate);
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 768;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = AppSettings.instance.primaryColor;

    // 側邊欄（電腦版放左邊，手機版放在抽屜裡）
    Widget sidebarContent() {
      return HomeSidebar(
        activeMenu: _activeMenu,
        isCollapsed: _effectiveSidebarCollapsed,
        isWideScreen: isWideScreen,
        userName: _userName,
        userEmail: _userEmail,
        userAvatarUrl: _userAvatarUrl,
        userRole: _userRole,
        activeViewRole: _activeViewRole,
        onMenuSelected: _changeActiveMenu,
        onReturnToDevView: () {
          setState(() {
            _activeViewRole = UserRole.dev;
          });
          context.go(AppRoutes.dev);
        },
        onToggleCollapse: () {
          setState(() {
            _isSidebarCollapsed = !_isSidebarCollapsed;
            _isSidebarHovered = false; // 手動收合／展開時，重設懸停狀態
          });
        },
        onPointerEnter: _handleSidebarPointerEnter,
        onPointerExit: _handleSidebarPointerExit,
        onSignOut: _handleSignOut,
      );
    }

    return Stack(
      children: [
        Scaffold(
          drawer: isWideScreen ? null : Drawer(child: sidebarContent()),
          appBar: isWideScreen
              ? null
              : HomeMobileAppBar(
                  activeMenu: _activeMenu,
                  isSchedulePage: _activeMenu == '今日行程',
                  unreadCount: _notifService.unreadCount,
                  onRefresh: () => _fetchEventsForSelectedDate(),
                  onAddEvent: () => _openAddEditEventDialog(),
                ),
          body: Row(
            children: [
              if (isWideScreen) sidebarContent(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 電腦版頂欄
                    if (isWideScreen) HomeWebHeader(activeMenu: _activeMenu, unreadCount: _notifService.unreadCount),
                    // 主要內容區：依目前選單顯示對應頁面
                    Expanded(child: _buildActivePage(isWideScreen)),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _activeMenu == '今日行程'
              ? VoiceSchedulerFab(
                  onPressed: _openVoiceSchedulerDialog,
                  isDark: isDark,
                  primaryColor: primaryColor,
                )
              : null,
        ),
        const SpotlightTourOverlay(),
      ],
    );
  }

  Widget _buildSchedulePage(bool isWideScreen) {
    final ScheduleViewData scheduleData = ScheduleViewData(
      selectedDate: _selectedDate,
      events: _events,
      isLoading: _isLoadingEvents,
      viewMode: _calendarViewMode,
    );
    final ScheduleActions scheduleActions = ScheduleActions(
      selectDate: (DateTime newDate) {
        setState(() {
          _selectedDate = newDate;
        });
      },
      selectDateAndReload: (DateTime newDate) {
        setState(() {
          _selectedDate = newDate;
        });
        _fetchEventsForSelectedDate(silent: true);
      },
      reload: _fetchEventsForSelectedDate,
      changeViewMode: _updateCalendarViewMode,
      openEventEditor: _openAddEditEventDialog,
      openRoutePlanner: _openRoutePlannerDialog,
      pickDate: () => _selectDate(context),
    );

    return SchedulePage(
      data: scheduleData,
      actions: scheduleActions,
      isWideScreen: isWideScreen,
    );
  }

  // 依目前選單決定主要內容區要顯示哪一頁
  Widget _buildActivePage(bool isWideScreen) {
    switch (_activeMenu) {
      case '👑 團隊戰情室':
        return const AdminDashboardTab();
      case '🛠️ 實體服務診斷':
        return DevConsoleScreen(
          activeRole: _activeViewRole,
          onRoleChanged: _switchViewRole,
        );
      case '今日行程':
        return _buildSchedulePage(isWideScreen);
      case '新聞頭條':
        return const InsuranceNewsTab();
      case '客戶管理':
        return const CustomerManagementTab();
      case '專案拜訪':
        return const VisitProjectsTab();
      case '人脈拓撲':
        return const RelationshipTopologyTab();
      case '數據戰情':
        return const DataDashboardTab();
      case '個人帳號':
        return ProfileScreen(
          onProfileUpdated: _loadUserProfile,
          onRoleChanged: _switchViewRole,
        );
      case '垃圾桶':
        return const TrashBinScreen();
      case '系統設定':
        return const SettingsScreen();
      default:
        return const NotFoundPage();
    }
  }

  // 開發者切換「檢視角色」後，跳到該角色的預設首頁
  void _switchViewRole(UserRole newRole) {
    setState(() {
      _activeViewRole = newRole;
    });
    if (newRole == UserRole.admin) {
      context.go(AppRoutes.admin);
    } else if (newRole == UserRole.dev) {
      context.go(AppRoutes.dev);
    } else {
      context.go(AppRoutes.schedule);
    }
  }
}

