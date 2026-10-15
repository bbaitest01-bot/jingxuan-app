import 'package:flutter/material.dart';
import '../../widgets/custom_toast.dart';
import '../visit_projects/visit_project_form_dialog.dart';

/// 客戶管理多選後「建立專案」（4-2a）：有勾選就用勾選的，沒有就用目前篩選結果，帶進新專案的名單。
/// 打開的是專案拜訪頁同一個建立專案視窗（週期＋目標次數＋名單）。
Future<void> showCreateProjectForCustomers(
  BuildContext context, {
  required List<Map<String, dynamic>> allCustomers,
  required List<Map<String, dynamic>> filteredCustomers,
  required Set<String> selectedCustomerIds,
  required VoidCallback onCreated,
}) async {
  List<Map<String, dynamic>> targetCustomers = filteredCustomers;
  if (selectedCustomerIds.isNotEmpty) {
    targetCustomers = allCustomers.where((customer) => selectedCustomerIds.contains(customer['id'].toString())).toList();
  }

  if (targetCustomers.isEmpty) {
    CustomToast.show(context, '目前未選取目標客戶，請先勾選或篩選客戶', ToastType.warning);
    return;
  }

  // 名單：客戶編號 → 名字
  final Map<String, String> members = {};
  for (final Map<String, dynamic> customer in targetCustomers) {
    members[customer['id'].toString()] = customer['name']?.toString() ?? '';
  }

  final bool saved = await showVisitProjectFormDialog(context, initialMembers: members);
  if (!saved || !context.mounted) return;
  onCreated();
  CustomToast.show(context, '已建立專案，名單 ${members.length} 位；到「專案拜訪」查看', ToastType.success);
}
