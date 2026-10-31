import 'package:flutter/material.dart';
import '../../services/account_deletion_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_toast.dart';

/// 系統設定「刪除帳號」的確認對話框（全景地圖 4-N）。
/// 先列出會被刪掉的資料筆數，使用者要自己輸入「刪除帳號」四個字，確認按鈕才會亮。
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  /// 打開對話框；不能刪除的帳號（示範、管理者）直接顯示原因，不打開
  static Future<void> show(BuildContext context) async {
    final String? blockedReason = AccountDeletionService.instance.deletionBlockedReason();
    if (blockedReason != null) {
      CustomToast.show(context, blockedReason, ToastType.warning);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => const DeleteAccountDialog(),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final TextEditingController _confirmController = TextEditingController();
  AccountDataSummary? _dataSummary;
  bool _isLoadingSummary = true;
  bool _isDeleting = false;

  bool get _isConfirmTextCorrect =>
      _confirmController.text.trim() == AccountDeletionService.confirmText;

  @override
  void initState() {
    super.initState();
    _loadDataSummary();
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  // 查筆數失敗不影響刪除，只是不顯示數字
  Future<void> _loadDataSummary() async {
    try {
      final AccountDataSummary summary = await AccountDeletionService.instance.fetchDataSummary();
      if (!mounted) return;
      setState(() => _dataSummary = summary);
    } catch (error) {
      debugPrint('查詢帳號資料筆數失敗: $error');
    } finally {
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    try {
      await AccountDeletionService.instance.deleteMyAccount(_confirmController.text);
      if (!mounted) return;
      // 登出後網址守門規則會自動回到登入頁；提示要在關掉對話框前取得 context
      CustomToast.show(context, '帳號與所有資料已刪除', ToastType.success);
      Navigator.of(context).pop();
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      CustomToast.show(context, error.message, ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color dangerColor = Theme.of(context).colorScheme.error;
    final bool canDelete = _isConfirmTextCorrect && !_isDeleting;

    return AlertDialog(
      backgroundColor: context.appColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: dangerColor),
          const SizedBox(width: 8),
          const Text('刪除帳號'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '刪除後，下列資料會立即永久刪除，無法復原：',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            _DeletedDataList(summary: _dataSummary, isLoading: _isLoadingSummary),
            const SizedBox(height: 16),
            const Text(
              '請輸入「${AccountDeletionService.confirmText}」確認：',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              enabled: !_isDeleting,
              autofocus: true,
              decoration: const InputDecoration(hintText: AccountDeletionService.confirmText),
              onChanged: (String value) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          style: AppButtonStyles.danger(context),
          onPressed: canDelete ? _deleteAccount : null,
          child: _isDeleting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('永久刪除'),
        ),
      ],
    );
  }
}

/// 列出會被刪掉的資料；有筆數就顯示筆數
class _DeletedDataList extends StatelessWidget {
  final AccountDataSummary? summary;
  final bool isLoading;

  const _DeletedDataList({required this.summary, required this.isLoading});

  String _countText(int? count) {
    if (isLoading) return '…';
    if (count == null) return '';
    return '$count 筆';
  }

  @override
  Widget build(BuildContext context) {
    final List<_DeletedDataRow> rows = [
      _DeletedDataRow(label: '客戶（含保單、標籤、人脈、保障缺口）', countText: _countText(summary?.customerCount)),
      _DeletedDataRow(label: '行程', countText: _countText(summary?.scheduleCount)),
      _DeletedDataRow(label: '拜訪專案', countText: _countText(summary?.visitProjectCount)),
      _DeletedDataRow(label: '拜訪紀錄', countText: _countText(summary?.visitRecordCount)),
      const _DeletedDataRow(label: '通知、自訂標籤、個人名片', countText: ''),
      const _DeletedDataRow(label: '大頭照、名片 QR Code、客戶照片', countText: ''),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: context.appColors.line),
      ),
      child: Column(children: rows),
    );
  }
}

class _DeletedDataRow extends StatelessWidget {
  final String label;
  final String countText;

  const _DeletedDataRow({required this.label, required this.countText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.remove_circle_outline, size: 14, color: context.appColors.ink3),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(countText, style: AppTextStyles.mono(fontSize: 13)),
        ],
      ),
    );
  }
}
