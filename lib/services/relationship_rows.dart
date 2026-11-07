import 'relationship_kinds.dart';

/// 「管理關係」視窗清單的一列：某一位客戶和這個人之間的所有關係（一般關係＋轉介紹合在一起）
class RelationshipRow {
  final String otherId;
  final String otherName;
  // 從這個人的角度看，對方是他的什麼人（例：配偶、子女、朋友）
  final List<String> labels;
  // 這個人介紹了對方
  final bool isIntroducedByViewer;
  // 對方介紹了這個人
  final bool introducedViewer;
  // 這對人的一般關係紀錄 id（刪除用）
  final List<String> relationshipIds;

  const RelationshipRow({
    required this.otherId,
    required this.otherName,
    required this.labels,
    required this.isIntroducedByViewer,
    required this.introducedViewer,
    required this.relationshipIds,
  });

  /// 清單上的文字：「朋友・王美華介紹的」「配偶」「介紹了王美華」（寫名字，不寫他／她，才不會搞混是誰介紹誰）
  String describe(String viewerName) {
    final List<String> parts = List.of(labels);
    if (isIntroducedByViewer) parts.add('$viewerName介紹的');
    if (introducedViewer) parts.add('介紹了$viewerName');
    return parts.join('・');
  }
}

/// 把關係紀錄和客戶資料上的轉介紹來源，整理成「一位對方一列」
class RelationshipRows {
  static List<RelationshipRow> build({
    required String viewerId,
    required List<Map<String, dynamic>> customers,
    required List<Map<String, dynamic>> relationships,
  }) {
    final Map<String, Map<String, dynamic>> customerById = {};
    for (final Map<String, dynamic> customer in customers) {
      customerById[customer['id'].toString()] = customer;
    }
    // 依對方整理：{對方 id: (稱呼們, 關係 id 們)}
    final Map<String, List<String>> labelsByOther = {};
    final Map<String, List<String>> idsByOther = {};
    for (final Map<String, dynamic> relationship in relationships) {
      final String sourceId = relationship['source_customer_id']?.toString() ?? '';
      final String targetId = relationship['target_customer_id']?.toString() ?? '';
      String otherId;
      if (sourceId == viewerId) {
        otherId = targetId;
      } else if (targetId == viewerId) {
        otherId = sourceId;
      } else {
        continue;
      }
      final List<String> labels = labelsByOther.putIfAbsent(otherId, () => []);
      final String label = RelationshipKinds.labelFor(viewerId, relationship);
      if (!labels.contains(label)) labels.add(label);
      idsByOther.putIfAbsent(otherId, () => []).add(relationship['id'].toString());
    }

    // 轉介紹：別人的「介紹人」是他＝他介紹的；他的「介紹人」＝介紹了他
    final Set<String> introducedByViewer = {};
    for (final Map<String, dynamic> customer in customers) {
      if (customer['referral_source_id']?.toString() == viewerId) introducedByViewer.add(customer['id'].toString());
    }
    final String? viewerReferrer = customerById[viewerId]?['referral_source_id']?.toString();

    final Set<String> otherIds = {...labelsByOther.keys, ...introducedByViewer};
    if (viewerReferrer != null && viewerReferrer.isNotEmpty) otherIds.add(viewerReferrer);

    final List<RelationshipRow> rows = [];
    for (final String otherId in otherIds) {
      final Map<String, dynamic>? other = customerById[otherId];
      if (other == null) continue;
      rows.add(RelationshipRow(
        otherId: otherId,
        otherName: other['name']?.toString() ?? '',
        labels: labelsByOther[otherId] ?? const [],
        isIntroducedByViewer: introducedByViewer.contains(otherId),
        introducedViewer: viewerReferrer == otherId,
        relationshipIds: idsByOther[otherId] ?? const [],
      ));
    }
    rows.sort((RelationshipRow first, RelationshipRow second) => first.otherName.compareTo(second.otherName));
    return rows;
  }
}
