import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 離線預覽模式時，登入頁最上方的提示列，附「直接跳過登入」按鈕
class LoginOfflineBanner extends StatelessWidget {
  final String reason;
  final VoidCallback onSkipLogin;

  const LoginOfflineBanner({super.key, required this.reason, required this.onSkipLogin});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Material(
      color: colors.warnSoft,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line))),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '離線預覽模式（$reason）',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.warn, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: onSkipLogin,
                child: const Text('直接跳過登入'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
