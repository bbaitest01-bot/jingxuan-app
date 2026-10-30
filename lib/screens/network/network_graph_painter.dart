import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/network_graph_layout.dart';
import '../../theme/app_theme.dart';

/// 目前看的位置與縮放：圖的 (0, 0) 在畫面的 [offset]，放大 [scale] 倍
class NetworkViewport extends ChangeNotifier {
  Offset _offset = Offset.zero;
  double _scale = 1;

  Offset get offset => _offset;
  double get scale => _scale;

  /// 圖的可視範圍大小（畫面算好後更新）
  Size viewSize = const Size(800, 500);

  /// 使用者自己拖過或縮放過：一開始的「自動縮放到全部看得到」就停止，不搶使用者的畫面
  bool userHasMoved = false;

  static const double minScale = 0.2;
  static const double maxScale = 4;

  void update(Offset offset, double scale) {
    _offset = offset;
    _scale = scale.clamp(minScale, maxScale).toDouble();
    notifyListeners();
  }

  /// 畫面上的點 → 圖上的點
  Offset toGraph(Offset screenPoint) => (screenPoint - _offset) / _scale;

  /// 把圖上的某一點移到畫面正中間
  void centerOn(Offset graphPoint, {double? scale}) {
    final double newScale = (scale ?? _scale).clamp(minScale, maxScale).toDouble();
    update(Offset(viewSize.width / 2, viewSize.height / 2) - graphPoint * newScale, newScale);
  }

  /// 縮放到 [area] 整個看得到、放在 [viewSize] 正中間（最多放大到 [maxFitScale]）
  void fit(Rect area, {double maxFitScale = 1.2}) {
    final double widthScale = viewSize.width / area.width;
    final double heightScale = viewSize.height / area.height;
    final double scale = math.min(math.min(widthScale, heightScale) * 0.92, maxFitScale);
    final double clampedScale = scale.clamp(minScale, maxScale).toDouble();
    update(Offset(viewSize.width / 2, viewSize.height / 2) - area.center * clampedScale, clampedScale);
  }
}

/// 畫整張黑曜石風格的人脈圖：線、轉介紹箭頭、小圓點、名字、關係文字
///
/// 全部在一張畫布上一次畫完（不是每個圓點一個元件），圓點會動時才不會卡（2026-10-30）。
class NetworkGraphPainter extends CustomPainter {
  final NetworkGraph graph;
  final NetworkViewport viewport;

  /// 滑鼠移上去或點選的那位客戶：只有他和他的人脈是亮的
  final String? focusedNodeId;
  final String? selectedNodeId;
  final Set<String> hiddenTypes;
  final bool hideLoneNodes;
  final Map<String, Color> edgeColors;
  final AppColors colors;

  // 名字與關係文字只排版一次
  final Map<String, TextPainter> _textCache = {};

  /// 縮到比這個小，名字先隱藏（太小看不清楚，只看整體形狀）
  static const double nameVisibleScale = 0.7;

  /// 放大到比這個大，每條線都寫出關係
  static const double edgeLabelVisibleScale = 1.6;

  NetworkGraphPainter({
    required this.graph,
    required this.viewport,
    required this.focusedNodeId,
    required this.selectedNodeId,
    required this.hiddenTypes,
    required this.hideLoneNodes,
    required this.edgeColors,
    required this.colors,
  }) : super(repaint: Listenable.merge([graph, viewport]));

  bool _isNodeVisible(NetworkGraphNode node) => !(hideLoneNodes && node.isLone);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(viewport.offset.dx, viewport.offset.dy);
    canvas.scale(viewport.scale);

    final String? focusId = focusedNodeId;
    Set<String>? focusIds;
    if (focusId != null) focusIds = graph.neighborIdsOf(focusId, hiddenTypes: hiddenTypes);

