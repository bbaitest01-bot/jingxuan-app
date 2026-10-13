import 'package:flutter/material.dart';
import 'visit_record_detail_view.dart';
import 'visit_record_list_view.dart';

/// 拜訪紀錄頁：網址沒有編號（/visit-records）顯示列表，有編號（/visit-records/:id）顯示單篇
class VisitRecordsPage extends StatelessWidget {
  final String? recordId;

  const VisitRecordsPage({super.key, this.recordId});

  @override
  Widget build(BuildContext context) {
    final String? id = recordId;
    if (id == null || id.isEmpty) return const VisitRecordListView();
    return VisitRecordDetailView(recordId: id);
  }
}
