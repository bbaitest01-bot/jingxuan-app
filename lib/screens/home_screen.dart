import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import '../models/schedule_event.dart';
import '../widgets/schedule_event_dialog.dart';
import '../widgets/custom_toast.dart';
import '../widgets/voice_scheduler_overlay.dart';
import '../widgets/voice_scheduler_fab.dart';
import 'login_screen.dart';
import 'customer_management_tab.dart';
import 'visit_projects_tab.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'trash_bin_screen.dart';
import 'insurance_news_tab.dart';
import '../widgets/route_planner_dialog.dart';
import '../widgets/spotlight_tour_overlay.dart';
import '../models/user_role.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/schedule_service.dart';
import '../widgets/notification_center_popover.dart';
import 'admin_dashboard_tab.dart';
import 'dev_console_screen.dart';
import 'relationship_topology_tab.dart';
import 'data_dashboard_tab.dart';
import 'home/home_menu.dart';
import 'home/home_sidebar.dart';
import 'home/schedule/schedule_page.dart';
import 'home/schedule/schedule_page_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now(); // Default to dynamic current time
  String _activeMenu = '今日行程';

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
    _loadSavedMenu().then((_) {
      if (mounted) _fetchEventsForSelectedDate(silent: true);
    });
    _fetchEventsForSelectedDate();
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
      final DateTime rangeStart;
      final DateTime rangeEnd;
      if (_calendarViewMode == 'month_grid' || _calendarViewMode == 'agenda') {
        // 月網格與議程清單模式：查詢全月份資料 (延伸前後各 14 天)
        rangeStart = DateTime(_selectedDate.year, _selectedDate.month, 1, 0, 0, 0).subtract(const Duration(days: 14));
        rangeEnd = DateTime(_selectedDate.year, _selectedDate.month + 2, 0, 23, 59, 59);
      } else {
        // 日時間軸模式：查詢單日涵蓋行程
        rangeStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
        rangeEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      }

      final List<ScheduleEvent>? events = await ScheduleService.instance.fetchOwnEventsInRange(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
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

  Future<void> _openAddEditEventDialog([ScheduleEvent? event]) async {
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    final result = isMobile
        ? await showModalBottomSheet<dynamic>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => ScheduleEventDialog(
              initialDate: _selectedDate,
              eventToEdit: event,
              isBottomSheet: true,
            ),
          )
        : await showDialog<dynamic>(
            context: context,
            builder: (ctx) => ScheduleEventDialog(
              initialDate: _selectedDate,
              eventToEdit: event,
            ),
          );

    if (result != null && mounted) {
      _fetchEventsForSelectedDate();

      if (result == 'created') {
        CustomToast.show(context, '行程已成功新增！', ToastType.success);
      } else if (result == 'updated') {
        CustomToast.show(context, '行程變更已儲存！', ToastType.success);
      } else if (result == 'deleted') {
        CustomToast.show(context, '行程已成功刪除！', ToastType.warning);
      }
    }
  }

  void _openRoutePlannerDialog({required DateTime date, required List<ScheduleEvent> events}) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => RoutePlannerDialog(
          selectedDate: date,
          events: events,
          isBottomSheet: true,
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => RoutePlannerDialog(
          selectedDate: date,
          events: events,
        ),
      );
    }
  }

  Future<void> _openVoiceSchedulerDialog() async {
    if (isOfflineMode) {
      CustomToast.show(context, '⚠️ 離線預覽模式：語音排程需要雲端 AI 連線，請在連線模式下使用。', ToastType.warning);
      return;
    }

    final result = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'VoiceScheduler',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const VoiceSchedulerOverlay();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: child,
        );
      },
    );

    if (result != null && mounted) {
      final status = result['status'] as String? ?? 'green';
      final eventMap = result['event'] as Map<String, dynamic>?;

      ScheduleEvent? event;
      if (eventMap != null) {
        try {
          event = ScheduleEvent.fromJson(eventMap);
        } catch (e) {
          debugPrint('解析語音行程失敗，改用預設行程物件: $e');
        }
      }

      if (event != null) {
        setState(() {
          _selectedDate = DateTime(event!.startAt.year, event.startAt.month, event.startAt.day);
        });
      }

      if (status == 'yellow') {
        final warnings = List<String>.from(result['warning_messages'] ?? []);
        final warningText = warnings.isNotEmpty
            ? '⚠️ ' + warnings.join('； ')
            : '行程資訊有所遺漏，請核對並補充細節！';
        CustomToast.show(context, warningText, ToastType.warning);
      } else {
        CustomToast.show(context, '語音辨識完成，請確認並儲存行程！', ToastType.success);
      }
      // 不論綠燈、黃燈或解析例外，均一律開啟手動編輯視窗供專案人員最終核對與儲存
      await _openAddEditEventDialog(event);
    }
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

  Future<void> _loadSavedMenu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMenu = prefs.getString('last_active_menu');
      final savedViewMode = prefs.getString('calendar_view_mode');
      if (savedMenu != null && mounted) {
        setState(() {
          _activeMenu = savedMenu;
        });
      }
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

  void _changeActiveMenu(String menu) async {
    if (!mounted) return;
    setState(() {
      _activeMenu = menu;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_active_menu', menu);
    } catch (e) {
      // ignore
    }
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
    if (isOfflineMode) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.signOut();
      // AuthGateway reactively handles returning to LoginScreen.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登出失敗: $e')),
        );
      }
    }
  }

  // Show date picker and update selected date
  Future<void> _selectDate(BuildContext context) async {
    final primaryColor = AppSettings.instance.primaryColor;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF161B22),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
          ),
          child: child!,
        );
      },
    );
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;

    final Color sidebarBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade200;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

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
            _activeMenu = '🛠️ 實體服務診斷';
          });
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
              : AppBar(
                  title: Text(
                    localizedMenuTitle(context, _activeMenu),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  ),
                  iconTheme: IconThemeData(color: textColor),
                  backgroundColor: sidebarBg,
                  elevation: 0,
                  actions: [
                    if (isOfflineMode)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.l10n('offline_preview'),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (_activeMenu == '今日行程') ...[
                      IconButton(
                        icon: Icon(Icons.refresh, size: 24, color: textColor),
                        tooltip: '重新整理',
                        onPressed: () => _fetchEventsForSelectedDate(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 26),
                        color: primaryColor,
                        tooltip: context.l10n('event_add_title'),
                        onPressed: () => _openAddEditEventDialog(),
                      ),
                    ],
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.notifications, size: 22, color: textColor),
                          tooltip: '訊息通知中心',
                          onPressed: () => NotificationCenterPopover.show(context),
                        ),
                        if (_notifService.unreadCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFF59E0B),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
          body: Row(
            children: [
              if (isWideScreen) sidebarContent(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Wide Screen Header
                    if (isWideScreen) _buildWebHeader(isDark, textColor, subTextColor, borderColor),
                    
                    // Main Working Area (Role-based & Menu-based Routing)
                    Expanded(
                      child: _activeMenu == '👑 團隊戰情室'
                          ? const AdminDashboardTab()
                          : _activeMenu == '🛠️ 實體服務診斷'
                              ? DevConsoleScreen(
                                  activeRole: _activeViewRole,
                                  onRoleChanged: (newRole) {
                                    setState(() {
                                      _activeViewRole = newRole;
                                      if (newRole == UserRole.admin) {
                                        _activeMenu = '👑 團隊戰情室';
                                      } else if (newRole == UserRole.dev) {
                                        _activeMenu = '🛠️ 實體服務診斷';
                                      } else {
                                        _activeMenu = '今日行程';
                                      }
                                    });
                                  },
                                )
                              : _activeMenu == '今日行程'
                                  ? _buildSchedulePage(isWideScreen)
                                  : _activeMenu == '新聞頭條'
                                      ? const InsuranceNewsTab()
                                      : _activeMenu == '客戶管理'
                                          ? CustomerManagementTab(
                                              onMenuChanged: (menu) {
                                                setState(() {
                                                  _activeMenu = menu;
                                                });
                                              },
                                            )
                                          : _activeMenu == '專案拜訪'
                                              ? const VisitProjectsTab()
                                              : _activeMenu == '人脈拓撲'
                                                  ? const RelationshipTopologyTab()
                                                  : _activeMenu == '數據戰情'
                                                      ? const DataDashboardTab()
                                                      : _activeMenu == '個人帳號'
                                                          ? ProfileScreen(
                                                              onProfileUpdated: _loadUserProfile,
                                                              onRoleChanged: (newRole) {
                                                                setState(() {
                                                                  _activeViewRole = newRole;
                                                                  if (newRole == UserRole.admin) {
                                                                    _activeMenu = '👑 團隊戰情室';
                                                                  } else if (newRole == UserRole.dev) {
                                                                    _activeMenu = '🛠️ 實體服務診斷';
                                                                  } else {
                                                                    _activeMenu = '今日行程';
                                                                  }
                                                                });
                                                              },
                                                            )
                                                          : _activeMenu == '垃圾桶'
                                                              ? const TrashBinScreen()
                                                              : _activeMenu == '系統設定'
                                                                  ? const SettingsScreen()
                                                                  : _buildFallbackScreen(),
                    ),
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

  // Web Header (Desktop top bar)
  Widget _buildWebHeader(bool isDark, Color textColor, Color subTextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            localizedMenuTitle(context, _activeMenu),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Row(
            children: [
              if (isOfflineMode)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withOpacity(0.3),
                    border: Border.all(color: Colors.amber.shade700, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.offline_bolt_outlined, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n('offline_preview_mode'),
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              // Notification Center Bell (Touch target >= 44x44, Minimal Amber Dot)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, size: 22),
                      color: textColor,
                      tooltip: '訊息通知中心',
                      onPressed: () => NotificationCenterPopover.show(context),
                    ),
                    if (_notifService.unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFF59E0B),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // 今日行程整頁：把目前的行程資料與可執行的動作打包後交給 SchedulePage
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

  // Fallback Placeholder screen for non-calendar sections
  Widget _buildFallbackScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _activeMenu == '客戶管理' 
                ? Icons.people_outline 
                : _activeMenu == '人脈拓撲' 
                    ? Icons.hub_outlined 
                    : Icons.bar_chart_outlined,
            size: 64,
            color: primaryColor.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '$_activeMenu 功能骨架',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '目前處於 Phase 1，此畫面為選單骨架頁面。\n後續 Phase 將逐步刻劃並串接資料庫實作。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white30 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

