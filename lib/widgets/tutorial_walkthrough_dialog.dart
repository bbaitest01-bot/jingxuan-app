import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 教學步驟資料模型
class WalkthroughStep {
  final String title;
  final String description;
  final String? actionBadge;
  final Offset cursorFraction; // 0.0 ~ 1.0 的相對坐標
  final Widget screen;

  const WalkthroughStep({
    required this.title,
    required this.description,
    this.actionBadge,
    required this.cursorFraction,
    required this.screen,
  });
}

/// 擬真滑鼠指標操作播放器（彈窗）
class TutorialWalkthroughDialog extends StatefulWidget {
  final String categoryName;
  final List<WalkthroughStep> steps;

  const TutorialWalkthroughDialog({
    super.key,
    required this.categoryName,
    required this.steps,
  });

  static Future<void> show(
    BuildContext context, {
    required String categoryName,
    required List<WalkthroughStep> steps,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => TutorialWalkthroughDialog(
        categoryName: categoryName,
        steps: steps,
      ),
    );
  }

  @override
  State<TutorialWalkthroughDialog> createState() => _TutorialWalkthroughDialogState();
}

class _TutorialWalkthroughDialogState extends State<TutorialWalkthroughDialog> with TickerProviderStateMixin {
  int _currentStepIndex = 0;
  bool _isPlaying = true;
  bool _isClicking = false;

  Timer? _stepTimer;
  Timer? _clickTimer;

  // 滑鼠坐標
  Offset _cursorPos = const Offset(0.5, 0.5);

  @override
  void initState() {
    super.initState();
    _startStep(_currentStepIndex);
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _clickTimer?.cancel();
    super.dispose();
  }

  void _startStep(int index) {
    _stepTimer?.cancel();
    _clickTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _currentStepIndex = index;
      _isClicking = false;
      // 游標平滑移動到按鈕目標坐標
      _cursorPos = widget.steps[index].cursorFraction;
    });

    // 0.8 秒後游標就位，觸發點擊波紋動畫
    _clickTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _isClicking = true);
      // 0.4 秒後關閉波紋
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _isClicking = false);
      });
    });

    // 自動播放：3.8 秒後切換到下一步
    if (_isPlaying) {
      _stepTimer = Timer(const Duration(milliseconds: 3800), () {
        if (!mounted) return;
        if (_currentStepIndex < widget.steps.length - 1) {
          _startStep(_currentStepIndex + 1);
        } else {
          setState(() => _isPlaying = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        if (_currentStepIndex >= widget.steps.length - 1) {
          _startStep(0);
        } else {
          _startStep(_currentStepIndex);
        }
      } else {
        _stepTimer?.cancel();
      }
    });
  }

  void _goToStep(int index) {
    if (index >= 0 && index < widget.steps.length) {
      _startStep(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final WalkthroughStep currentStep = widget.steps[_currentStepIndex];

    return Dialog(
      backgroundColor: colors.surface,
      elevation: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 頂部列：標題、播放暫停、關閉
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.accSoft,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_display_outlined, size: 16, color: colors.acc),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.categoryName} 操作教學',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.acc),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded),
                    color: colors.ink2,
                    tooltip: _isPlaying ? '暫停' : '播放',
                    onPressed: _togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: colors.ink2,
                    tooltip: '關閉',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. 分段進度條
              Row(
                children: List.generate(widget.steps.length, (int index) {
                  final bool isCurrent = index == _currentStepIndex;
                  final bool isPassed = index < _currentStepIndex;

                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index == widget.steps.length - 1 ? 0 : 6),
                      height: 4,
                      decoration: BoxDecoration(
                        color: isCurrent ? colors.acc : (isPassed ? colors.acc.withValues(alpha: 0.5) : colors.line),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),

              // 3. 核心畫面展示區（100% 靜止穩定、原生向量清晰度、游標平滑點擊）
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          border: Border.all(color: colors.line, width: 1),
                          borderRadius: BorderRadius.circular(AppRadius.control),
                        ),
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) {
                            final double w = constraints.maxWidth;
                            final double h = constraints.maxHeight;

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // 核心畫面內容（100% 向量清晰無鋸齒、零縮放晃動）
                                Positioned.fill(child: currentStep.screen),

                                // 擬真滑鼠指標
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 650),
                                  curve: Curves.easeInOutCubic,
                                  left: (_cursorPos.dx * w).clamp(0.0, w - 24.0),
                                  top: (_cursorPos.dy * h).clamp(0.0, h - 24.0),
                                  child: _VirtualMouseCursor(
                                    isClicking: _isClicking,
                                    actionBadge: currentStep.actionBadge,
                                    accentColor: colors.acc,
                                    isNearBottom: _cursorPos.dy > 0.8,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. 底部說明卡片與步驟切換
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: colors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: colors.line.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                '步驟 ${_currentStepIndex + 1} / ${widget.steps.length}',
                                style: AppTextStyles.mono(fontSize: 12, color: colors.ink3),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                currentStep.title,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.ink),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentStep.description,
                            style: TextStyle(fontSize: 13, height: 1.5, color: colors.ink2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.outlined(
                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                          tooltip: '上一步',
                          onPressed: _currentStepIndex > 0 ? () => _goToStep(_currentStepIndex - 1) : null,
                        ),
                        const SizedBox(width: 8),
                        if (_currentStepIndex < widget.steps.length - 1)
                          FilledButton(
                            onPressed: () => _goToStep(_currentStepIndex + 1),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('下一步'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('完成教學'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 擬真滑鼠游標元件（含水波紋光圈動畫與操作小提示）
class _VirtualMouseCursor extends StatelessWidget {
  final bool isClicking;
  final String? actionBadge;
  final Color accentColor;
  final bool isNearBottom;

  const _VirtualMouseCursor({
    required this.isClicking,
    this.actionBadge,
    required this.accentColor,
    this.isNearBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 點擊水波紋光圈（以指標箭頭頂點 (0, 0) 為圓心向外擴散）
        if (isClicking)
          Positioned(
            left: -20,
            top: -20,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.2, end: 1.0),
              duration: const Duration(milliseconds: 350),
              builder: (BuildContext context, double value, Widget? child) {
                final double size = 40 * value;
                return SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Opacity(
                      opacity: (1.0 - value).clamp(0.0, 1.0),
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accentColor, width: 2.5),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // 黑色擬真滑鼠指標
        CustomPaint(
          size: const Size(22, 26),
          painter: _MousePointerPainter(),
        ),

        // 動態操作提示標籤（近底時向上放，避免超出邊界被切到）
        if (actionBadge != null)
          Positioned(
            left: 20,
            top: isNearBottom ? -24 : 14,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  actionBadge!,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 繪製擬真滑鼠游標箭頭
class _MousePointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.8)
      ..lineTo(size.width * 0.32, size.height * 0.58)
      ..lineTo(size.width * 0.65, size.height * 0.95)
      ..lineTo(size.width * 0.85, size.height * 0.8)
      ..lineTo(size.width * 0.52, size.height * 0.44)
      ..lineTo(size.width * 0.88, size.height * 0.44)
      ..close();

    // 陰影
    canvas.drawShadow(path, Colors.black, 4, true);

    // 白色外框
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, borderPaint);

    // 黑色實體
    final Paint fillPaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
