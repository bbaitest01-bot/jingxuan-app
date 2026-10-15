import 'package:flutter/material.dart';
import '../../services/customer_service.dart';
import '../../services/visit_pending_service.dart';
import '../customers/customer_status_widgets.dart';

const List<String> _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

/// 行程日期的說法：今天、昨天，其餘「10/13（一）」
String friendlyEventDate(DateTime date, DateTime today) {
  final DateTime day = DateUtils.dateOnly(date);
  final DateTime todayDate = DateUtils.dateOnly(today);
  if (day == todayDate) return '今天';
  if (day == todayDate.subtract(const Duration(days: 1))) return '昨天';
  return '${day.month}/${day.day}（${_weekdayNames[day.weekday - 1]}）';
}

String _timeText(DateTime time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// 專案拜訪頁上方：「還沒記錄結果」與「已記錄（最近 7 天）」（4-2c）。兩個都空就不顯示
class VisitPendingSection extends StatelessWidget {
  final PendingVisitLists lists;
  final DateTime today;
  final ValueChanged<PendingVisitEvent> onRecord;
  final ValueChanged<PendingVisitEvent> onSkip;
  final ValueChanged<PendingVisitEvent> onUndoSkip;
  final ValueChanged<PendingVisitEvent> onEditResult;

  const VisitPendingSection({
    super.key,
    required this.lists,
    required this.today,
    required this.onRecord,
    required this.onSkip,
    required this.onUndoSkip,
    required this.onEditResult,
  });

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('還沒記錄結果（${lists.pending.length}）', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '最近 30 天、有選客戶的行程，時間到了還沒記錄結果就會留在這裡。',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
            if (lists.pending.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('都記錄完了 👍')),
            ..._buildPendingRows(),
            if (lists.recentlyDone.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('已記錄（最近 7 天）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ..._buildDoneRows(context),
            ],
          ],
        ),
      ),
    );
  }

  // 依日期分組：每換一天先放一個小標題
  List<Widget> _buildPendingRows() {
    final List<Widget> rows = [];
    String lastDateLabel = '';
    for (final PendingVisitEvent event in lists.pending) {
      final String dateLabel = friendlyEventDate(event.startAt, today);
      if (dateLabel != lastDateLabel) {
        final bool isOverdue = DateUtils.dateOnly(event.startAt).isBefore(DateUtils.dateOnly(today));
        rows.add(_DateHeader(text: isOverdue ? '$dateLabel・過期未記錄' : dateLabel));
        lastDateLabel = dateLabel;
      }
      rows.add(_EventRow(
        event: event,
        timeLabel: _timeText(event.startAt),
        actions: [
          TextButton(onPressed: () => onSkip(event), child: const Text('沒拜訪')),
          FilledButton(
            onPressed: () => onRecord(event),
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('記錄結果'),
          ),
        ],
      ));
    }
    return rows;
  }

  List<Widget> _buildDoneRows(BuildContext context) {
    final List<Widget> rows = [];
    for (final PendingVisitEvent event in lists.recentlyDone) {
      final List<Widget> actions = [];
      if (event.isRecorded) {
        final String status = event.result ?? '';
        actions.add(Text(
          '已記錄 ${CustomerService.clientStatusSymbol(status)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: customerStatusColor(status)),
        ));
        actions.add(TextButton(onPressed: () => onEditResult(event), child: const Text('修改')));
      } else {
        actions.add(Text('沒拜訪', style: TextStyle(color: Theme.of(context).hintColor)));
        actions.add(TextButton(onPressed: () => onUndoSkip(event), child: const Text('復原')));
      }
      rows.add(_EventRow(
        event: event,
        timeLabel: '${friendlyEventDate(event.startAt, today)} ${_timeText(event.startAt)}',
        actions: actions,
      ));
    }
    return rows;
  }
}

class _DateHeader extends StatelessWidget {
  final String text;

  const _DateHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).hintColor)),
    );
  }
}

/// 一個行程一列：時間、客戶、行程標題，右邊放按鈕（窄螢幕時按鈕換到下一行）
class _EventRow extends StatelessWidget {
  final PendingVisitEvent event;
  final String timeLabel;
  final List<Widget> actions;

  const _EventRow({required this.event, required this.timeLabel, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$timeLabel  ', style: TextStyle(color: Theme.of(context).hintColor)),
              TextSpan(text: event.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: '  ${event.title}', style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
            ])),
          ),
          Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
        ],
      ),
    );
  }
}
