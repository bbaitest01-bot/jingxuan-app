import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'walkthrough_stage.dart';
import 'walkthrough_step.dart';

/// 教學中心的操作示範播放器：像 IG 限時動態一樣自動播放；
/// 在畫面上點左邊回上一步、點右邊到下一步、點中間暫停／繼續（下方按鈕也可以操作）
class WalkthroughPlayerDialog extends StatefulWidget {
  final String categoryName;
  final List<WalkthroughStep> steps;

  const WalkthroughPlayerDialog({super.key, required this.categoryName, required this.steps});

  static Future<void> show(
    BuildContext context, {
    required String categoryName,
    required List<WalkthroughStep> steps,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => WalkthroughPlayerDialog(categoryName: categoryName, steps: steps),
    );
  }

  @override
  State<WalkthroughPlayerDialog> createState() => _WalkthroughPlayerDialogState();
}

class _WalkthroughPlayerDialogState extends State<WalkthroughPlayerDialog> with SingleTickerProviderStateMixin {
  // 舞台寬高比，和截圖一樣是 16:9
  static const double _stageAspectRatio = 16 / 9;
  // 舞台以外（標題、進度、說明、按鈕）大約佔的高度
  static const double _chromeHeight = 212;
  static const double _maxStageWidth = 1040;

  late final AnimationController _timelineController;
  int _currentIndex = 0;
  bool _isPlaying = true;
  bool _isFirstImageReady = false;
  bool _hasStartedLoading = false;

  WalkthroughStep get _currentStep => widget.steps[_currentIndex];
  bool get _isLastStep => _currentIndex == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _timelineController = AnimationController(vsync: this)..addStatusListener(_onTimelineStatusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // precacheImage 需要 context 裡的畫面資訊，所以放在這裡，而且只做一次
    if (_hasStartedLoading) return;
    _hasStartedLoading = true;
    _loadImagesThenStart();
  }

  @override
  void dispose() {
    _timelineController.dispose();
    super.dispose();
  }

  // 先載入第一步的圖再開始播，其餘的圖在背景載入，換步時才不會閃一下
  Future<void> _loadImagesThenStart() async {
    await _precacheStep(0);
    if (!mounted) return;
    setState(() => _isFirstImageReady = true);
    _playStep(0);
    for (int index = 1; index < widget.steps.length; index++) {
      if (!mounted) return;
      await _precacheStep(index);
    }
  }

  Future<void> _precacheStep(int index) async {
    final WalkthroughStep step = widget.steps[index];
    await precacheImage(AssetImage(step.image), context);
    if (!mounted) return;
    final String? imageAfter = step.imageAfter;
    if (imageAfter != null) await precacheImage(AssetImage(imageAfter), context);
    if (!mounted) return;
    final WalkthroughScroll? scroll = step.scroll;
    if (scroll != null) await precacheImage(AssetImage(scroll.stripImage), context);
  }

  void _playStep(int index) {
    setState(() => _currentIndex = index);
    _timelineController
      ..duration = Duration(milliseconds: WalkthroughTiming.totalOf(widget.steps[index]))
      ..forward(from: 0);
  }

