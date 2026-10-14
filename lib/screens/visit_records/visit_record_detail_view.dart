import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/visit_record.dart';
import '../../router/app_routes.dart';
import '../../services/visit_record_service.dart';
import '../../widgets/custom_toast.dart';
import 'visit_record_customer_picker.dart';
import 'visit_record_widgets.dart';

/// 單篇拜訪紀錄（/visit-records/:id）：左邊原始轉錄（不能改，一律保留），右邊整理後內容（可編輯）
class VisitRecordDetailView extends StatefulWidget {
  final String recordId;

  const VisitRecordDetailView({super.key, required this.recordId});

  @override
  State<VisitRecordDetailView> createState() => _VisitRecordDetailViewState();
}

class _VisitRecordDetailViewState extends State<VisitRecordDetailView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _organizedController = TextEditingController();
  VisitRecord? _record;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLinkingCustomer = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  @override
  void didUpdateWidget(covariant VisitRecordDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同一個畫面換成另一篇（例如之後從通知點進來）要重新讀
    if (oldWidget.recordId != widget.recordId) _loadRecord();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _organizedController.dispose();
    super.dispose();
  }

  Future<void> _loadRecord() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final VisitRecord? record = await VisitRecordService.instance.fetchRecord(widget.recordId);
      if (!mounted) return;
      if (record == null) {
        setState(() {
          _record = null;
          _isLoading = false;
        });
        return;
      }
      _titleController.text = record.title;
      _organizedController.text = record.organizedContent ?? '';
      setState(() {
        _record = record;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '讀取失敗：$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final VisitRecord updated = await VisitRecordService.instance.updateRecord(
        widget.recordId,
        title: _titleController.text,
        organizedContent: _organizedController.text,
      );
      if (!mounted) return;
      _titleController.text = updated.title;
      setState(() {
        _record = updated;
        _isSaving = false;
      });
      CustomToast.show(context, '已儲存', ToastType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToast.show(context, '儲存失敗：$e', ToastType.error);
    }
  }

  // 連結、更換或取消客戶（傳 null 是取消）；選了就立刻存，不用再按「儲存」
  Future<void> _changeCustomer(VisitRecord record, VisitCustomerOption? customer) async {
    setState(() => _isLinkingCustomer = true);
    try {
      final VisitRecord updated = await VisitRecordService.instance.updateCustomerLink(record, customer);
      if (!mounted) return;
      setState(() {
        _record = updated;
        _isLinkingCustomer = false;
      });
      final String message = customer == null ? '已取消連結客戶' : '已連結客戶「${customer.name}」';
      CustomToast.show(context, message, ToastType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLinkingCustomer = false);
      CustomToast.show(context, '連結客戶失敗：$e', ToastType.error);
    }
  }

  Future<void> _chooseCustomer(VisitRecord record) async {
    final VisitCustomerOption? customer = await showVisitCustomerPicker(context);
    if (customer == null || !mounted) return;
    await _changeCustomer(record, customer);
  }

  // 整理後內容還空著時，可以先把原始轉錄複製過來再修改
  void _copyRawToOrganized(VisitRecord record) {
    _organizedController.text = record.rawTranscript;
    CustomToast.show(context, '已複製原始轉錄，修改後記得按「儲存」', ToastType.success);
  }

  void _backToList() => context.go(AppRoutes.visitRecords);

  // 刪除：先確認，再移到垃圾桶（30 天內可還原），回到列表
  Future<void> _confirmDelete(VisitRecord record) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('刪除拜訪紀錄'),
        content: Text('「${record.title}」會移到垃圾桶，30 天內可以從垃圾桶還原。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await VisitRecordService.instance.moveToTrash(record.id);
      if (!mounted) return;
      CustomToast.show(context, '拜訪紀錄已移到垃圾桶', ToastType.warning);
      _backToList();
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, '刪除失敗：$e', ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final String? errorMessage = _errorMessage;
    if (errorMessage != null) return _buildMessage(errorMessage);
    final VisitRecord? record = _record;
    if (record == null) return _buildMessage('找不到這篇拜訪紀錄（可能已刪除或不是你的紀錄）');

    final bool isWide = MediaQuery.of(context).size.width >= 900;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(record),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                maxLength: VisitRecordService.maxTitleLength,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: '標題',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              VisitRecordCustomerSection(
                record: record,
                isBusy: _isLinkingCustomer,
                onChoose: () => _chooseCustomer(record),
                onClear: () => _changeCustomer(record, null),
              ),
              const SizedBox(height: 16),
              _buildContentPanels(record, isWide),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(VisitRecord record) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        TextButton.icon(
          onPressed: _backToList,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('返回列表'),
        ),
        const SizedBox(width: 8),
        VisitRecordStatusChip(record: record),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '建立於 ${formatVisitRecordTime(record.createdAt)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        TextButton.icon(
          onPressed: _isSaving ? null : () => _confirmDelete(record),
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
          label: const Text('刪除', style: TextStyle(color: Colors.redAccent)),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(_isSaving ? '儲存中…' : '儲存'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // 電腦版左右並排、手機版上下排列
  Widget _buildContentPanels(VisitRecord record, bool isWide) {
    final Widget rawPanel = _ContentPanel(
      title: '原始轉錄',
      subtitle: '錄音或建立時的原文，不會被修改',
      child: SelectableText(
        record.rawTranscript.isEmpty ? '（沒有內容）' : record.rawTranscript,
        style: const TextStyle(fontSize: 14, height: 1.6),
      ),
    );
    final Widget organizedPanel = _ContentPanel(
      title: '整理後內容',
      subtitle: '可以自己整理；之後接上自動整理也會放在這裡',
      action: TextButton(
        onPressed: () => _copyRawToOrganized(record),
        child: const Text('複製原始轉錄'),
      ),
      child: TextField(
        controller: _organizedController,
        minLines: 10,
        maxLines: null,
        decoration: InputDecoration(
          hintText: '還沒有整理後內容',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );

    if (!isWide) {
      return Column(children: [rawPanel, const SizedBox(height: 16), organizedPanel]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: rawPanel),
        const SizedBox(width: 16),
        Expanded(child: organizedPanel),
      ],
    );
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _backToList,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('返回拜訪紀錄列表'),
          ),
        ],
      ),
    );
  }
}

/// 內容區塊外框：標題、說明、右上角按鈕、內容
class _ContentPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _ContentPanel({required this.title, required this.subtitle, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final Widget? actionWidget = action;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                if (actionWidget != null) actionWidget,
              ],
            ),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
