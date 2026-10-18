import 'package:flutter/material.dart';
import '../models/schedule_event.dart';
import '../models/visit_record.dart';
import '../services/customer_trash_service.dart';
import '../services/schedule_service.dart';
import '../services/visit_record_service.dart';
import 'trash/trash_item_cards.dart';
import '../services/app_localizations.dart';
import '../widgets/custom_toast.dart';
import '../theme/app_theme.dart';

enum TrashCategory {
  all(label: '全部項目', icon: Icons.all_inbox_rounded),
  customer(label: '正式客戶', icon: Icons.person_outline_rounded),
  // 原本的「語音草稿」沒有來源（線上客戶表沒有草稿狀態，問題 C12），4-D 改成拜訪紀錄
  visitRecord(label: '拜訪紀錄', icon: Icons.record_voice_over_outlined),
  schedule(label: '行程與日曆', icon: Icons.event_busy_rounded);

  final String label;
  final IconData icon;
  const TrashCategory({required this.label, required this.icon});
}

class TrashBinScreen extends StatefulWidget {
  const TrashBinScreen({super.key});

  @override
  State<TrashBinScreen> createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends State<TrashBinScreen> {
  // 上次讀到的垃圾桶內容（2026-10-19）：切頁回來時先顯示這份，不會每次都轉圈圈、閃一下；
  // 背景照樣重讀。記住是哪個帳號的，換人登入時不會看到上一位的資料
  static String? _cacheOwnerId;
  static List<Map<String, dynamic>>? _cachedCustomers;
  static List<ScheduleEvent>? _cachedEvents;
  static List<VisitRecord>? _cachedVisitRecords;

  List<Map<String, dynamic>> _deletedCustomers = [];
  List<ScheduleEvent> _deletedEvents = [];
  List<VisitRecord> _deletedVisitRecords = [];
  bool _isLoading = false;
  TrashCategory _activeCategory = TrashCategory.all;

  // 目前帳號（離線預覽沒有帳號，用固定字串）
  String get _ownerId => ScheduleService.instance.currentUserId ?? 'offline';

  @override
  void initState() {
    super.initState();
    if (_cacheOwnerId == _ownerId) {
      _deletedCustomers = _cachedCustomers ?? [];
      _deletedEvents = _cachedEvents ?? [];
      _deletedVisitRecords = _cachedVisitRecords ?? [];
    } else {
      _cacheOwnerId = _ownerId;
      _cachedCustomers = null;
      _cachedEvents = null;
      _cachedVisitRecords = null;
    }
    _fetchDeletedCustomers();
    _fetchDeletedEvents();
    _fetchDeletedVisitRecords();
  }

  int get _totalCount => _deletedCustomers.length + _deletedEvents.length + _deletedVisitRecords.length;

  // 讀取放進垃圾桶的拜訪紀錄（4-D）
  Future<void> _fetchDeletedVisitRecords() async {
    try {
      final List<VisitRecord> records = await VisitRecordService.instance.fetchDeletedRecords();
      if (!mounted) return;
      _cachedVisitRecords = records;
      setState(() => _deletedVisitRecords = records);
    } catch (e) {
      if (mounted) CustomToast.show(context, '載入垃圾桶拜訪紀錄失敗: $e', ToastType.error);
    }
  }

  Future<void> _restoreVisitRecord(VisitRecord record) async {
    try {
      await VisitRecordService.instance.restoreRecord(record.id);
      await _fetchDeletedVisitRecords();
      if (mounted) CustomToast.show(context, '🎉 拜訪紀錄「${record.title}」已還原', ToastType.success);
    } catch (e) {
      if (mounted) CustomToast.show(context, '還原拜訪紀錄失敗: $e', ToastType.error);
    }
  }

  Future<void> _deleteVisitRecordForever(VisitRecord record) async {
    try {
      await VisitRecordService.instance.deleteRecordForever(record.id);
      await _fetchDeletedVisitRecords();
      if (mounted) CustomToast.show(context, context.l10n('trash_bin_delete_forever_success'), ToastType.success);
    } catch (e) {
      if (mounted) CustomToast.show(context, '永久刪除拜訪紀錄失敗: $e', ToastType.error);
    }
  }

  // 讀取放進垃圾桶的行程（3-F）
  Future<void> _fetchDeletedEvents() async {
    try {
      final List<ScheduleEvent> deletedEvents = await ScheduleService.instance.fetchDeletedEvents();
      if (!mounted) return;
      _cachedEvents = deletedEvents;
      setState(() => _deletedEvents = deletedEvents);
    } catch (e) {
      if (mounted) CustomToast.show(context, '載入垃圾桶行程失敗: $e', ToastType.error);
    }
  }

  Future<void> _restoreEvent(ScheduleEvent event) async {
    try {
      await ScheduleService.instance.restoreEvent(event.id);
      await _fetchDeletedEvents();
      if (mounted) CustomToast.show(context, '🎉 行程「${event.title}」已還原', ToastType.success);
    } catch (e) {
      if (mounted) CustomToast.show(context, '還原行程失敗: $e', ToastType.error);
    }
  }

  Future<void> _deleteEventForever(ScheduleEvent event) async {
    try {
      await ScheduleService.instance.deleteEventForever(event.id);
      await _fetchDeletedEvents();
      if (mounted) CustomToast.show(context, context.l10n('trash_bin_delete_forever_success'), ToastType.success);
    } catch (e) {
      if (mounted) CustomToast.show(context, '永久刪除行程失敗: $e', ToastType.error);
    }
  }

  Future<void> _fetchDeletedCustomers() async {
    // 已經有上次的資料就不轉圈圈，背景更新
    if (_cachedCustomers == null) setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> customers = await CustomerTrashService.instance.fetchDeletedCustomers();
      if (!mounted) return;
      _cachedCustomers = customers;
      setState(() {
        _deletedCustomers = customers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomToast.show(context, '載入垃圾桶失敗: $e', ToastType.error);
    }
  }

  Future<void> _restoreCustomer(String id) async {
    try {
      await CustomerTrashService.instance.restoreCustomer(id);
      await _fetchDeletedCustomers();
      if (mounted) CustomToast.show(context, '🎉 客戶已成功還原至名冊！', ToastType.success);
    } catch (e) {
      if (mounted) CustomToast.show(context, '復原失敗: $e', ToastType.error);
    }
  }

  Future<void> _deleteCustomerForever(String id) async {
    try {
      await CustomerTrashService.instance.deleteCustomerForever(id);
      await _fetchDeletedCustomers();
      if (mounted) CustomToast.show(context, context.l10n('trash_bin_delete_forever_success'), ToastType.success);
    } catch (e) {
      if (mounted) CustomToast.show(context, '徹底刪除失敗: $e', ToastType.error);
    }
  }

  void _showDeleteForeverConfirm(String name, VoidCallback onConfirm) {
    final textColor = context.appColors.ink;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: context.appColors.surface,
          title: Text(
            context.l10n('trash_bin_confirm_delete_forever_title'),
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          content: Text(
            '確定要永久刪除「$name」嗎？此動作將自資料庫徹底銷毀，無法復原！',
            style: TextStyle(color: textColor.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.l10n('cancel'),
                style: TextStyle(color: context.appColors.ink3),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: AppButtonStyles.danger(context),
              child: Text(context.l10n('trash_bin_delete_forever')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = context.appColors.acc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = context.appColors.ink;
    final subTextColor = context.appColors.ink3;
    final cardBg = context.appColors.surface;
    final borderColor = context.appColors.line;

    final TrashCardColors cardColors = TrashCardColors(
      cardBg: cardBg,
      borderColor: borderColor,
      textColor: textColor,
      subTextColor: subTextColor,
      primaryColor: primaryColor,
    );
    final List<Widget> displayedCards = _buildDisplayedCards(cardColors);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading && _deletedCustomers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(Icons.delete_sweep_outlined, color: primaryColor, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            context.l10n('trash_bin'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_totalCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primaryColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                _totalCount.toString(),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '已刪除項目將保留 30 天，可依「正式客戶」「拜訪紀錄」「行程與日曆」分類還原或永久刪除。',
                        style: TextStyle(
                          fontSize: 13,
                          color: subTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🏷️ 可擴展分類 Filter Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: TrashCategory.values.map((cat) {
                            final isSelected = _activeCategory == cat;
                            final int count = _countForCategory(cat);

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: Icon(cat.icon, size: 14, color: isSelected ? context.appColors.onAcc : primaryColor),
                                label: Text('${cat.label} ($count)', style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _activeCategory = cat),
                                selectedColor: primaryColor,
                                labelStyle: TextStyle(color: isSelected ? context.appColors.onAcc : textColor),
                                checkmarkColor: context.appColors.onAcc,
                                backgroundColor: cardBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: isSelected ? primaryColor : borderColor),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // List / Grid
                      Expanded(
                        child: displayedCards.isEmpty
                            ? _buildEmptyState(isDark, subTextColor)
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  int crossAxisCount = 1;
                                  if (constraints.maxWidth >= 900) {
                                    crossAxisCount = 3;
                                  } else if (constraints.maxWidth >= 600) {
                                    crossAxisCount = 2;
                                  }

                                  return GridView.builder(
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      mainAxisExtent: 220,
                                    ),
                                    itemCount: displayedCards.length,
                                    itemBuilder: (context, index) => displayedCards[index],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline_rounded,
            size: 80,
            color: context.appColors.line,
          ),
          const SizedBox(height: 16),
          Text(
            '此分類目前無任何垃圾項目',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.appColors.ink3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '所有被刪除或捨棄的檔案將在此妥善保存 30 天。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: subTextColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // 每個分類標籤上顯示的筆數
  int _countForCategory(TrashCategory category) {
    switch (category) {
      case TrashCategory.all:
        return _totalCount;
      case TrashCategory.customer:
        return _deletedCustomers.length;
      case TrashCategory.visitRecord:
        return _deletedVisitRecords.length;
      case TrashCategory.schedule:
        return _deletedEvents.length;
    }
  }

  // 依目前分類組出要顯示的卡片；「全部」時客戶與行程混在一起，最近刪除的排前面
  List<Widget> _buildDisplayedCards(TrashCardColors cardColors) {
    final List<MapEntry<DateTime, Widget>> entries = [];

    final bool showCustomers = _activeCategory == TrashCategory.all || _activeCategory == TrashCategory.customer;
    if (showCustomers) {
      for (final Map<String, dynamic> customer in _deletedCustomers) {
        final String customerId = customer['id'].toString();
        final String customerName = customer['name'] as String? ?? '';
        final DateTime deletedAt = DateTime.tryParse(customer['deleted_at']?.toString() ?? '') ?? DateTime.now();
        entries.add(MapEntry(
          deletedAt,
          DeletedCustomerCard(
            customer: customer,
            colors: cardColors,
            onRestore: () => _restoreCustomer(customerId),
            onDeleteForever: () => _showDeleteForeverConfirm(customerName, () => _deleteCustomerForever(customerId)),
          ),
        ));
      }
    }

    final bool showEvents = _activeCategory == TrashCategory.all || _activeCategory == TrashCategory.schedule;
    if (showEvents) {
      for (final ScheduleEvent event in _deletedEvents) {
        entries.add(MapEntry(
          event.deletedAt ?? DateTime.now(),
          DeletedScheduleCard(
            event: event,
            colors: cardColors,
            onRestore: () => _restoreEvent(event),
            onDeleteForever: () => _showDeleteForeverConfirm(event.title, () => _deleteEventForever(event)),
          ),
        ));
      }
    }

    final bool showVisitRecords = _activeCategory == TrashCategory.all || _activeCategory == TrashCategory.visitRecord;
    if (showVisitRecords) {
      for (final VisitRecord record in _deletedVisitRecords) {
        entries.add(MapEntry(
          record.deletedAt ?? DateTime.now(),
          DeletedVisitRecordCard(
            record: record,
            colors: cardColors,
            onRestore: () => _restoreVisitRecord(record),
            onDeleteForever: () => _showDeleteForeverConfirm(record.title, () => _deleteVisitRecordForever(record)),
          ),
        ));
      }
    }

    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries.map((entry) => entry.value).toList();
  }
}
