import 'package:flutter/material.dart';

import '../../services/policy_scan_service.dart';
import '../../theme/app_theme.dart';

/// 存入前發現「這位客戶已經存過同一個保單號碼」時的提醒（2026-10-24 沛沛：提醒就好，不擋）
/// 回傳 true 代表業務員選「仍要存入」
Future<bool> showScanDuplicateDialog(
  BuildContext context, {
  required String customerName,
  required String policyNumber,
  required ExistingPolicyInfo existingPolicy,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final AppColors colors = dialogContext.appColors;
      String savedDateText = '';
      final DateTime? savedAt = existingPolicy.firstSavedAt;
      if (savedAt != null) {
        savedDateText = '，${savedAt.month}/${savedAt.day} 存入';
      }
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text('這份保單可能已經存過', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
        content: SizedBox(
          width: 400,
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 13, height: 1.6, color: colors.ink2),
              children: [
                TextSpan(text: '$customerName 已經有保單號碼 '),
                TextSpan(text: policyNumber, style: TextStyle(fontWeight: FontWeight.bold, color: colors.ink)),
                TextSpan(text: ' 的保單（${existingPolicy.itemCount} 項$savedDateText）。要再存一次嗎？'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.acc,
              foregroundColor: colors.onAcc,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            child: const Text('仍要存入'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
