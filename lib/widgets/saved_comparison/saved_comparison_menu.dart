import 'package:flutter/material.dart';

import '../../models/saved_comparison.dart';
import '../../services/saved_comparison_service.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';
import 'saved_comparison_name_dialog.dart';
import 'saved_comparison_opener.dart';

/// 客戶卡片右上角的「比較清單 N」（D36）：有存過比較才出現，點開是浮在畫面上的選單，不會拉長卡片
class SavedComparisonMenuButton extends StatefulWidget {
  final String customerId;
  final String customerName;
  // 列表檢視比較擠，字縮短成「比較 N」
  final bool isCompact;
  // 以下四個測試時換成假的，不用連資料庫
  final Future<List<SavedComparison>> Function(String customerId)? fetchComparisons;
  final Future<void> Function(BuildContext context, SavedComparison comparison)? openComparison;
  final Future<void> Function(String comparisonId, String newName)? renameComparison;
  final Future<void> Function(String comparisonId)? deleteComparison;

  const SavedComparisonMenuButton({
    super.key,
    required this.customerId,
    required this.customerName,
    this.isCompact = false,
    this.fetchComparisons,
    this.openComparison,
    this.renameComparison,
    this.deleteComparison,
  });

  @override
  State<SavedComparisonMenuButton> createState() => _SavedComparisonMenuButtonState();
}

class _SavedComparisonMenuButtonState extends State<SavedComparisonMenuButton> {
  /// 畫面比這個窄就用下方面板，寬的用浮動選單
  static const double _bottomSheetBelowWidth = 600;

  final MenuController _menuController = MenuController();

  Future<List<SavedComparison>> _loadComparisons() {
    final Future<List<SavedComparison>> Function(String customerId) fetchComparisons =
        widget.fetchComparisons ?? SavedComparisonService.instance.fetchForCustomer;
    return fetchComparisons(widget.customerId);
  }

  Future<void> _open(SavedComparison comparison) async {
    _menuController.close();
    final Future<void> Function(BuildContext context, SavedComparison comparison)? openComparison = widget.openComparison;
    if (openComparison != null) {
      await openComparison(context, comparison);
      return;
    }
    await openSavedComparison(context, comparison, widget.customerName);
  }

  Future<void> _rename(SavedComparison comparison) async {
    _menuController.close();
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SavedComparisonNameDialog(title: '改名', confirmLabel: '儲存', initialName: comparison.name);
      },
    );
    if (newName == null || newName.trim() == comparison.name || !mounted) return;
    try {
      final Future<void> Function(String comparisonId, String newName)? renameComparison = widget.renameComparison;
      if (renameComparison != null) {
        await renameComparison(comparison.id, newName);
      } else {
        await SavedComparisonService.instance.rename(comparisonId: comparison.id, newName: newName);
      }
      if (!mounted) return;
      CustomToast.show(context, '名稱已更新', ToastType.success);
    } on SavedComparisonException catch (error) {
      if (!mounted) return;
      CustomToast.show(context, error.message, ToastType.warning);
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(context, '改名失敗，請再試一次', ToastType.error);
    }
  }

  Future<bool> _confirmDelete(SavedComparison comparison) async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          title: const Text('刪除這筆比較？'),
          content: Text('「${comparison.name}」刪除後無法復原。'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('取消')),
            FilledButton(
              style: AppButtonStyles.danger(dialogContext),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    return isConfirmed ?? false;
  }

  Future<void> _delete(SavedComparison comparison) async {
    _menuController.close();
    final bool isConfirmed = await _confirmDelete(comparison);
    if (!isConfirmed || !mounted) return;
    try {
      final Future<void> Function(String comparisonId)? deleteComparison = widget.deleteComparison;
      if (deleteComparison != null) {
        await deleteComparison(comparison.id);
      } else {
        await SavedComparisonService.instance.delete(comparison.id);
      }
      if (!mounted) return;
      CustomToast.show(context, '已刪除「${comparison.name}」', ToastType.success);
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(context, '刪除失敗，請再試一次', ToastType.error);
    }
  }

  /// 手機：從下方滑出的面板，列比較高、手指比較好按（2026-11-10 沛沛確認）
  Future<void> _showBottomSheet() async {
    final AppColors colors = context.appColors;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (BuildContext sheetContext) {
        // 選了之後先收起面板，再做打開、改名或刪除
        ValueChanged<SavedComparison> closeSheetThen(ValueChanged<SavedComparison> action) {
          return (SavedComparison comparison) {
            Navigator.of(sheetContext).pop();
            action(comparison);
          };
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '${widget.customerName} 的比較清單',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink),
                ),
              ),
              Divider(height: 1, color: colors.line),
              Flexible(
                child: _ComparisonMenuList(
                  loadComparisons: _loadComparisons,
                  onOpen: closeSheetThen(_open),
                  onRename: closeSheetThen(_rename),
                  onDelete: closeSheetThen(_delete),
                  isBottomSheet: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleMenu() {
    if (MediaQuery.sizeOf(context).width < _bottomSheetBelowWidth) {
      _showBottomSheet();
      return;
    }
    if (_menuController.isOpen) {
      _menuController.close();
    } else {
      _menuController.open();
    }
  }

  Widget _buildMenuButton(BuildContext context, int count) {
    final AppColors colors = context.appColors;
    String label = '比較清單 $count';
    if (widget.isCompact) {
      label = '比較 $count';
    }
    return Material(
      color: colors.accSoft,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: _toggleMenu,
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 6, top: 5, bottom: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.acc)),
              Icon(Icons.expand_more_rounded, size: 16, color: colors.acc),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: SavedComparisonService.instance.countByCustomer,
      builder: (BuildContext context, Map<String, int> countByCustomer, Widget? child) {
        final int count = countByCustomer[widget.customerId] ?? 0;
        if (count == 0) {
          return const SizedBox.shrink();
        }
        return MenuAnchor(
          controller: _menuController,
          alignmentOffset: const Offset(0, 4),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll<Color>(colors.surface),
            surfaceTintColor: WidgetStatePropertyAll<Color>(colors.surface),
            elevation: const WidgetStatePropertyAll<double>(10),
            padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
            shape: WidgetStatePropertyAll<OutlinedBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                side: BorderSide(color: colors.line),
              ),
            ),
          ),
          // 選單打開時才建立，所以每次打開都讀到最新內容
          menuChildren: [
            _ComparisonMenuList(
              loadComparisons: _loadComparisons,
              onOpen: _open,
              onRename: _rename,
              onDelete: _delete,
            ),
          ],
          builder: (BuildContext context, MenuController controller, Widget? child) {
            return _buildMenuButton(context, count);
          },
        );
      },
    );
  }
}

