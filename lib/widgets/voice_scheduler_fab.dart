import 'package:flutter/material.dart';

/// 今日行程右下角的「語音排程」麥克風按鈕。
/// 深色模式時外圈會有呼吸燈般的光暈動畫；淺色模式是一般的淡色按鈕。
class VoiceSchedulerFab extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isDark;
  final Color primaryColor;

  const VoiceSchedulerFab({
    super.key,
    required this.onPressed,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  State<VoiceSchedulerFab> createState() => _VoiceSchedulerFabState();
}

class _VoiceSchedulerFabState extends State<VoiceSchedulerFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDark) {
      return FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: widget.primaryColor.withValues(alpha: 0.12),
        elevation: 0,
        highlightElevation: 2,
        hoverElevation: 1,
        shape: const CircleBorder(),
        child: Icon(
          Icons.mic,
          color: widget.primaryColor,
          size: 28,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withValues(alpha: 0.35),
                blurRadius: _glowAnimation.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: const Color(0xFF161B22),
        elevation: 4,
        shape: CircleBorder(
          side: BorderSide(color: widget.primaryColor.withValues(alpha: 0.3), width: 1),
        ),
        child: Icon(
          Icons.mic,
          color: widget.primaryColor,
          size: 28,
        ),
      ),
    );
  }
}
