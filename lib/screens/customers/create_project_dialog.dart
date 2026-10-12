import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/app_localizations.dart';
import '../../services/app_settings.dart';
import '../../services/customer_service.dart';
import '../../widgets/custom_toast.dart';

/// 決定要為哪些客戶建立專案：有勾選就用勾選的，沒有就用目前篩選結果；都沒有就提示並停止
void showCreateProjectForCustomers(
  BuildContext outerContext, {
  required List<Map<String, dynamic>> allCustomers,
  required List<Map<String, dynamic>> filteredCustomers,
  required Set<String> selectedCustomerIds,
  required VoidCallback onCreated,
}) {
  final List<Map<String, dynamic>> targetCustomers = selectedCustomerIds.isNotEmpty
      ? allCustomers.where((c) => selectedCustomerIds.contains(c['id'].toString())).toList()
      : filteredCustomers;

  if (targetCustomers.isEmpty) {
    CustomToast.show(outerContext, '目前未選取目標客戶，請先勾選或篩選客戶', ToastType.warning);
    return;
  }

  showCreateProjectDialog(
    outerContext,
    targetCustomers: targetCustomers,
    filteredCount: filteredCustomers.length,
    onCreated: onCreated,
  );
}

/// 為選取（或篩選）的客戶建立拜訪專案的視窗。
/// 建立成功後呼叫 [onCreated]（外框用來結束多選），再關閉視窗。
void showCreateProjectDialog(
  BuildContext outerContext, {
  required List<Map<String, dynamic>> targetCustomers,
  required int filteredCount,
  required VoidCallback onCreated,
}) {
  final isDark = Theme.of(outerContext).brightness == Brightness.dark;
  final primaryColor = AppSettings.instance.primaryColor;
  final Color dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
  final Color textColor = isDark ? Colors.white : Colors.black87;
  final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

  final titleController = TextEditingController();
  final purposeController = TextEditingController();

  InputDecoration buildInputDecoration(String labelText, IconData iconData, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: subTextColor, fontSize: 13),
      hintText: hintText,
      hintStyle: TextStyle(color: subTextColor, fontSize: 13),
      prefixIcon: Icon(iconData, color: primaryColor, size: 18),
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
    );
  }

  showDialog(
    context: outerContext,
    builder: (context) {
      bool isSubmitting = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submitProject() async {
            final title = titleController.text.trim();
            final purpose = purposeController.text.trim();

            if (title.isEmpty || purpose.isEmpty) {
              CustomToast.show(context, '專案標題與建立目的為必填欄位', ToastType.warning);
              return;
            }

            setDialogState(() {
              isSubmitting = true;
            });

            try {
              if (isOfflineMode) {
                await CustomerService.instance.createOfflineVisitProject(
                  title: title,
                  purpose: purpose,
                  customers: targetCustomers,
                );
              } else {
                await CustomerService.instance.createVisitProject(
                  title: title,
                  purpose: purpose,
                  customers: targetCustomers,
                );
              }

              if (outerContext.mounted) {
                onCreated();
                final String offlineSuffix = isOfflineMode ? ' (離線暫存)' : '';
                CustomToast.show(context, '已成功為 ${targetCustomers.length} 筆客戶建立「$title」拜訪專案$offlineSuffix', ToastType.success);
                Navigator.pop(context);
              }
            } catch (e) {
              if (outerContext.mounted) {
                final String failurePrefix = isOfflineMode ? '建立失敗' : '建立專案失敗';
                CustomToast.show(context, '$failurePrefix: $e', ToastType.error);
              }
            } finally {
              setDialogState(() {
                isSubmitting = false;
              });
            }
          }

          return AlertDialog(
            backgroundColor: dialogBg,
            title: Text(
              context.l10n('pv_dialog_title'),
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, color: primaryColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppSettings.instance.language == 'en_US'
                                  ? 'Selected Customers: $filteredCount\n(This list will be used as the visit checklist)'
                                  : '已篩選客戶數：$filteredCount 位\n(專案將以此名單作為拜訪 Checklist)',
                              style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: textColor),
                      textInputAction: TextInputAction.next,
                      decoration: buildInputDecoration(context.l10n('pv_name_label'), Icons.assignment_outlined),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: purposeController,
                      style: TextStyle(color: textColor),
                      maxLines: 3,
                      decoration: buildInputDecoration(context.l10n('pv_purpose_label'), Icons.ads_click_outlined),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: Text(context.l10n('cancel'), style: TextStyle(color: subTextColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting ? null : submitProject,
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(context.l10n('pv_confirm_create')),
              ),
            ],
          );
        },
      );
    },
  );
}