    final List<NetworkGraphEdge> visibleEdges = [];
    for (final NetworkGraphEdge edge in graph.edges) {
      if (!hiddenTypes.contains(edge.type)) visibleEdges.add(edge);
    }
    for (final NetworkGraphEdge edge in visibleEdges) {
      _paintEdge(canvas, edge, focusId);
    }
    for (final NetworkGraphNode node in graph.nodes) {
      if (_isNodeVisible(node)) _paintNode(canvas, node, focusIds);
    }
    for (final NetworkGraphEdge edge in visibleEdges) {
      // 關係文字：有人被選取時只寫他的線；沒有時放大到夠大才全部寫
      bool showLabel = viewport.scale >= edgeLabelVisibleScale;
      if (focusId != null) showLabel = edge.touches(focusId);
      if (showLabel) _paintEdgeLabel(canvas, edge);
    }
    canvas.restore();
  }

  Color _edgeColor(String type) => edgeColors[type] ?? edgeColors['other']!;

  void _paintEdge(Canvas canvas, NetworkGraphEdge edge, String? focusId) {
    double opacity = 0.55;
    double width = 1.2;
    if (focusId != null) {
      opacity = 0.06;
      if (edge.touches(focusId)) {
        opacity = 1;
        width = 2;
      }
    }
    final Paint linePaint = Paint()
      ..color = _edgeColor(edge.type).withValues(alpha: opacity)
      ..strokeWidth = width;
    canvas.drawLine(edge.from.position, edge.to.position, linePaint);
    if (edge.type == 'referral') _paintArrow(canvas, edge, linePaint.color);
  }

  // 轉介紹的箭頭：指向被介紹的人，尖端停在圓點外緣
  void _paintArrow(Canvas canvas, NetworkGraphEdge edge, Color color) {
    final Offset direction = edge.to.position - edge.from.position;
    final double length = direction.distance;
    if (length < 1) return;
    final Offset unit = direction / length;
    final Offset side = Offset(-unit.dy, unit.dx);
    final Offset tip = edge.to.position - unit * (edge.to.radius + 2);
    final Path arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - unit.dx * 8 + side.dx * 4, tip.dy - unit.dy * 8 + side.dy * 4)
      ..lineTo(tip.dx - unit.dx * 8 - side.dx * 4, tip.dy - unit.dy * 8 - side.dy * 4)
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);
  }

  void _paintNode(Canvas canvas, NetworkGraphNode node, Set<String>? focusIds) {
    final bool isDimmed = focusIds != null && !focusIds.contains(node.id);
    // 關係越多顏色越濃；沒有關係的人用灰色
    Color color = colors.acc.withValues(alpha: 0.45 + math.min(node.degree, 4) * 0.13);
    if (node.isLone) color = colors.ink3.withValues(alpha: 0.55);
    if (isDimmed) color = color.withValues(alpha: 0.12);
    canvas.drawCircle(node.position, node.radius, Paint()..color = color);

    if (node.id == selectedNodeId) {
      final Paint ringPaint = Paint()
        ..color = colors.warn
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(node.position, node.radius + 4, ringPaint);
    }

    // 名字：縮太小時隱藏，被選取的人脈例外
    final bool isInFocus = focusIds != null && focusIds.contains(node.id);
    if (viewport.scale < nameVisibleScale && !isInFocus) return;
    Color nameColor = colors.ink;
    if (isDimmed) nameColor = colors.ink.withValues(alpha: 0.15);
    final TextPainter namePainter = _text(node.name, 11, nameColor, FontWeight.normal);
    namePainter.paint(canvas, node.position + Offset(-namePainter.width / 2, node.radius + 3));
  }

  void _paintEdgeLabel(Canvas canvas, NetworkGraphEdge edge) {
    final Offset middle = (edge.from.position + edge.to.position) / 2;
    final TextPainter labelPainter = _text(edge.label, 10, colors.ink2, FontWeight.bold);
    final Rect pillRect = Rect.fromCenter(
      center: middle,
      width: labelPainter.width + 12,
      height: labelPainter.height + 6,
    );
    final RRect pill = RRect.fromRectAndRadius(pillRect, const Radius.circular(8));
    canvas.drawRRect(pill, Paint()..color = colors.surface);
    final Paint borderPaint = Paint()
      ..color = _edgeColor(edge.type)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(pill, borderPaint);
    labelPainter.paint(canvas, middle - Offset(labelPainter.width / 2, labelPainter.height / 2));
  }

  TextPainter _text(String text, double fontSize, Color color, FontWeight weight) {
    final String cacheKey = '$text|$fontSize|${color.toARGB32()}|${weight.value}';
    return _textCache.putIfAbsent(cacheKey, () {
      final TextPainter painter = TextPainter(
        // 要指定內建黑體：畫布不會套用 App 的字型設定，沒指定時中文會變方框（2026-10-30 沛沛反映）
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: AppTextStyles.bodyFamily,
            fontSize: fontSize,
            color: color,
            fontWeight: weight,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      return painter;
    });
  }

  @override
  bool shouldRepaint(covariant NetworkGraphPainter oldDelegate) => true;
}
