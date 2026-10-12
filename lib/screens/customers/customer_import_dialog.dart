import 'package:flutter/material.dart';
import '../../services/customer_service.dart';
import '../../widgets/batch_import_customers_dialog.dart';
import '../../widgets/custom_toast.dart';

/// 批次匯入 CSV／Excel：選檔與欄位對應在 BatchImportCustomersDialog；
/// 寫入資料庫由 CustomerService 負責。完成後呼叫 [onImported]（外框重新讀取客戶），再顯示結果。
void showCustomerImportDialog(
  BuildContext outerContext, {
  required List<Map<String, dynamic>> existingCustomers,
  required Future<void> Function() onImported,
}) {
  showDialog(
    context: outerContext,
    builder: (context) => BatchImportCustomersDialog(
      existingCustomers: existingCustomers,
      onImport: (importedList, duplicateStrategy) async {
        final CustomerImportResult result = await CustomerService.instance.importCustomers(
          importedList: importedList,
          duplicateStrategy: duplicateStrategy,
          existingCustomers: existingCustomers,
        );

        await onImported();
        if (outerContext.mounted) {
          if (result.failedCount > 0) {
            CustomToast.show(
              context,
              '⚠️ 批次處理完成：成功 ${result.processedCount} 筆，失敗 ${result.failedCount} 筆 (請檢查網路或權限)',
              ToastType.warning,
            );
          } else {
            CustomToast.show(
              context,
              '🎉 成功匯入並處理 ${result.processedCount} 筆客戶資料！',
              ToastType.success,
            );
          }
        }
      },
    ),
  );
}
