import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum ToastType { success, warning, error }

class CustomToast extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const CustomToast({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
    this.actionLabel,
    this.onActionPressed,
  });

  static void show(
    BuildContext context,
    String message,
    ToastType type, {
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 檢查 context 是否仍然有效與 mounted
      if (!context.mounted) return;

      OverlayState? overlay;
      try {
        overlay = Overlay.maybeOf(context);
      } catch (_) {
        return;
      }
      if (overlay == null) return;

      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: 24,
          right: MediaQuery.of(context).size.width >= 768 ? 24 : null,
          left: MediaQuery.of(context).size.width >= 768 ? null : 24,
          width: MediaQuery.of(context).size.width >= 768 ? 360 : MediaQuery.of(context).size.width - 48,
          child: Material(
            color: Colors.transparent,
            child: CustomToast(
              message: message,
              type: type,
              actionLabel: actionLabel,
              onActionPressed: onActionPressed,
              onDismiss: () {
                if (overlayEntry.mounted) {
                  overlayEntry.remove();
                }
              },
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);
    });
  }

  @override
  State<CustomToast> createState() => _CustomToastState();
}

class _CustomToastState extends State<CustomToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    // Auto dismiss after 3 seconds
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 2026-10-19 換皮：白底細框＋左側一條語意色，取代整圈彩色框與彩色光暈
    final AppColors colors = context.appColors;
    IconData icon = Icons.check_circle_outline_rounded;
    Color iconColor = colors.ok;
    if (widget.type == ToastType.warning) {
      icon = Icons.warning_amber_rounded;
      iconColor = colors.warn;
    } else if (widget.type == ToastType.error) {
      icon = Icons.error_outline_rounded;
      iconColor = Theme.of(context).colorScheme.error;
    }
    final Color textColor = colors.ink;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: colors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            // 左側一條語意色細條（框有圓角時四邊只能同一種顏色，所以色條放在框裡面）
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: iconColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                      child: Row(
                        children: [
                          Icon(icon, color: iconColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
                            ),
                          ),
                          if (widget.actionLabel != null && widget.onActionPressed != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                widget.onActionPressed!();
                                _controller.reverse().then((_) {
                                  widget.onDismiss();
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: TextStyle(color: colors.acc, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              _controller.reverse().then((_) {
                                widget.onDismiss();
                              });
                            },
                            borderRadius: BorderRadius.circular(AppRadius.control),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(Icons.close, color: colors.ink3, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
