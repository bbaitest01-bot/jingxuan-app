import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 比較頁的「上方捲動列」外框：上面固定一列（第幾款／滑軌／左右箭頭），下面放整頁內容。
///
/// 為什麼需要：比較表左右放不下時，用滑鼠的人只能上下捲、看不到右邊（要按 Shift）。
/// 這一列固定在頁面最上方，往下捲表格時也看得到；觸控板兩指滑動照常可用，
/// 因為表格和滑軌共用同一個 [controller]，任一邊移動另一邊都會跟著動。
class ComparisonScrollArea extends StatefulWidget {
  /// 比較表左右捲動用的控制器（同一個也要交給表格的 SingleChildScrollView）
  final ScrollController controller;

  /// 共有幾款商品（一款一欄）
  final int columnCount;

  /// 一欄佔的寬度（欄寬＋欄與欄的間距），箭頭一次移一欄
  final double columnStep;

  /// 頁面內容（上下捲動的那一層，裡面包著左右捲動的比較表）
  final Widget child;

  const ComparisonScrollArea({
    super.key,
    required this.controller,
    required this.columnCount,
    required this.columnStep,
    required this.child,
  });

  @override
  State<ComparisonScrollArea> createState() => _ComparisonScrollAreaState();
}

class _ComparisonScrollAreaState extends State<ComparisonScrollArea> {
  /// 手機寬度以下不顯示（手機用手指左右滑就好），和專案其他頁面一樣用 768
  static const double _mobileWidthLimit = 768;

  /// 比較表是不是有放不下、要往右捲才看得到的商品
  bool _hasHiddenColumns = false;

  @override
  void initState() {
    super.initState();
    // 表格一捲動就再確認一次（保險起見，避免第一次量尺寸時漏掉）
    widget.controller.addListener(_checkHiddenColumns);
  }

  @override
  void didUpdateWidget(ComparisonScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_checkHiddenColumns);
      widget.controller.addListener(_checkHiddenColumns);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkHiddenColumns);
    super.dispose();
  }

  // 直接問比較表「還能往右捲多少」：大於 0 就是有商品放不下，要顯示這一列
  void _checkHiddenColumns() {
    if (!mounted || !widget.controller.hasClients) {
      return;
    }
    final ScrollPosition position = widget.controller.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return;
    }
    final bool hasHiddenColumns = position.maxScrollExtent > 0;
    if (hasHiddenColumns != _hasHiddenColumns) {
      setState(() => _hasHiddenColumns = hasHiddenColumns);
    }
  }

  // 比較表量好尺寸（第一次顯示、視窗縮放、增減商品）時，重新判斷要不要顯示這一列
  bool _handleMetricsChanged(ScrollMetricsNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) {
      _checkHiddenColumns();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // 每次畫完畫面（第一次打開、資料載入完、視窗縮放）都再確認一次
    WidgetsBinding.instance.addPostFrameCallback((Duration unusedTimeStamp) => _checkHiddenColumns());

    final bool isMobile = MediaQuery.sizeOf(context).width < _mobileWidthLimit;
    final bool showBar = _hasHiddenColumns && !isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBar)
          _ComparisonScrollBar(
            controller: widget.controller,
            columnCount: widget.columnCount,
            columnStep: widget.columnStep,
          ),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _handleMetricsChanged,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// 上方那一列：「第 1–4 款／共 N 款」＋滑軌＋左右箭頭
class _ComparisonScrollBar extends StatelessWidget {
  final ScrollController controller;
  final int columnCount;
  final double columnStep;

  const _ComparisonScrollBar({
    required this.controller,
    required this.columnCount,
    required this.columnStep,
  });

