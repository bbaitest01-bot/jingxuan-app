import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 網狀人脈關係圖上的一位客戶（一個小圓點）
class NetworkGraphNode {
  final String id;
  final String name;
  final Map<String, dynamic> customer;

  /// 有幾條關係線（越多圓點越大、顏色越濃）
  int degree = 0;

  // 位置與速度（圖的座標，正中間是 (0, 0)）
  double x;
  double y;
  double velocityX = 0;
  double velocityY = 0;

  /// 正在被拖曳時固定在手指／滑鼠的位置
  Offset? pinnedPosition;

  NetworkGraphNode({required this.id, required this.name, required this.customer, required this.x, required this.y});

  Offset get position => Offset(x, y);

  bool get isLone => degree == 0;

  /// 沒有關係的人最小；關係越多越大，最大 16
  double get radius {
    if (isLone) return 4;
    return math.min(16, 5 + degree * 2.2);
  }
}

/// 兩位客戶之間的一條關係線
class NetworkGraphEdge {
  final NetworkGraphNode from;
  final NetworkGraphNode to;

  /// referral（轉介紹，from 介紹了 to）、family、workplace、social、other
  final String type;
  final String label;

  const NetworkGraphEdge({required this.from, required this.to, required this.type, required this.label});

  bool touches(String nodeId) => from.id == nodeId || to.id == nodeId;
}

/// 像黑曜石（Obsidian）一樣會自己排好的人脈圖（2026-10-30 組長、沛沛決定）
///
/// 每一格做三件事：圓點互相推開、有關係的人像彈簧一樣互相拉、大家都往正中間靠
/// （沒有關係的人拉得比較輕，會在外圈繞成一圈，整張圖縮小時看起來是圓的）。
/// 「熱度」[alpha] 每一格慢慢降低，大約 5 秒就停下來，不會一直佔用電腦。
class NetworkGraph extends ChangeNotifier {
  final List<NetworkGraphNode> nodes;
  final List<NetworkGraphEdge> edges;
  final Map<String, NetworkGraphNode> nodeById;

  NetworkGraph({required this.nodes, required this.edges})
      : nodeById = {for (final NetworkGraphNode node in nodes) node.id: node};

  // 力量大小（照黑曜石的手感試出來的）
  static const double linkDistance = 110;
  static const double linkStrength = 0.5;
  static const double connectedRepel = -300;
  static const double loneRepel = -40;
  static const double connectedGravity = 0.08;
  static const double loneGravity = 0.06;
  static const double collisionPadding = 16;
  static const double velocityKeep = 0.6;
  static const double alphaMin = 0.001;
  static const double alphaDecay = 0.0228;

  double alpha = 1;
  double _alphaTarget = 0;

  bool get isSettled => alpha < alphaMin && _alphaTarget == 0;

  /// 拖曳時讓圖「熱起來」，周圍的人跟著動；放開時再慢慢冷卻
  void setDragging(bool isDragging) {
    if (isDragging) {
      _alphaTarget = 0.3;
      if (alpha < 0.3) alpha = 0.3;
    } else {
      _alphaTarget = 0;
    }
  }

  /// 這位客戶和直接有關係的人（隱藏的關係類型不算）
  Set<String> neighborIdsOf(String nodeId, {Set<String> hiddenTypes = const {}}) {
    final Set<String> neighborIds = {nodeId};
    for (final NetworkGraphEdge edge in edges) {
      if (hiddenTypes.contains(edge.type)) continue;
      if (edge.from.id == nodeId) neighborIds.add(edge.to.id);
      if (edge.to.id == nodeId) neighborIds.add(edge.from.id);
    }
    return neighborIds;
  }

  /// 所有圓點（含名字的空間）佔的範圍
  Rect bounds({bool includeLone = true}) {
    Rect? result;
    for (final NetworkGraphNode node in nodes) {
      if (!includeLone && node.isLone) continue;
      final Rect nodeRect = Rect.fromCircle(center: node.position, radius: node.radius + 30);
      if (result == null) {
        result = nodeRect;
      } else {
        result = result.expandToInclude(nodeRect);
      }
    }
    return result ?? Rect.fromCircle(center: Offset.zero, radius: 100);
  }

  /// 往前算一格
  void tick() {
    alpha += (_alphaTarget - alpha) * alphaDecay;
    _applyLinks();
    _applyRepelAndCollision();
    _applyGravity();
    for (final NetworkGraphNode node in nodes) {
      final Offset? pinned = node.pinnedPosition;
      if (pinned != null) {
        node.x = pinned.dx;
        node.y = pinned.dy;
        node.velocityX = 0;
        node.velocityY = 0;
        continue;
      }
      node.velocityX *= velocityKeep;
      node.velocityY *= velocityKeep;
      node.x += node.velocityX;
      node.y += node.velocityY;
    }
    notifyListeners();
  }

  // 彈簧：比 linkDistance 遠就拉近、近就推開；關係多的人比較不會被拉動
  void _applyLinks() {
    for (final NetworkGraphEdge edge in edges) {
      final NetworkGraphNode source = edge.from;
      final NetworkGraphNode target = edge.to;
      double deltaX = target.x + target.velocityX - source.x - source.velocityX;
      double deltaY = target.y + target.velocityY - source.y - source.velocityY;
      double distance = math.sqrt(deltaX * deltaX + deltaY * deltaY);
      if (distance < 0.01) distance = 0.01;
      final double pull = (distance - linkDistance) / distance * alpha * linkStrength;
      deltaX *= pull;
      deltaY *= pull;
      final double targetShare = source.degree / (source.degree + target.degree);
      target.velocityX -= deltaX * targetShare;
      target.velocityY -= deltaY * targetShare;
      source.velocityX += deltaX * (1 - targetShare);
      source.velocityY += deltaY * (1 - targetShare);
    }
  }

