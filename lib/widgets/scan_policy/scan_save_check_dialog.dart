import 'package:flutter/material.dart';

import '../../services/policy_scan_service.dart';
import '../../theme/app_theme.dart';

/// 存入前還有沒處理的項目時，業務員的選擇
enum ScanSaveChoice { goBack, saveAsIs, applyAllAndSave }

/// 存入前檢查（2026-10-29 沛沛提出）：還有「可能是…」沒套用、補拍金額不同沒選時先提醒
///
/// 「全部套用」放在這個視窗裡並列出每一項「讀到的 → 建議的」，業務員至少會看過一次，
/// 不在畫面上放一按就全換的按鈕（建議偶爾會猜錯）。都處理好了回傳 saveAsIs，不跳視窗
Future<ScanSaveChoice> checkBeforeSave(BuildContext context, ScannedPolicy policy) async {
  final List<ScannedPolicyItem> suggestions = [];
  int conflictCount = 0;
  for (final ScannedPolicyItem item in policy.items) {
    if (!item.isInCatalog && item.suggestedProduct != null) suggestions.add(item);
    if (item.retakeAlternative != null) conflictCount++;
  }
  if (suggestions.isEmpty && conflictCount == 0) {
    return ScanSaveChoice.saveAsIs;
  }
  final ScanSaveChoice? choice = await showDialog<ScanSaveChoice>(
    context: context,
    builder: (BuildContext dialogContext) => _SaveCheckDialog(suggestions: suggestions, conflictCount: conflictCount),
  );
  return choice ?? ScanSaveChoice.goBack;
}

class _SaveCheckDialog extends StatelessWidget {
  final List<ScannedPolicyItem> suggestions;
  final int conflictCount;

  const _SaveCheckDialog({required this.suggestions, required this.conflictCount});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final int pendingCount = suggestions.length + conflictCount;
    final List<Widget> lines = [];
    if (suggestions.isNotEmpty) {
      lines.add(Text('可能讀錯字的商品（套用後才連得到商品資料、保單健檢）：', style: TextStyle(fontSize: 12, color: colors.ink2)));
      for (final ScannedPolicyItem item in suggestions) {
        lines.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: item.productName, style: TextStyle(fontSize: 12, color: colors.ink3)),
            TextSpan(text: '  →  ', style: TextStyle(fontSize: 12, color: colors.ink3)),
            TextSpan(
              text: item.suggestedProduct?.productName ?? '',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink),
            ),
          ])),
        ));
      }
    }
    if (conflictCount > 0) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('補拍金額或計畫不同：$conflictCount 項還沒選，存入會保留第一次讀到的', style: TextStyle(fontSize: 12, color: colors.warn)),
      ));
    }

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text('還有 $pendingCount 項沒處理', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: lines),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, ScanSaveChoice.goBack), child: const Text('回去逐項看')),
        TextButton(onPressed: () => Navigator.pop(context, ScanSaveChoice.saveAsIs), child: const Text('不套用，直接存')),
        if (suggestions.isNotEmpty)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ScanSaveChoice.applyAllAndSave),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.acc,
              foregroundColor: colors.onAcc,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            child: const Text('全部套用並存入'),
          ),
      ],
    );
  }
}
