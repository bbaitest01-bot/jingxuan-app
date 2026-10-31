import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/visit_record.dart';
import '../../router/app_routes.dart';
import '../../services/visit_record_service.dart';
import '../../widgets/custom_toast.dart';
import 'visit_record_widgets.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tour_target.dart';

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
    _openCreatedRecord(record);
  }

  Future<void> _recordNewRecord() async {
    final VisitRecord? record = await showRecordVisitRecordDialog(context);
    _openCreatedRecord(record);
  }

  // 建立成功就打開那篇
  void _openCreatedRecord(VisitRecord? record) {
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

  // 按鈕列：頁首已經顯示「拜訪紀錄」，這裡不再重複標題（2026-10-14 沛沛）；
  // 按鈕放不下時自動換行（手機），重新整理固定在右邊
  Widget _buildHeader(Color primaryColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 新手導覽第 7 步亮這兩顆按鈕
              TourTarget(
                id: 'visitRecords.add',
                child: Wrap(spacing: 8, runSpacing: 8, children: _buildAddButtons(primaryColor)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '重新整理',
          onPressed: _isLoading ? null : _loadRecords,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  // 錄音新增、新增紀錄兩顆按鈕
  List<Widget> _buildAddButtons(Color primaryColor) {
    return [
              OutlinedButton.icon(
                onPressed: _recordNewRecord,
                icon: const Icon(Icons.mic_none, size: 18),
                label: const Text('錄音新增'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createRecord,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增紀錄'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: context.appColors.onAcc,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
    ];
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final String? errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Center(child: Text(errorMessage, style: TextStyle(color: Theme.of(context).colorScheme.error)));
    }
    // 新手導覽：沒有紀錄時亮這塊空白提示，不用等第一篇出現
    if (_records.isEmpty) return const TourTarget(id: 'visitRecords.empty', child: _VisitRecordEmptyState());

    return ListView.separated(
      itemCount: _records.length,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final VisitRecord record = _records[index];
        final Widget card = _VisitRecordCard(
          record: record,
          onTap: () => context.go(AppRoutes.visitRecordPath(record.id)),
        );
        // 新手導覽第 8 步亮第一篇
        if (index == 0) return TourTarget(id: 'visitRecords.first', child: card);
        return card;
      },
    );
  }
}

class _VisitRecordCard extends StatelessWidget {
  final VisitRecord record;
  final VoidCallback onTap;

  const _VisitRecordCard({required this.record, required this.onTap});

  // 卡片最下面：有連結客戶就顯示客戶名字，再接建立時間
  String _buildFooterText() {
    final String timeText = '建立於 ${formatVisitRecordTime(record.createdAt)}';
    final String? customerName = record.customerName;
    if (record.customerId == null || customerName == null) return timeText;
    return '👤 $customerName　·　$timeText';
  }

  @override
  Widget build(BuildContext context) {
    final Color subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? context.appColors.ink3;
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
                _buildFooterText(),
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
          Icon(Icons.record_voice_over_outlined, size: 64, color: context.appColors.ink3.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          const Text('還沒有拜訪紀錄', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('按右上角「錄音新增」或「新增紀錄」建立第一篇', style: TextStyle(fontSize: 13, color: context.appColors.ink3)),
        ],
      ),
    );
  }
}
