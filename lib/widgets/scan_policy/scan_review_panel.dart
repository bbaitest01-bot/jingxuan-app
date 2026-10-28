import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/policy_scan_service.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';
import '../customer_policy_widgets.dart';
import 'scan_review_items.dart';
import 'scan_save_check_dialog.dart';

/// 掃描保單第 ④ 步：確認／修正辨識結果，存入客戶保單
///
/// 2026-10-29 依組長意見改版（模型圖沛沛確認）：
/// 最上方一眼看結果（讀取完成／有 N 件事要確認）→ 保單資料卡 → 商品清單（只有有問題的才標黃）
/// → 業務員勾「已對照保單，共 N 項」才能存（AI 數錯總項數時不會提醒，人工確認最可靠，D19）
class ScanReviewPanel extends StatefulWidget {
  final String customerName;
  final ScannedPolicy policy;
  final String status;
  final bool isSaving;
  final ValueChanged<int> onEditItem;
  final ValueChanged<int> onRemoveItem;
  final ValueChanged<int> onApplySuggestion;
  final VoidCallback onAddItem;
  // 補拍漏掉的部分；「改用補拍的」（金額或計畫和第一次不同時）
  final VoidCallback onRetake;
  final ValueChanged<int> onUseRetakeValue;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onRescan;
  final VoidCallback onSave;

  const ScanReviewPanel({
    super.key,
    required this.customerName,
    required this.policy,
    required this.status,
    required this.isSaving,
    required this.onEditItem,
    required this.onRemoveItem,
    required this.onApplySuggestion,
    required this.onAddItem,
    required this.onRetake,
    required this.onUseRetakeValue,
    required this.onStatusChanged,
    required this.onRescan,
    required this.onSave,
  });

  @override
  State<ScanReviewPanel> createState() => _ScanReviewPanelState();
}

class _ScanReviewPanelState extends State<ScanReviewPanel> {
  // 勾選「已對照保單，共 N 項」；項數變了（補了、刪了）就要重新確認
  bool _isCountConfirmed = false;
  int _confirmedItemCount = 0;
  // 附約很多時先收起來（有問題的項目一律顯示）
  bool _isExpanded = false;
  static const int _collapsedVisibleCount = 4;

  ScannedPolicy get _policy => widget.policy;

  /// 要業務員確認的事；空的代表讀取完成、沒有可疑之處
  List<String> _issues() {
    final List<String> issues = [];
    if (_policy.missingItemCount > 0) {
      issues.add('保單上可能有 ${_policy.expectedItemCount} 項，只讀到 ${_policy.items.length} 項，請對照保單補上');
    }
    if (_policy.sentWholePhoto) {
      issues.add('這次是整張辨識，下面幾項比較容易漏，請核對項數');
    }
    int notInCatalogCount = 0;
    for (final ScannedPolicyItem item in _policy.items) {
      if (!item.isInCatalog) notInCatalogCount++;
    }
    if (notInCatalogCount > 0) {
      issues.add('$notInCatalogCount 項在商品目錄找不到，請核對名稱（仍會存入）');
    }
    int conflictCount = 0;
    for (final ScannedPolicyItem item in _policy.items) {
      if (item.retakeAlternative != null) conflictCount++;
    }
    if (conflictCount > 0) {
      issues.add('$conflictCount 項補拍讀到的金額或計畫不一樣，請選擇用哪一個');
    }
    return issues;
  }

  Future<void> _trySave() async {
    final bool countStillMatches = _confirmedItemCount == _policy.items.length;
    if (!_isCountConfirmed || !countStillMatches) {
      setState(() => _isCountConfirmed = false);
      CustomToast.show(context, '請先對照保單，勾選項數確認', ToastType.warning);
      return;
    }
    // 還有「可能是…」沒套用、補拍金額不同沒選：先問（全部套用會列出每一項怎麼換）
    final ScanSaveChoice choice = await checkBeforeSave(context, _policy);
    if (choice == ScanSaveChoice.goBack) return;
    if (choice == ScanSaveChoice.applyAllAndSave) {
      for (int index = 0; index < _policy.items.length; index++) {
        final ScannedPolicyItem item = _policy.items[index];
        if (!item.isInCatalog && item.suggestedProduct != null) {
          widget.onApplySuggestion(index);
        }
      }
    }
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final int itemCount = _policy.items.length;
    // 項數變了，之前的勾選就不算
    final bool isConfirmed = _isCountConfirmed && _confirmedItemCount == itemCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultBanner(issues: _issues(), itemCount: itemCount),
        const SizedBox(height: 12),
        _PolicyInfoCard(
          customerName: widget.customerName,
          policy: _policy,
          status: widget.status,
          onStatusChanged: widget.onStatusChanged,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text('讀到 $itemCount 項商品', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink)),
            ),
            Text('點一項可修改或刪除', style: TextStyle(fontSize: 11, color: colors.ink3)),
          ],
        ),
        const SizedBox(height: 8),
        ScanReviewItemList(
          items: _policy.items,
          isExpanded: _isExpanded,
          collapsedVisibleCount: _collapsedVisibleCount,
          onToggleExpanded: () => setState(() => _isExpanded = !_isExpanded),
          onEditItem: widget.onEditItem,
          onApplySuggestion: widget.onApplySuggestion,
          onUseRetakeValue: widget.onUseRetakeValue,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _SecondaryButton(icon: Icons.add_rounded, label: '手動補一項', onPressed: widget.onAddItem)),
            const SizedBox(width: 8),
            Expanded(child: _SecondaryButton(icon: Icons.photo_camera_outlined, label: '補拍漏掉的', onPressed: widget.onRetake)),
          ],
        ),
        const SizedBox(height: 16),
        _CountConfirmBox(
          itemCount: itemCount,
          isConfirmed: isConfirmed,
          onChanged: (bool value) => setState(() {
            _isCountConfirmed = value;
            _confirmedItemCount = itemCount;
          }),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: widget.isSaving || itemCount == 0 ? null : _trySave,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.acc,
            foregroundColor: colors.onAcc,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: Text(widget.isSaving ? '存入中…' : '存入客戶保單（$itemCount 項）'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: widget.isSaving ? null : widget.onRescan,
          child: Text('重新拍整張', style: TextStyle(fontSize: 12, color: colors.ink3)),
        ),
      ],
    );
  }
}

