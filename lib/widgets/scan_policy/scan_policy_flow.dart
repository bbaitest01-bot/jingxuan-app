import 'package:flutter/material.dart';

import '../../services/customer_policy_service.dart';
import '../../services/policy_scan_service.dart';
import '../custom_toast.dart';
import 'scan_customer_picker_dialog.dart';
import 'scan_notice_dialog.dart';
import 'scan_policy_screen.dart';

/// 掃描保單的共用入口（數據戰情第四張卡、客戶完整頁、客戶側邊抽屜都呼叫這裡）
///
/// 已經在某位客戶的頁面時，帶 customerId、customerName 就會跳過「選客戶」。
/// 存入成功回傳 true，讓呼叫的頁面重新讀資料。
Future<bool> startPolicyScan(BuildContext context, {String? customerId, String? customerName}) async {
  // ① 選客戶（從客戶頁進來就不用選）
  ScanCustomerChoice? customerChoice;
  if (customerId != null) {
    customerChoice = ScanCustomerChoice(customerId: customerId, customerName: customerName ?? '這位客戶');
  } else {
    customerChoice = await _pickCustomer(context);
  }
  if (customerChoice == null || !context.mounted) return false;

  // ② 每次都要勾「已向客戶說明並取得同意」；第一次使用多顯示照片怎麼處理的完整說明
  final PolicyScanService scanService = PolicyScanService();
  final bool isFirstTime = !await scanService.hasAgreedToNotice();
  if (!context.mounted) return false;
  final bool agreed = await showScanNoticeDialog(
    context,
    customerName: customerChoice.customerName,
    showPrivacyDetails: isFirstTime,
  );
  if (!agreed || !context.mounted) return false;
  if (isFirstTime) {
    await scanService.markNoticeAgreed();
  }
  if (!context.mounted) return false;

  // ③④ 拍照／上傳 → 辨識 → 確認存入
  final bool? saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (BuildContext routeContext) => ScanPolicyScreen(
        customerId: customerChoice!.customerId,
        customerName: customerChoice.customerName,
      ),
    ),
  );
  return saved ?? false;
}

Future<ScanCustomerChoice?> _pickCustomer(BuildContext context) async {
  List<Map<String, dynamic>> customers = [];
  try {
    customers = await CustomerPolicyService().fetchMyCustomersForEnroll();
  } catch (error) {
    if (context.mounted) {
      CustomToast.show(context, '讀取客戶資料失敗，請稍後再試', ToastType.error);
    }
    return null;
  }
  if (!context.mounted) return null;
  return showScanCustomerPickerDialog(context, customers);
}
