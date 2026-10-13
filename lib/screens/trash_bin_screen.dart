import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/schedule_event.dart';
import '../services/app_settings.dart';
import '../services/schedule_service.dart';
import 'trash/trash_item_cards.dart';
import '../services/app_localizations.dart';
import '../widgets/custom_toast.dart';

enum TrashCategory {
  all(label: '全部項目', icon: Icons.all_inbox_rounded),
  customer(label: '正式客戶', icon: Icons.person_outline_rounded),
  draftCustomer(label: '語音草稿', icon: Icons.mic_none_rounded),
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
  List<Map<String, dynamic>> _deletedCustomers = [];
  List<ScheduleEvent> _deletedEvents = [];
  bool _isLoading = false;
  TrashCategory _activeCategory = TrashCategory.all;

  @override
  void initState() {
    super.initState();
    _fetchDeletedCustomers();
    _fetchDeletedEvents();
  }

  int get _totalCount => _deletedCustomers.length + _deletedEvents.length;

  // 讀取放進垃圾桶的行程（3-F）
  Future<void> _fetchDeletedEvents() async {
    try {
      final List<ScheduleEvent> deletedEvents = await ScheduleService.instance.fetchDeletedEvents();
      if (!mounted) return;
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
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      setState(() {
        _deletedCustomers = OfflineDataStore.customers
            .where((c) => c['deleted_at'] != null)
            .toList();
        _isLoading = false;
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      // Fetch only soft-deleted customers
      final response = await supabase
          .from('customers')
          .select()
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false);

      setState(() {
        _deletedCustomers = List<Map<String, dynamic>>.from(response.map((data) {
          return {
            'id': data['id'],
            'name': data['name'],
            'nickname': data['nickname'] ?? '',
            'avatar_url': data['avatar_url'] ?? '',
            'phone': data['phone'],
            'email': data['email'],
            'status': data['status'] ?? 'active',
            'tags': List<String>.from(data['tags'] ?? []),
            'notes': data['notes'],
            'created_at': data['created_at'],
            'deleted_at': data['deleted_at'],
          };
        }));
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '載入垃圾桶失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreCustomer(String id, bool isDraft) async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      final index = OfflineDataStore.customers.indexWhere((c) => c['id'] == id);
      if (index != -1) {
        OfflineDataStore.customers[index] = {
          ...OfflineDataStore.customers[index],
          'deleted_at': null,
        };
      }
      await _fetchDeletedCustomers();
      if (mounted) {
        CustomToast.show(context, isDraft ? '🎉 語音草稿已成功還原至收件匣！' : '🎉 客戶已成功還原至名冊！', ToastType.success);
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('customers').update({
        'deleted_at': null,
      }).eq('id', id);
      await _fetchDeletedCustomers();
      if (mounted) {
        CustomToast.show(context, isDraft ? '🎉 語音草稿已成功還原至收件匣！' : '🎉 客戶已成功還原至名冊！', ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '復原失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCustomerForever(String id) async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      OfflineDataStore.customers.removeWhere((c) => c['id'] == id);
      await _fetchDeletedCustomers();
      if (mounted) {
        CustomToast.show(context, '${context.l10n('trash_bin_delete_forever_success')} (離線暫存)', ToastType.success);
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      // Physical hard delete
      await supabase.from('customers').delete().eq('id', id);
      await _fetchDeletedCustomers();
      if (mounted) {
        CustomToast.show(context, context.l10n('trash_bin_delete_forever_success'), ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '徹底刪除失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDeleteForeverConfirm(String name, VoidCallback onConfirm) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
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
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: Text(context.l10n('trash_bin_delete_forever')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppSettings.instance.primaryColor;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF30363D) : Colors.grey.shade200;

    final TrashCardColors cardColors = TrashCardColors(
      cardBg: cardBg,
      borderColor: borderColor,
      textColor: textColor,
      subTextColor: subTextColor,
      primaryColor: primaryColor,
    );
    final List<Widget> displayedCards = _buildDisplayedCards(cardColors);

    final draftCount = _deletedCustomers.where((c) => DeletedCustomerCard.isDraftCustomer(c)).length;
    final activeCount = _deletedCustomers.length - draftCount;

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
                        '已刪除項目將保留 30 天，可依「正式客戶」「語音草稿」「行程與日曆」分類還原或永久刪除。',
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
                            final int count = _countForCategory(cat, activeCount, draftCount);

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: Icon(cat.icon, size: 14, color: isSelected ? Colors.white : primaryColor),
                                label: Text('${cat.label} ($count)', style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _activeCategory = cat),
                                selectedColor: primaryColor,
                                labelStyle: TextStyle(color: isSelected ? Colors.white : textColor),
                                checkmarkColor: Colors.white,
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
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '此分類目前無任何垃圾項目',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
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
  int _countForCategory(TrashCategory category, int activeCount, int draftCount) {
    switch (category) {
      case TrashCategory.all:
        return _totalCount;
      case TrashCategory.customer:
        return activeCount;
      case TrashCategory.draftCustomer:
        return draftCount;
      case TrashCategory.schedule:
        return _deletedEvents.length;
    }
  }

  // 依目前分類組出要顯示的卡片；「全部」時客戶與行程混在一起，最近刪除的排前面
  List<Widget> _buildDisplayedCards(TrashCardColors cardColors) {
    final List<MapEntry<DateTime, Widget>> entries = [];

    final bool showCustomers = _activeCategory != TrashCategory.schedule;
    if (showCustomers) {
      for (final Map<String, dynamic> customer in _deletedCustomers) {
        final bool isDraft = DeletedCustomerCard.isDraftCustomer(customer);
        if (_activeCategory == TrashCategory.customer && isDraft) continue;
        if (_activeCategory == TrashCategory.draftCustomer && !isDraft) continue;

        final String customerId = customer['id'].toString();
        final String customerName = customer['name'] as String? ?? '';
        final DateTime deletedAt = DateTime.tryParse(customer['deleted_at']?.toString() ?? '') ?? DateTime.now();
        entries.add(MapEntry(
          deletedAt,
          DeletedCustomerCard(
            customer: customer,
            colors: cardColors,
            onRestore: () => _restoreCustomer(customerId, isDraft),
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

    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries.map((entry) => entry.value).toList();
  }
}
