import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../services/network_graph_layout.dart';
import '../../theme/app_theme.dart';
import '../topology_colors.dart';
import 'network_graph_painter.dart';

/// 黑曜石風格的網狀人脈關係圖：會自己排好、可拖曳、縮放、移上去只亮他的人脈（2026-10-30）
///
/// 操作都在這裡處理：
/// - 按住圓點拖曳：圓點跟著走，有關係的人像彈簧一樣被拉著動，放開後整張圖自己重新排好
/// - 按住空白處拖曳：移動畫面；滾輪或兩指捏合：縮放
/// - 滑鼠移到圓點上：只亮他和他的人脈；點一下：選取（手機沒有滑鼠，靠點一下）
class NetworkGraphView extends StatefulWidget {
  final NetworkGraph graph;
  final NetworkViewport viewport;
  final String? selectedNodeId;
  final ValueChanged<String?> onSelectNode;
  final Set<String> hiddenTypes;
  final bool hideLoneNodes;

  const NetworkGraphView({
    super.key,
    required this.graph,
    required this.viewport,
    required this.selectedNodeId,
    required this.onSelectNode,
    required this.hiddenTypes,
    required this.hideLoneNodes,
  });

  @override
  State<NetworkGraphView> createState() => _NetworkGraphViewState();
}

class _NetworkGraphViewState extends State<NetworkGraphView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<String?> _hoveredNodeId = ValueNotifier<String?>(null);

  NetworkGraphNode? _draggingNode;
  double _gestureStartScale = 1;
  Offset _gestureStartGraphPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _startMoving();
    // 罕見字的備用字型下載好時重畫一次，名字才不會停在方框
    PaintingBinding.instance.systemFonts.addListener(_onFontsLoaded);
    // 第一格先置中，不用等圖開始動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.viewport.userHasMoved) _fitToGraph();
    });
  }

  void _fitToGraph() {
    widget.viewport.fit(widget.graph.bounds(includeLone: !widget.hideLoneNodes));
  }

  @override
  void didUpdateWidget(NetworkGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graph != widget.graph) _startMoving();
  }

  void _onFontsLoaded() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsLoaded);
    _ticker.dispose();
    _hoveredNodeId.dispose();
    super.dispose();
  }

  void _startMoving() {
    if (!_ticker.isActive) _ticker.start();
  }

  // 每一格：圖往前算一步；一開始還沒人動過畫面時，跟著縮放到全部看得到
  void _onTick(Duration elapsed) {
    widget.graph.tick();
    if (!widget.viewport.userHasMoved) _fitToGraph();
    if (widget.graph.isSettled && _draggingNode == null) _ticker.stop();
  }

  /// 畫面上這一點有沒有圓點（太小的圓點放寬一點比較好點）
  NetworkGraphNode? _nodeAt(Offset screenPoint) {
    final Offset graphPoint = widget.viewport.toGraph(screenPoint);
    final double minimumTouchRadius = 12 / widget.viewport.scale;
    NetworkGraphNode? closestNode;
    double closestDistance = double.infinity;
    for (final NetworkGraphNode node in widget.graph.nodes) {
      if (widget.hideLoneNodes && node.isLone) continue;
      final double distance = (node.position - graphPoint).distance;
      final double touchRadius = math.max(node.radius + 2, minimumTouchRadius);
      if (distance <= touchRadius && distance < closestDistance) {
        closestNode = node;
        closestDistance = distance;
      }
    }
    return closestNode;
  }

  void _onScaleStart(ScaleStartDetails details) {
    widget.viewport.userHasMoved = true;
    final NetworkGraphNode? node = _nodeAt(details.localFocalPoint);
    if (details.pointerCount == 1 && node != null) {
      _draggingNode = node;
      node.pinnedPosition = node.position;
      widget.graph.setDragging(true);
      _startMoving();
      return;
    }
    _gestureStartScale = widget.viewport.scale;
    _gestureStartGraphPoint = widget.viewport.toGraph(details.localFocalPoint);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final NetworkGraphNode? draggingNode = _draggingNode;
    if (draggingNode != null) {
      draggingNode.pinnedPosition = widget.viewport.toGraph(details.localFocalPoint);
      return;
    }
    // 手指／滑鼠下面那一點保持在原位，畫面跟著移動或縮放
    final double newScale = (_gestureStartScale * details.scale)
        .clamp(NetworkViewport.minScale, NetworkViewport.maxScale)
        .toDouble();
    widget.viewport.update(details.localFocalPoint - _gestureStartGraphPoint * newScale, newScale);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final NetworkGraphNode? draggingNode = _draggingNode;
    if (draggingNode == null) return;
    draggingNode.pinnedPosition = null;
    widget.graph.setDragging(false);
    _draggingNode = null;
  }

  void _onTapUp(TapUpDetails details) {
    final NetworkGraphNode? node = _nodeAt(details.localPosition);
    if (node == null || node.id == widget.selectedNodeId) {
      widget.onSelectNode(null);
    } else {
      widget.onSelectNode(node.id);
    }
  }

  // 滑鼠滾輪：以滑鼠所在的點為中心縮放
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (PointerSignalEvent resolvedEvent) {
      final NetworkViewport viewport = widget.viewport;
      viewport.userHasMoved = true;
      final Offset graphPoint = viewport.toGraph(event.localPosition);
      final double newScale = (viewport.scale * math.exp(-event.scrollDelta.dy / 300))
          .clamp(NetworkViewport.minScale, NetworkViewport.maxScale)
          .toDouble();
      viewport.update(event.localPosition - graphPoint * newScale, newScale);
    });
  }

  void _onHover(PointerHoverEvent event) {
    _hoveredNodeId.value = _nodeAt(event.localPosition)?.id;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Map<String, Color> edgeColors = {
      for (final String type in ['referral', 'family', 'workplace', 'social', 'other'])
        type: topologyEdgeColor(context, type),
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        widget.viewport.viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerSignal: _onPointerSignal,
          child: ValueListenableBuilder<String?>(
            valueListenable: _hoveredNodeId,
            builder: (BuildContext context, String? hoveredNodeId, Widget? child) {
              MouseCursor cursor = SystemMouseCursors.basic;
              if (hoveredNodeId != null) cursor = SystemMouseCursors.grab;
              return MouseRegion(
                cursor: cursor,
                onHover: _onHover,
                onExit: (PointerExitEvent event) => _hoveredNodeId.value = null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _onTapUp,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: NetworkGraphPainter(
                      graph: widget.graph,
                      viewport: widget.viewport,
                      focusedNodeId: hoveredNodeId ?? widget.selectedNodeId,
                      selectedNodeId: widget.selectedNodeId,
                      hiddenTypes: widget.hiddenTypes,
                      hideLoneNodes: widget.hideLoneNodes,
                      edgeColors: edgeColors,
                      colors: colors,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