/// 選單內容：讀這位客戶的比較，一筆一列
class _ComparisonMenuList extends StatefulWidget {
  /// 選單寬度；高度放得下約 5 筆，再多就在選單裡捲動
  static const double menuWidth = 270;
  static const double menuMaximumHeight = 296;

  final Future<List<SavedComparison>> Function() loadComparisons;
  final ValueChanged<SavedComparison> onOpen;
  final ValueChanged<SavedComparison> onRename;
  final ValueChanged<SavedComparison> onDelete;
  final bool isBottomSheet;

  const _ComparisonMenuList({
    required this.loadComparisons,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    this.isBottomSheet = false,
  });

  @override
  State<_ComparisonMenuList> createState() => _ComparisonMenuListState();
}

class _ComparisonMenuListState extends State<_ComparisonMenuList> {
  List<SavedComparison>? _comparisons;
  bool _didLoadFail = false;
  // 正在顯示「改名／刪除」的那一列
  String? _comparisonIdShowingActions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<SavedComparison> comparisons = await widget.loadComparisons();
      if (!mounted) return;
      setState(() => _comparisons = comparisons);
    } catch (error) {
      if (!mounted) return;
      setState(() => _didLoadFail = true);
    }
  }

  void _toggleActions(String comparisonId) {
    setState(() {
      if (_comparisonIdShowingActions == comparisonId) {
        _comparisonIdShowingActions = null;
      } else {
        _comparisonIdShowingActions = comparisonId;
      }
    });
  }

  Widget _buildMessage(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: TextStyle(fontSize: 12, color: context.appColors.ink3)),
    );
  }

  Widget _buildContent() {
    if (_didLoadFail) {
      return _buildMessage('讀不到比較清單，請再試一次');
    }
    final List<SavedComparison>? comparisons = _comparisons;
    if (comparisons == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (comparisons.isEmpty) {
      return _buildMessage('這位客戶還沒有存比較');
    }
    final List<Widget> rows = [];
    for (final SavedComparison comparison in comparisons) {
      if (rows.isNotEmpty) {
        rows.add(Divider(height: 1, color: context.appColors.line));
      }
      rows.add(_ComparisonMenuRow(
        comparison: comparison,
        isShowingActions: _comparisonIdShowingActions == comparison.id,
        isBottomSheet: widget.isBottomSheet,
        onOpen: () => widget.onOpen(comparison),
        onToggleActions: () => _toggleActions(comparison.id),
        onRename: () => widget.onRename(comparison),
        onDelete: () => widget.onDelete(comparison),
      ));
    }
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isBottomSheet) {
      // 面板寬度跟著螢幕；高度最多半個螢幕多一點，再多就捲動
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: _buildContent(),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _ComparisonMenuList.menuWidth,
        maxWidth: _ComparisonMenuList.menuWidth,
        maxHeight: _ComparisonMenuList.menuMaximumHeight,
      ),
      child: _buildContent(),
    );
  }
}

/// 選單的一列：點名稱打開比較，點「⋯」換出改名、刪除
class _ComparisonMenuRow extends StatelessWidget {
  final SavedComparison comparison;
  final bool isShowingActions;
  final bool isBottomSheet;
  final VoidCallback onOpen;
  final VoidCallback onToggleActions;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ComparisonMenuRow({
    required this.comparison,
    required this.isShowingActions,
    required this.isBottomSheet,
    required this.onOpen,
    required this.onToggleActions,
    required this.onRename,
    required this.onDelete,
  });

  String _detailText() {
    final DateTime savedAt = comparison.updatedAt.toLocal();
    final String month = savedAt.month.toString().padLeft(2, '0');
    final String day = savedAt.day.toString().padLeft(2, '0');
    return '${comparison.items.length} 款・$month/$day 存';
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    // 手機面板的列高一點，手指比較好按
    double rowVerticalPadding = 8;
    double rowLeftPadding = 12;
    if (isBottomSheet) {
      rowVerticalPadding = 12;
      rowLeftPadding = 16;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onOpen,
          child: Padding(
            padding: EdgeInsets.only(left: rowLeftPadding, right: 4, top: rowVerticalPadding, bottom: rowVerticalPadding),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comparison.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(_detailText(), style: AppTextStyles.mono(fontSize: 11, color: colors.ink3)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '改名或刪除',
                  icon: Icon(Icons.more_horiz_rounded, size: 18, color: colors.ink3),
                  onPressed: onToggleActions,
                ),
              ],
            ),
          ),
        ),
        if (isShowingActions)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onRename, child: const Text('改名')),
                TextButton(style: AppButtonStyles.dangerText(context), onPressed: onDelete, child: const Text('刪除')),
              ],
            ),
          ),
      ],
    );
  }
}
