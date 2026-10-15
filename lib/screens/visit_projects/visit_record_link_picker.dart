import 'package:flutter/material.dart';
import '../../models/visit_record.dart';
import '../../services/visit_record_service.dart';

/// 選一篇拜訪紀錄來連結（P5）。這位客戶的紀錄排在前面；可搜尋標題。選了回傳那一篇，取消回傳 null
Future<VisitRecord?> showVisitRecordLinkPicker(BuildContext context, {String customerId = ''}) {
  return showDialog<VisitRecord>(
    context: context,
    builder: (dialogContext) => _VisitRecordLinkPicker(customerId: customerId),
  );
}

class _VisitRecordLinkPicker extends StatefulWidget {
  final String customerId;

  const _VisitRecordLinkPicker({required this.customerId});

  @override
  State<_VisitRecordLinkPicker> createState() => _VisitRecordLinkPickerState();
}

class _VisitRecordLinkPickerState extends State<_VisitRecordLinkPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<VisitRecord> _records = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 讀自己的拜訪紀錄（不含垃圾桶）；連結這位客戶的排前面，其餘照原本新到舊
  Future<void> _loadRecords() async {
    try {
      final List<VisitRecord> records = await VisitRecordService.instance.fetchMyRecords();
      final List<VisitRecord> sameCustomer = records.where((record) => record.customerId == widget.customerId).toList();
      final List<VisitRecord> others = records.where((record) => record.customerId != widget.customerId).toList();
      if (!mounted) return;
      setState(() {
        _records = [...sameCustomer, ...others];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '讀取拜訪紀錄失敗：$e';
        _isLoading = false;
      });
    }
  }

  List<VisitRecord> _filtered() {
    final String keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return _records;
    return _records.where((record) => record.title.toLowerCase().contains(keyword)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('連結拜訪紀錄'),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋標題',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final String? errorMessage = _errorMessage;
    if (errorMessage != null) return Center(child: Text(errorMessage));
    if (_records.isEmpty) return const Center(child: Text('還沒有拜訪紀錄'));
    final List<VisitRecord> shown = _filtered();
    if (shown.isEmpty) return const Center(child: Text('找不到符合的紀錄'));

    return ListView.builder(
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final VisitRecord record = shown[index];
        final String customerName = record.customerName ?? '';
        final bool isSameCustomer = widget.customerId.isNotEmpty && record.customerId == widget.customerId;
        String subtitle = customerName.isEmpty ? '未連結客戶' : '客戶：$customerName';
        if (isSameCustomer) subtitle = '$subtitle（這位客戶）';
        return ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.record_voice_over_outlined),
          title: Text(record.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle),
          onTap: () => Navigator.pop(context, record),
        );
      },
    );
  }
}
