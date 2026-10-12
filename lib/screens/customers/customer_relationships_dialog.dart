import 'package:flutter/material.dart';
import '../../services/customer_relationship_service.dart';
import '../../widgets/custom_toast.dart';

/// 管理一位客戶的人脈：轉介紹來源（維度 1）與社交角色關係（維度 2）。
/// 轉介紹來源改變時呼叫 [onReferralSourceChanged]，讓外框同步畫面上的客戶資料。
Future<void> showCustomerRelationshipsDialog(
  BuildContext outerContext, {
  required Map<String, dynamic> customer,
  required List<Map<String, dynamic>> allCustomers,
  required void Function(String? referralSourceId) onReferralSourceChanged,
}) async {
  final customerId = customer['id'].toString();
  String? currentReferralId = customer['referral_source_id']?.toString();

  List<Map<String, dynamic>> rels = await CustomerRelationshipService.fetchAllRelationships();

  if (!outerContext.mounted) return;

  showDialog(
    context: outerContext,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final myRels = rels.where((r) =>
            r['source_customer_id'].toString() == customerId ||
            r['target_customer_id'].toString() == customerId
          ).toList();

          final otherCustomers = allCustomers.where((c) => c['id'].toString() != customerId).toList();

          String? selectedTargetId = otherCustomers.isNotEmpty ? otherCustomers.first['id'].toString() : null;
          String selectedType = 'family';
          final detailController = TextEditingController(text: '親眷');

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.hub_rounded, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '👥 管理人脈與轉介紹：${customer['name']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📌 維度 1：轉介紹歸因 (Referral Source)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                    const SizedBox(height: 4),
                    const Text('指定是哪位已有客戶將此人轉介紹給您：', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: otherCustomers.any((c) => c['id'].toString() == currentReferralId) ? currentReferralId : null,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('無 (自開發 / 獨立客戶)'),
                        ),
                        ...otherCustomers.map((c) => DropdownMenuItem<String?>(
                          value: c['id'].toString(),
                          child: Text('${c['name']} ${c['phone'] != null && c['phone'].toString().isNotEmpty ? "(${c['phone']})" : ""}'),
                        )),
                      ],
                      onChanged: (val) async {
                        currentReferralId = val;
                        await CustomerRelationshipService.updateReferralSource(
                          customerId: customerId,
                          referralSourceId: val,
                        );
                        onReferralSourceChanged(val);
                        setDialogState(() {});
                        CustomToast.show(outerContext, '✅ 已更新轉介紹來源', ToastType.success);
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    const Text('🕸️ 維度 2：社交角色關係 (Social Relationships)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    const SizedBox(height: 4),
                    const Text('建立與其他客戶的親眷、職場、社團關係：', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 10),

                    if (myRels.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('目前尚無社交角色關係紀錄', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )
                    else
                      ...myRels.map((r) {
                        final bool isSource = r['source_customer_id'].toString() == customerId;
                        final otherId = isSource ? r['target_customer_id'].toString() : r['source_customer_id'].toString();
                        final otherCust = allCustomers.firstWhere((c) => c['id'].toString() == otherId, orElse: () => {'name': '未知客戶'});
                        final typeStr = r['relationship_type'] ?? 'family';
                        final detailStr = r['relationship_detail'] ?? '';

                        Color tagColor = const Color(0xFF10B981);
                        String typeName = '親眷';
                        if (typeStr == 'workplace') { tagColor = const Color(0xFFF59E0B); typeName = '職場'; }
                        else if (typeStr == 'social') { tagColor = const Color(0xFF8B5CF6); typeName = '社團'; }
                        else if (typeStr == 'other') { tagColor = const Color(0xFF6B7280); typeName = '其他'; }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tagColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tagColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(typeName, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${otherCust['name']} (${detailStr.isNotEmpty ? detailStr : typeName})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                onPressed: () async {
                                  await CustomerRelationshipService.deleteRelationship(r['id'].toString());
                                  rels = await CustomerRelationshipService.fetchAllRelationships();
                                  setDialogState(() {});
                                  CustomToast.show(outerContext, '🗑️ 已解除人脈關係', ToastType.warning);
                                },
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(outerContext).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('➕ 新增社交關係：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedTargetId,
                            items: otherCustomers.map((c) => DropdownMenuItem<String>(
                              value: c['id'].toString(),
                              child: Text(c['name'] ?? ''),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) selectedTargetId = val;
                            },
                            decoration: InputDecoration(
                              labelText: '選擇對象客戶',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedType,
                                  items: const [
                                    DropdownMenuItem(value: 'family', child: Text('親眷')),
                                    DropdownMenuItem(value: 'workplace', child: Text('職場/同事')),
                                    DropdownMenuItem(value: 'social', child: Text('社團/朋友')),
                                    DropdownMenuItem(value: 'other', child: Text('其他')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      selectedType = val;
                                      if (val == 'family') detailController.text = '親眷';
                                      else if (val == 'workplace') detailController.text = '同事';
                                      else if (val == 'social') detailController.text = '社友';
                                      else detailController.text = '朋友';
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: '關係類別',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: detailController,
                                  decoration: InputDecoration(
                                    labelText: '細節描述 (如 夫妻)',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (selectedTargetId != null) {
                                  await CustomerRelationshipService.addRelationship(
                                    sourceCustomerId: customerId,
                                    targetCustomerId: selectedTargetId!,
                                    relationshipType: selectedType,
                                    relationshipDetail: detailController.text.trim(),
                                  );
                                  rels = await CustomerRelationshipService.fetchAllRelationships();
                                  setDialogState(() {});
                                  CustomToast.show(outerContext, '✅ 成功新增人脈關聯', ToastType.success);
                                }
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('新增關聯'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('關閉'),
              ),
            ],
          );
        },
      );
    },
  );
}
