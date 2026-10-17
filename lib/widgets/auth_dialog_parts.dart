import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 忘記密碼、重設密碼視窗共用的小零件（標題列、錯誤框、按鈕轉圈）

/// 視窗標題列：左邊圖示（主題色淡底）、中間宋體標題、右邊關閉
class AuthDialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const AuthDialogHeader({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.accSoft,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(icon, color: colors.acc, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: AppTextStyles.serif(fontSize: 18, color: colors.ink)),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.ink3, size: 20),
          tooltip: '關閉',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// 紅色錯誤提示框（危險色淡底＋危險色字）
class AuthErrorBox extends StatelessWidget {
  final String message;

  const AuthErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Text(message, style: TextStyle(color: colorScheme.error, fontSize: 12)),
    );
  }
}

/// 主要按鈕「處理中」時顯示的小轉圈
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.onAcc),
    );
  }
}
