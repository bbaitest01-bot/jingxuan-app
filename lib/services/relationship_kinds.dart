/// 人脈關係的選項（2026-11-08 沛沛確認：改用業務員平常講的稱呼）
///
/// 存法：`customer_relationships` 一筆＝「來源客戶」的「目標客戶」是什麼人。
/// 例：來源＝王美華、目標＝陳小寶、detail＝「子女」→ 陳小寶是王美華的子女。
/// 從陳小寶那邊看要反過來：王美華是陳小寶的「父母」。
/// 畫圖時照舊歸成四種顏色（type）：家人 family、朋友 social、同事 workplace、其他 other。
class RelationshipKind {
  final String label;
  final String type;
  // 從對方那邊看的稱呼（子女 ↔ 父母）
  final String inverseLabel;

  const RelationshipKind(this.label, this.type, this.inverseLabel);
}

class RelationshipKinds {
  /// 選項順序就是按鈕順序
  static const List<RelationshipKind> all = [
    RelationshipKind('配偶', 'family', '配偶'),
    RelationshipKind('子女', 'family', '父母'),
    RelationshipKind('父母', 'family', '子女'),
    RelationshipKind('兄弟姊妹', 'family', '兄弟姊妹'),
    RelationshipKind('朋友', 'social', '朋友'),
    RelationshipKind('同事', 'workplace', '同事'),
    RelationshipKind('其他', 'other', '其他'),
  ];

  static RelationshipKind? byLabel(String label) {
    for (final RelationshipKind kind in all) {
      if (kind.label == label) return kind;
    }
    return null;
  }

  /// 舊資料沒有 detail 時用類型的中文
  static String typeLabel(String type) {
    if (type == 'family') return '家人';
    if (type == 'workplace' || type == 'colleague') return '同事';
    if (type == 'social') return '朋友';
    return '其他';
  }

  /// 一筆關係的稱呼（原本存的文字）；舊資料沒有就用類型
  static String detailOf(Map<String, dynamic> relationship) {
    String detail = relationship['relationship_detail']?.toString() ?? '';
    if (detail.isEmpty) detail = relationship['notes']?.toString() ?? '';
    if (detail.isEmpty) detail = typeLabel(relationship['relationship_type']?.toString() ?? 'other');
    return detail;
  }

  /// 從 [viewerId] 這個人的角度看，對方是他的什麼人（他是來源就照存的，他是目標就反過來）；
  /// 舊資料的自由文字（例：「母子」「獅子會社友」）不知道怎麼反過來，照原樣
  static String labelFor(String viewerId, Map<String, dynamic> relationship) {
    final String detail = detailOf(relationship);
    if (relationship['source_customer_id']?.toString() == viewerId) return detail;
    return byLabel(detail)?.inverseLabel ?? detail;
  }

  /// 線上的文字不分方向：子女、父母都寫「親子」，其他照原本
  static String edgeLabel(Map<String, dynamic> relationship) {
    final String detail = detailOf(relationship);
    if (detail == '子女' || detail == '父母') return '親子';
    return detail;
  }
}
