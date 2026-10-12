import 'package:flutter/material.dart';

/// 離線預覽模式時，登入頁最上方的橘色橫幅，附「直接跳過登入」按鈕
class LoginOfflineBanner extends StatelessWidget {
  final String reason;
  final VoidCallback onSkipLogin;

  const LoginOfflineBanner({super.key, required this.reason, required this.onSkipLogin});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.amber.shade900.withValues(alpha: 0.95),
      child: SafeArea(
        bottom: false,
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '⚠️ 離線預覽模式已啟用 ($reason)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onSkipLogin,
                child: const Text(
                  '直接跳過登入',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