  // 箭頭：一次移一欄，並對齊到欄的開頭（不會停在半欄）
  void _scrollOneColumn({required bool toRight}) {
    if (!controller.hasClients) {
      return;
    }
    final ScrollPosition position = controller.position;
    final double currentColumn = position.pixels / columnStep;
    double targetColumn;
    if (toRight) {
      targetColumn = currentColumn.floorToDouble() + 1;
    } else {
      targetColumn = currentColumn.ceilToDouble() - 1;
    }
    final double target = (targetColumn * columnStep).clamp(0.0, position.maxScrollExtent);
    controller.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      // 表格一捲動（滑鼠、觸控板、箭頭都算），這一列就跟著更新
      child: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? unusedChild) {
          if (!controller.hasClients) {
            return const SizedBox(height: 28);
          }
          final ScrollPosition position = controller.position;
          final bool atStart = position.pixels <= 0.5;
          final bool atEnd = position.pixels >= position.maxScrollExtent - 0.5;

          return Row(
            children: [
              _VisibleRangeLabel(position: position, columnCount: columnCount, columnStep: columnStep),
              const SizedBox(width: 12),
              Expanded(child: _DraggableTrack(controller: controller, position: position)),
              const SizedBox(width: 12),
              _ArrowButton(
                icon: Icons.chevron_left_rounded,
                tooltip: '往左一款',
                isEnabled: !atStart,
                onPressed: () => _scrollOneColumn(toRight: false),
              ),
              const SizedBox(width: 6),
              _ArrowButton(
                icon: Icons.chevron_right_rounded,
                tooltip: '往右一款',
                isEnabled: !atEnd,
                onPressed: () => _scrollOneColumn(toRight: true),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 「第 1–4 款／共 7 款」：依目前捲到哪裡，算出畫面上看得到第幾款到第幾款
class _VisibleRangeLabel extends StatelessWidget {
  final ScrollPosition position;
  final int columnCount;
  final double columnStep;

  const _VisibleRangeLabel({required this.position, required this.columnCount, required this.columnStep});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    // 左邊露出一半以上才算看得到；右邊要整欄都露出來才算
    int firstVisible = (position.pixels / columnStep).round() + 1;
    int lastVisible = ((position.pixels + position.viewportDimension) / columnStep).floor();
    if (firstVisible > columnCount) {
      firstVisible = columnCount;
    }
    if (lastVisible > columnCount) {
      lastVisible = columnCount;
    }
    if (lastVisible < firstVisible) {
      lastVisible = firstVisible;
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 12, color: colors.ink2),
        children: [
          const TextSpan(text: '第 '),
          TextSpan(text: '$firstVisible–$lastVisible', style: AppTextStyles.mono(fontSize: 12, color: colors.ink)),
          const TextSpan(text: ' 款／共 '),
          TextSpan(text: '$columnCount', style: AppTextStyles.mono(fontSize: 12, color: colors.ink)),
          const TextSpan(text: ' 款'),
        ],
      ),
    );
  }
}

/// 可以拖曳、也可以點的滑軌：灰色底是全部商品，主題色那段是目前看得到的範圍
class _DraggableTrack extends StatelessWidget {
  static const double _trackHeight = 10;

  final ScrollController controller;
  final ScrollPosition position;

  const _DraggableTrack({required this.controller, required this.position});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double trackWidth = constraints.maxWidth;
        final double maxScroll = position.maxScrollExtent;
        final double totalWidth = maxScroll + position.viewportDimension;

        // 主題色那段的長度＝看得到的比例；最少 40，太短不好抓
        double thumbWidth = trackWidth * position.viewportDimension / totalWidth;
        if (thumbWidth < 40) {
          thumbWidth = 40;
        }
        if (thumbWidth > trackWidth) {
          thumbWidth = trackWidth;
        }
        final double movableWidth = trackWidth - thumbWidth;
        double thumbLeft = 0;
        if (maxScroll > 0) {
          thumbLeft = movableWidth * (position.pixels / maxScroll);
        }

        // 拖曳：手指／滑鼠移動多少，換算成表格要捲多少
        void handleDrag(DragUpdateDetails details) {
          if (movableWidth <= 0) {
            return;
          }
          final double scrollDelta = details.delta.dx * maxScroll / movableWidth;
          final double target = (position.pixels + scrollDelta).clamp(0.0, maxScroll);
          controller.jumpTo(target);
        }

        // 點空白處：讓主題色那段的中間移到點的位置
        void handleTap(TapUpDetails details) {
          if (movableWidth <= 0) {
            return;
          }
          final double ratio = ((details.localPosition.dx - thumbWidth / 2) / movableWidth).clamp(0.0, 1.0);
          controller.animateTo(
            ratio * maxScroll,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: handleTap,
            onHorizontalDragUpdate: handleDrag,
            // 上下各留一點空間，比較好點到
            child: SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: _trackHeight,
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      border: Border.all(color: colors.line),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  Positioned(
                    left: thumbLeft,
                    width: thumbWidth,
                    child: Container(
                      height: _trackHeight,
                      decoration: BoxDecoration(
                        color: colors.acc,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 左右小箭頭；已經到最左／最右時變淡、按了沒反應
class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isEnabled;
  final VoidCallback onPressed;

  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    VoidCallback? pressHandler;
    if (isEnabled) {
      pressHandler = onPressed;
    }

    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: pressHandler,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          disabledForegroundColor: colors.ink3,
          side: BorderSide(color: colors.line),
          minimumSize: const Size(32, 28),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
