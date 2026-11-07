import 'customer_relationship_service.dart';
import 'customer_service.dart';
import 'relationship_kinds.dart';
import 'relationship_rows.dart';

/// 「新增關係」要做的事（2026-11-08 模型圖沛沛確認：一個視窗完成新客戶＋關係＋轉介紹）
class AddRelationshipRequest {
  // 選現有客戶時有值；打新名字時是 null
  final String? existingCustomerId;
  // 打新名字時有值（只要名字就建一位客戶）
  final String newCustomerName;
  // 對方是這個人的什麼人；只勾轉介紹、沒選關係時是 null
  final RelationshipKind? kind;
  // 「是這個人介紹給我的」
  final bool isReferredByViewer;

  const AddRelationshipRequest({
    required this.existingCustomerId,
    required this.newCustomerName,
    required this.kind,
    required this.isReferredByViewer,
  });
}

/// 管理關係視窗的資料動作（畫面只負責顯示）
class RelationshipManagerService {
  /// 新增：必要時先建客戶 → 寫一般關係 → 設轉介紹；回傳對方的客戶 id（人脈圖移到他身上）
  static Future<String> addRelation(String viewerId, AddRelationshipRequest request) async {
    String otherId = request.existingCustomerId ?? '';
    if (otherId.isEmpty) {
      otherId = await CustomerService.instance.createCustomerWithName(request.newCustomerName.trim());
    }
    final RelationshipKind? kind = request.kind;
    if (kind != null) {
      // 存法：來源＝這個人、目標＝對方、detail＝對方是他的什麼人
      await CustomerRelationshipService.addRelationship(
        sourceCustomerId: viewerId,
        targetCustomerId: otherId,
        relationshipType: kind.type,
        relationshipDetail: kind.label,
      );
    }
    if (request.isReferredByViewer) {
      await CustomerRelationshipService.updateReferralSource(customerId: otherId, referralSourceId: viewerId);
    }
    return otherId;
  }

  /// 刪除一列：這對人的一般關係全部刪掉，兩人之間的轉介紹也拿掉（客戶本身不刪）
  static Future<void> removeRow(String viewerId, RelationshipRow row) async {
    for (final String relationshipId in row.relationshipIds) {
      await CustomerRelationshipService.deleteRelationship(relationshipId);
    }
    if (row.isIntroducedByViewer) {
      await CustomerRelationshipService.updateReferralSource(customerId: row.otherId, referralSourceId: null);
    }
    if (row.introducedViewer) {
      await CustomerRelationshipService.updateReferralSource(customerId: viewerId, referralSourceId: null);
    }
  }
}