  // 一步播完：播放中就接下一步；暫停時（手動按上一步、下一步播完）就停在這裡
  void _onTimelineStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_isPlaying) return;
    if (_isLastStep) {
      setState(() => _isPlaying = false);
      return;
    }
    _playStep(_currentIndex + 1);
  }

  void _togglePlaying() {
    if (_isPlaying) {
      _timelineController.stop();
      setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    // 最後一步已經播完時，按播放就從頭開始
    if (_timelineController.isCompleted && _isLastStep) {
      _playStep(0);
      return;
    }
    if (_timelineController.isCompleted) {
      _playStep(_currentIndex + 1);
      return;
    }
    _timelineController.forward();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) _playStep(_currentIndex - 1);
  }

  // 點畫面：左邊 30%＝上一步、右邊 30%＝下一步、中間＝暫停／繼續
  void _onStageTapped(TapUpDetails details, double stageWidth) {
    final double tapFraction = details.localPosition.dx / stageWidth;
    if (tapFraction < 0.3) {
      _goToPrevious();
      return;
    }
    if (tapFraction > 0.7) {
      _goToNext();
      return;
    }
    if (_isFirstImageReady) _togglePlaying();
  }

  void _goToNext() {
    if (!_isLastStep) _playStep(_currentIndex + 1);
  }

  // 這一步開始時，滑鼠和鏡頭要接著上一步結束的地方，動作才連得起來
  Offset _cursorStartOf(int index) {
    if (index == 0) return const Offset(0.5, 0.6);
    return widget.steps[index - 1].target;
  }

  WalkthroughCamera _cameraStartOf(int index) {
    if (index == 0) return WalkthroughCamera.full;
    return widget.steps[index - 1].cameraAfter;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Size screenSize = MediaQuery.sizeOf(context);
    // 舞台盡量大，但高度要放得下，也不能超出螢幕寬度
    final double widthFromHeight = (screenSize.height - 48 - _chromeHeight) * _stageAspectRatio;
    final double stageWidth = math.max(240, math.min(math.min(screenSize.width - 72, widthFromHeight), _maxStageWidth));

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      child: SizedBox(
        width: stageWidth + 24,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(colors),
              const SizedBox(height: 8),
              _buildProgressBar(colors),
              const SizedBox(height: 10),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails details) => _onStageTapped(details, stageWidth),
                  child: SizedBox(width: stageWidth, height: stageWidth / _stageAspectRatio, child: _buildStage(colors)),
                ),
              ),
              const SizedBox(height: 12),
              _buildCaption(colors),
              const SizedBox(height: 8),
              _buildControls(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Row(
      children: [
        Icon(Icons.play_circle_outline_rounded, size: 20, color: colors.acc),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${widget.categoryName} 操作示範',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink),
          ),
        ),
        IconButton(
          tooltip: '關閉',
          icon: Icon(Icons.close_rounded, size: 20, color: colors.ink2),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // 頂部進度條：一步一格，目前這一格跟著播放進度填滿
  Widget _buildProgressBar(AppColors colors) {
    final List<Widget> segments = [];
    for (int index = 0; index < widget.steps.length; index++) {
      if (index > 0) segments.add(const SizedBox(width: 3));
      segments.add(
        Expanded(
          child: AnimatedBuilder(
            animation: _timelineController,
            builder: (BuildContext builderContext, Widget? child) {
              double fill = 0;
              if (index < _currentIndex) fill = 1;
              if (index == _currentIndex) fill = _timelineController.value;
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: fill,
                  minHeight: 3,
                  backgroundColor: colors.line,
                  color: colors.acc,
                ),
              );
            },
          ),
        ),
      );
    }
    return Row(children: segments);
  }

  Widget _buildStage(AppColors colors) {
    if (!_isFirstImageReady) {
      return ColoredBox(
        color: colors.surface2,
        child: Center(child: CircularProgressIndicator(color: colors.acc)),
      );
    }
    return AnimatedBuilder(
      animation: _timelineController,
      builder: (BuildContext builderContext, Widget? child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            WalkthroughStage(
              step: _currentStep,
              cursorStart: _cursorStartOf(_currentIndex),
              cameraStart: _cameraStartOf(_currentIndex),
              elapsedMilliseconds: _timelineController.value * WalkthroughTiming.totalOf(_currentStep),
              previousImage: _currentIndex == 0 ? null : widget.steps[_currentIndex - 1].endImage,
            ),
            if (_isStoppedByUser) _buildPausedBadge(colors),
          ],
        );
      },
    );
  }

  // 真的停住時才顯示（暫停狀態下點上一步、下一步，那一步還是會播完）
  bool get _isStoppedByUser => !_isPlaying && !_timelineController.isAnimating;

  bool get _hasFinished => !_isPlaying && _isLastStep && _timelineController.isCompleted;

  // 畫面中間的暫停（播完時是重播）提示；不擋點擊
  Widget _buildPausedBadge(AppColors colors) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: colors.acc.withValues(alpha: 0.85), shape: BoxShape.circle),
          child: Icon(_hasFinished ? Icons.replay_rounded : Icons.play_arrow_rounded, size: 36, color: colors.onAcc),
        ),
      ),
    );
  }

  // 說明文字固定高度，換步時版面才不會跳動
  Widget _buildCaption(AppColors colors) {
    return SizedBox(
      height: 62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentStep.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            _currentStep.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.4, color: colors.ink2),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(AppColors colors) {
    IconData playIcon = Icons.play_arrow_rounded;
    if (_isPlaying) playIcon = Icons.pause_rounded;
    if (_hasFinished) playIcon = Icons.replay_rounded;

    return Row(
      children: [
        Text(
          '${_currentIndex + 1} / ${widget.steps.length}',
          style: AppTextStyles.mono(fontSize: 12, color: colors.ink3),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '點畫面左右換步，點中間暫停',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colors.ink3),
          ),
        ),
        IconButton(
          tooltip: '上一步',
          onPressed: _currentIndex > 0 ? _goToPrevious : null,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        IconButton.filled(
          tooltip: _isPlaying ? '暫停' : '播放',
          onPressed: _isFirstImageReady ? _togglePlaying : null,
          style: IconButton.styleFrom(backgroundColor: colors.acc, foregroundColor: colors.onAcc),
          icon: Icon(playIcon),
        ),
        IconButton(
          tooltip: '下一步',
          onPressed: _isLastStep ? null : _goToNext,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}
