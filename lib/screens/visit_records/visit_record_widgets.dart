import 'package:flutter/material.dart';
import '../../main.dart' show isOfflineMode;
import '../../models/visit_record.dart';
import '../../services/visit_record_service.dart';
import '../../widgets/custom_toast.dart';
import '../../widgets/voice_recorder_widget.dart';
import '../../theme/app_theme.dart';

/// 寬度小於這個值（手機）時，標題列的按鈕換到下一行
const double visitRecordNarrowWidth = 640;

/// 例：2026/10/14 15:30
String formatVisitRecordTime(DateTime time) {
  final String month = time.month.toString().padLeft(2, '0');
  final String day = time.day.toString().padLeft(2, '0');
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '${time.year}/$month/$day $hour:$minute';
}

/// 處理狀態的小標籤（尚未整理／整理中／完成／失敗）
class VisitRecordStatusChip extends StatelessWidget {
  final VisitRecord record;

  const VisitRecordStatusChip({super.key, required this.record});

  Color _statusColor(BuildContext context) {
    // 整理中卡住超過 5 分鐘，跟失敗一樣用紅色
    if (record.isOrganizeStale(DateTime.now())) return Theme.of(context).colorScheme.error;
    switch (record.status) {
      case VisitRecord.statusProcessing:
        return Theme.of(context).colorScheme.primary;
      case VisitRecord.statusDone:
        return context.appColors.ok;
      case VisitRecord.statusFailed:
        return Theme.of(context).colorScheme.error;
      default:
        return context.appColors.ink3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _statusColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        record.isOrganizeStale(DateTime.now()) ? '失敗' : record.statusLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

/// 「新增拜訪紀錄」視窗：標題（預設日期時間）＋內容。建立成功回傳新紀錄，取消回傳 null
Future<VisitRecord?> showCreateVisitRecordDialog(BuildContext context) {
  return showDialog<VisitRecord>(
    context: context,
    builder: (BuildContext dialogContext) => const _CreateVisitRecordDialog(),
  );
}

class _CreateVisitRecordDialog extends StatefulWidget {
  const _CreateVisitRecordDialog();

  @override
  State<_CreateVisitRecordDialog> createState() => _CreateVisitRecordDialogState();
}

class _CreateVisitRecordDialogState extends State<_CreateVisitRecordDialog> {
  late final TextEditingController _titleController;
  final TextEditingController _contentController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: VisitRecord.defaultTitle(DateTime.now()));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_contentController.text.trim().isEmpty) {
      CustomToast.show(context, '請輸入拜訪內容', ToastType.warning);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final VisitRecord record = await VisitRecordService.instance.createRecord(
        title: _titleController.text,
        rawTranscript: _contentController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(record);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomToast.show(context, '建立失敗：$e', ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('新增拜訪紀錄', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                maxLength: VisitRecordService.maxTitleLength,
                decoration: InputDecoration(
                  labelText: '標題',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                autofocus: true,
                minLines: 6,
                maxLines: 12,
                decoration: InputDecoration(
                  labelText: '拜訪內容',
                  hintText: '例如：今天拜訪王先生，討論醫療險…',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: context.appColors.onAcc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_isSaving ? '建立中…' : '建立'),
        ),
      ],
    );
  }
}

/// 「錄音新增」視窗：錄音 → 轉文字 → 自動建立一篇（內容放在原始轉錄）。建立成功回傳新紀錄
Future<VisitRecord?> showRecordVisitRecordDialog(BuildContext context) {
  return showDialog<VisitRecord>(
    context: context,
    barrierDismissible: false, // 錄音中不要點外面就關掉
    builder: (BuildContext dialogContext) => const _RecordVisitRecordDialog(),
  );
}

class _RecordVisitRecordDialog extends StatefulWidget {
  const _RecordVisitRecordDialog();

  @override
  State<_RecordVisitRecordDialog> createState() => _RecordVisitRecordDialogState();
}

class _RecordVisitRecordDialogState extends State<_RecordVisitRecordDialog> {
  // 拜訪紀錄最長錄 10 分鐘（問題 R5 長錄音實測後可調整）
  static const int _maxRecordingSeconds = 600;
  bool _isCreating = false;

  Future<void> _createFromTranscript(String transcript) async {
    setState(() => _isCreating = true);
    try {
      // 錄音建立的紀錄一開始就是「整理中」，接著在背景送去 AI 整理（4-E1，沛沛決定錄音才自動整理）
      final VisitRecord record = await VisitRecordService.instance.createRecord(
        title: VisitRecord.defaultTitle(DateTime.now()),
        rawTranscript: transcript,
        startOrganizing: !isOfflineMode,
      );
      if (!isOfflineMode) VisitRecordService.instance.startOrganizeInBackground(record.id);
      if (!mounted) return;
      Navigator.of(context).pop(record);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      CustomToast.show(context, '建立失敗：$e', ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('錄音新增拜訪紀錄', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '按「錄音」開始說話，說完按「停止」，會自動轉成文字並建立一篇紀錄。最長 10 分鐘。',
              style: TextStyle(fontSize: 13, color: context.appColors.ink3, height: 1.5),
            ),
            const SizedBox(height: 16),
            if (_isCreating)
              const Row(
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('建立紀錄中…'),
                ],
              )
            else
              VoiceRecorderWidget(
                primaryColor: primaryColor,
                isDark: isDark,
                maxRecordingSeconds: _maxRecordingSeconds,
                onTranscribed: _createFromTranscript,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}