/// 清單下方的次要按鈕（手動補一項、補拍漏掉的）
class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.ink2,
        side: BorderSide(color: colors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
    );
  }
}

/// 最上方的結果：沒有問題是綠色「讀取完成」；有問題是黃色「有 N 件事要確認」並列出原因
class _ResultBanner extends StatelessWidget {
  final List<String> issues;
  final int itemCount;

  const _ResultBanner({required this.issues, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool hasIssues = issues.isNotEmpty;
    Color backgroundColor = colors.okSoft;
    Color textColor = colors.ok;
    IconData icon = Icons.check_circle_outline_rounded;
    String title = '讀取完成';
    List<String> lines = ['$itemCount 項都對到商品目錄，對照保單確認項數後就能存入'];
    if (hasIssues) {
      backgroundColor = colors.warnSoft;
      textColor = colors.warn;
      icon = Icons.warning_amber_rounded;
      title = '有 ${issues.length} 件事要確認';
      lines = issues;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 4),
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(line, style: TextStyle(fontSize: 12, color: textColor)),
            ),
        ],
      ),
    );
  }
}

/// 保單資料卡：公司、保單號碼、生效日、客戶，以及有效／已失效
class _PolicyInfoCard extends StatelessWidget {
  final String customerName;
  final ScannedPolicy policy;
  final String status;
  final ValueChanged<String> onStatusChanged;

  const _PolicyInfoCard({
    required this.customerName,
    required this.policy,
    required this.status,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String companyName = PolicyScanService.companyShortNames[policy.companyCode] ?? policy.companyName ?? '';
    if (companyName.isEmpty) {
      companyName = '保險公司未讀到';
    }
    final String policyNumber = policy.policyNumber ?? '';
    String effectiveDateText = '未讀到';
    final DateTime? effectiveDate = policy.effectiveDate;
    if (effectiveDate != null) {
      effectiveDateText = DateFormat('yyyy/MM/dd').format(effectiveDate);
    }
    final TextStyle labelStyle = TextStyle(fontSize: 12, color: colors.ink3);
    final TextStyle valueStyle = AppTextStyles.mono(fontSize: 12, color: colors.ink2);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(companyName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink)),
          const SizedBox(height: 4),
          Text.rich(TextSpan(children: [
            TextSpan(text: '保單號碼　', style: labelStyle),
            TextSpan(text: policyNumber.isEmpty ? '未讀到（可之後補）' : policyNumber, style: valueStyle),
          ])),
          Text.rich(TextSpan(children: [
            TextSpan(text: '生效日　', style: labelStyle),
            TextSpan(text: effectiveDateText, style: valueStyle),
            TextSpan(text: '　客戶　', style: labelStyle),
            TextSpan(text: customerName, style: TextStyle(fontSize: 12, color: colors.ink2)),
          ])),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('這張保單目前', style: TextStyle(fontSize: 12, color: colors.ink2)),
              const SizedBox(width: 8),
              PolicyStatusSelector(status: status, onChanged: onStatusChanged),
            ],
          ),
        ],
      ),
    );
  }
}

/// 存入前的確認：業務員對照紙本保單，勾「共 N 項，和上面一樣」
class _CountConfirmBox extends StatelessWidget {
  final int itemCount;
  final bool isConfirmed;
  final ValueChanged<bool> onChanged;

  const _CountConfirmBox({required this.itemCount, required this.isConfirmed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return InkWell(
      onTap: () => onChanged(!isConfirmed),
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: isConfirmed ? colors.ok : colors.line),
        ),
        child: Row(
          children: [
            Checkbox(value: isConfirmed, onChanged: (bool? value) => onChanged(value ?? false), activeColor: colors.ok),
            Expanded(
              child: Text('我已對照保單，保單上共 $itemCount 項，和上面一樣', style: TextStyle(fontSize: 13, color: colors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 保費文字：新臺幣「保費 12,350 元」；外幣「保費 USD 4,215」
String formatPremiumText(int premium, String? currency) {
  final String amount = NumberFormat('#,###').format(premium);
  final String code = currency ?? 'TWD';
  if (code == 'TWD') {
    return '保費 $amount 元';
  }
  return '保費 $code $amount';
}
