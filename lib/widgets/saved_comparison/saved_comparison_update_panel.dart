import 'package:flutter/material.dart';

import '../../models/saved_comparison.dart';
import '../../services/saved_comparison_service.dart';
import '../../services/scenario/claim_scenario.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';
import 'saved_comparison_name_dialog.dart';

/// 真正更新資料庫的動作；測試時可以換成假的
typedef UpdateComparisonAction = Future<void> Function(
  String comparisonId,
  ClaimScenarioInput scenario,
  List<SavedComparisonItem> items,
);

/// 真正另存一筆的動作；測試時可以換成假的
typedef SaveAsNewComparisonAction = Future<SavedComparison> Function(
  String customerId,
  String name,
  ClaimScenarioInput scenario,
  List<SavedComparisonItem> items,
);

/// 從客戶比較清單打開時，存檔框變成「更新這筆／另存新的」（D36）
class SavedComparisonUpdatePanel extends StatefulWidget {
  final SavedComparison comparison;
  final String customerName;
  final ClaimScenarioInput Function() currentScenario;
  final List<SavedComparisonItem> Function() currentItems;
  final ValueChanged<SavedComparison> onSavedAsNew;
  final UpdateComparisonAction? updateComparison;
  final SaveAsNewComparisonAction? saveAsNewComparison;

  const SavedComparisonUpdatePanel({
    super.key,
    required this.comparison,
    required this.customerName,
    required this.currentScenario,
    required this.currentItems,
    required this.onSavedAsNew,
    this.updateComparison,
    this.saveAsNewComparison,
  });

  @override
  State<SavedComparisonUpdatePanel> createState() => _SavedComparisonUpdatePanelState();
}

class _SavedComparisonUpdatePanelState extends State<SavedComparisonUpdatePanel> {
  bool _isSaving = false;

  Future<void> _updateInService(
    String comparisonId,
    ClaimScenarioInput scenario,
    List<SavedComparisonItem> items,
  ) async {
    await SavedComparisonService.instance.updateContent(
      comparisonId: comparisonId,
      scenario: scenario,
      items: items,
    );
  }

  Future<SavedComparison> _saveAsNewInService(
    String customerId,
    String name,
    ClaimScenarioInput scenario,
    List<SavedComparisonItem> items,
  ) {
    return SavedComparisonService.instance.create(
      customerId: customerId,
      name: name,
      scenario: scenario,
      items: items,
    );
  }

  /// 存檔共用的流程：鎖住按鈕、把錯誤轉成提示
  Future<void> _runSave(Future<void> Function() save) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await save();
    } on SavedComparisonException catch (error) {
      if (!mounted) return;
      CustomToast.show(context, error.message, ToastType.warning);
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(context, '存檔失敗，請再試一次', ToastType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateThisComparison() async {
    final UpdateComparisonAction updateComparison = widget.updateComparison ?? _updateInService;
    await _runSave(() async {
      await updateComparison(widget.comparison.id, widget.currentScenario(), widget.currentItems());
      if (!mounted) return;
      CustomToast.show(context, '已更新「${widget.comparison.name}」', ToastType.success);
    });
  }

  Future<void> _saveAsNew() async {
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return const SavedComparisonNameDialog(title: '另存新的比較', confirmLabel: '另存');
      },
    );
    if (newName == null || !mounted) return;
    final SaveAsNewComparisonAction saveAsNewComparison = widget.saveAsNewComparison ?? _saveAsNewInService;
    await _runSave(() async {
      final String normalizedName = SavedComparisonService.normalizeName(newName);
      final SavedComparison newComparison = await saveAsNewComparison(
        widget.comparison.customerId,
        normalizedName,
        widget.currentScenario(),
        widget.currentItems(),
      );
      if (!mounted) return;
      widget.onSavedAsNew(newComparison);
      CustomToast.show(context, '已另存為「$normalizedName」', ToastType.success);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.customerName} 的比較', style: TextStyle(fontSize: 11, color: colors.ink3)),
          const SizedBox(height: 2),
          Text(widget.comparison.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: _isSaving ? null : _updateThisComparison, child: const Text('更新這筆')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(onPressed: _isSaving ? null : _saveAsNew, child: const Text('另存新的')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('金額會依目前的條款資料重新計算', style: TextStyle(fontSize: 11, color: colors.ink3)),
        ],
      ),
    );
  }
}
