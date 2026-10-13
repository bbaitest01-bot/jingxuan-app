import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/visit_record.dart';
import '../../router/app_routes.dart';
import '../../services/visit_record_service.dart';
import '../../widgets/custom_toast.dart';
import 'visit_record_widgets.dart';

/// 拜訪紀錄列表（/visit-records）：新到舊，點一篇打開單篇頁
class VisitRecordListView extends StatefulWidget {
  const VisitRecordListView({super.key});

  @override
  State<VisitRecordListView> createState() => _VisitRecordListViewState();
}

class _VisitRecordListViewState extends State<VisitRecordListView> {
  List<VisitRecord> _records = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<VisitRecord> records = await VisitRecordService.instance.fetchMyRecords();
      if (!mounted) return;
      setState(() {
        _records = records;
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

  Future<void> _createRecord() async {
    final VisitRecord? record = await showCreateVisitRecordDialog(context);
    if (record == null || !mounted) return;
    CustomToast.show(context, '已建立拜訪紀錄', ToastType.success);
    context.go(AppRoutes.visitRecordPath(record.id));
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(primaryColor),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Row(
      children: [
        Icon(Icons.record_voice_over_outlined, color: primaryColor, size: 28),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('拜訪紀錄', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          tooltip: '重新整理',
          onPressed: _isLoading ? null : _loadRecords,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _createRecord,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('新增紀錄'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final String? errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.redAccent)));
    }
    if (_records.isEmpty) return const _VisitRecordEmptyState();

    return ListView.separated(
      itemCount: _records.length,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final VisitRecord record = _records[index];
        return _VisitRecordCard(
          record: record,
          onTap: () => context.go(AppRoutes.visitRecordPath(record.id)),
        );
      },
    );
  }
}

class _VisitRecordCard extends StatelessWidget {
  final VisitRecord record;
  final VoidCallback onTap;

  const _VisitRecordCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  VisitRecordStatusChip(record: record),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                record.previewText,
                style: TextStyle(fontSize: 13, color: subTextColor, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '建立於 ${formatVisitRecordTime(record.createdAt)}',
                style: TextStyle(fontSize: 11, color: subTextColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitRecordEmptyState extends StatelessWidget {
  const _VisitRecordEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.record_voice_over_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('還沒有拜訪紀錄', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('按右上角「新增紀錄」寫下第一篇', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}