  // 每兩個圓點互相推開；太近（疊在一起）時直接分開
  void _applyRepelAndCollision() {
    for (int first = 0; first < nodes.length; first++) {
      final NetworkGraphNode nodeA = nodes[first];
      for (int second = first + 1; second < nodes.length; second++) {
        final NetworkGraphNode nodeB = nodes[second];
        double deltaX = nodeB.x - nodeA.x;
        double deltaY = nodeB.y - nodeA.y;
        double squaredDistance = deltaX * deltaX + deltaY * deltaY;
        // 完全疊在同一點時沒有方向，用編號挑一個方向
        if (squaredDistance < 1) {
          deltaX = math.cos(second.toDouble());
          deltaY = math.sin(second.toDouble());
          squaredDistance = 1;
        }
        double repelOfA = connectedRepel;
        if (nodeA.isLone) repelOfA = loneRepel;
        double repelOfB = connectedRepel;
        if (nodeB.isLone) repelOfB = loneRepel;
        nodeA.velocityX += deltaX * repelOfB * alpha / squaredDistance;
        nodeA.velocityY += deltaY * repelOfB * alpha / squaredDistance;
        nodeB.velocityX -= deltaX * repelOfA * alpha / squaredDistance;
        nodeB.velocityY -= deltaY * repelOfA * alpha / squaredDistance;

        final double distance = math.sqrt(squaredDistance);
        final double minimumDistance = nodeA.radius + nodeB.radius + collisionPadding;
        if (distance < minimumDistance) {
          final double push = (minimumDistance - distance) / distance * 0.5;
          nodeA.velocityX -= deltaX * push;
          nodeA.velocityY -= deltaY * push;
          nodeB.velocityX += deltaX * push;
          nodeB.velocityY += deltaY * push;
        }
      }
    }
  }

  // 大家往正中間靠；橫向、直向一樣大，所以整體是圓的
  void _applyGravity() {
    for (final NetworkGraphNode node in nodes) {
      double gravity = connectedGravity;
      if (node.isLone) gravity = loneGravity;
      node.velocityX -= node.x * gravity * alpha;
      node.velocityY -= node.y * gravity * alpha;
    }
  }

  /// 把客戶與關係資料變成一張圖。一開始排成向日葵種子那樣的螺旋，再讓它自己散開
  static NetworkGraph build(List<Map<String, dynamic>> customers, List<Map<String, dynamic>> relationships) {
    final List<NetworkGraphNode> nodes = [];
    final Map<String, NetworkGraphNode> nodeById = {};
    final double goldenAngle = math.pi * (3 - math.sqrt(5));
    for (int index = 0; index < customers.length; index++) {
      final Map<String, dynamic> customer = customers[index];
      final double spiralRadius = 10 * math.sqrt(0.5 + index);
      final NetworkGraphNode node = NetworkGraphNode(
        id: customer['id'].toString(),
        name: customer['name']?.toString() ?? '未知',
        customer: customer,
        x: spiralRadius * math.cos(index * goldenAngle),
        y: spiralRadius * math.sin(index * goldenAngle),
      );
      nodes.add(node);
      nodeById[node.id] = node;
    }

    final List<NetworkGraphEdge> edges = _buildEdges(customers, relationships, nodeById);
    for (final NetworkGraphEdge edge in edges) {
      edge.from.degree++;
      edge.to.degree++;
    }
    return NetworkGraph(nodes: nodes, edges: edges);
  }

  static List<NetworkGraphEdge> _buildEdges(
    List<Map<String, dynamic>> customers,
    List<Map<String, dynamic>> relationships,
    Map<String, NetworkGraphNode> nodeById,
  ) {
    final List<NetworkGraphEdge> edges = [];
    for (final Map<String, dynamic> relationship in relationships) {
      final NetworkGraphNode? from = nodeById[relationship['source_customer_id']?.toString()];
      final NetworkGraphNode? to = nodeById[relationship['target_customer_id']?.toString()];
      if (from == null || to == null || from == to) continue;
      String type = relationship['relationship_type']?.toString() ?? 'other';
      if (type == 'colleague') type = 'workplace';
      String detail = relationship['relationship_detail']?.toString() ?? '';
      if (detail.isEmpty) detail = relationship['notes']?.toString() ?? '';
      edges.add(NetworkGraphEdge(from: from, to: to, type: type, label: _edgeLabel(type, detail)));
    }

    // 客戶資料上的「轉介紹來源」畫成有箭頭的線（已經有線的兩個人不重複畫）
    for (final Map<String, dynamic> customer in customers) {
      final NetworkGraphNode? referrer = nodeById[customer['referral_source_id']?.toString()];
      final NetworkGraphNode? referred = nodeById[customer['id'].toString()];
      if (referrer == null || referred == null || referrer == referred) continue;
      bool alreadyLinked = false;
      for (final NetworkGraphEdge edge in edges) {
        if (edge.touches(referrer.id) && edge.touches(referred.id)) alreadyLinked = true;
      }
      if (!alreadyLinked) {
        edges.add(NetworkGraphEdge(from: referrer, to: referred, type: 'referral', label: '轉介紹'));
      }
    }
    return edges;
  }

  static String _edgeLabel(String type, String detail) {
    if (detail.isNotEmpty) return detail;
    if (type == 'referral') return '轉介紹';
    if (type == 'family') return '親眷';
    if (type == 'workplace') return '同事';
    if (type == 'social') return '社友';
    return '朋友';
  }
}
