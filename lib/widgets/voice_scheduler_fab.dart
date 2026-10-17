import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 今日行程右下角的「語音排程」麥克風按鈕：主題色圓形按鈕，明亮、深色都一樣。
/// （2026-10-18 UI 改版：拿掉深色模式的呼吸光暈，改成乾淨的實心按鈕）
class VoiceSchedulerFab extends StatelessWidget {
  final VoidCallback onPressed;

  const VoiceSchedulerFab({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: '語音排程',
      backgroundColor: colors.acc,
      foregroundColor: colors.onAcc,
      elevation: 2,
      highlightElevation: 4,
      hoverElevation: 3,
      shape: const CircleBorder(),
      child: const Icon(Icons.mic, size: 28),
    );
  }
}
