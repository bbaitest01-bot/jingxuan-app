import 'package:flutter/material.dart';
import '../../models/visit_record.dart';

/// 單篇頁上方的 AI 整理狀態（4-E1，R8）：
/// 整理中 → 轉圈說明；失敗或卡住超過 5 分鐘 → 原因＋「重新整理」；完成 → 一行小字。
/// 尚未整理（打字建立的紀錄）不顯示
class VisitRecordOrganizeBanner extends StatelessWidget {
  final VisitRecord record;
  final bool isRequesting;
  final VoidCallback onRetry;

  const VisitRecordOrganizeBanner({super.key, required this.record, required this.isRequesting, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    if (record.isOrganizeFailed(now)) return _buildFailed(context, now);
    if (record.isProcessing) return _buildProcessing(context);
    if (record.status == VisitRecord.statusDone) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('✓ 已由 AI 整理到「整理後內容」，可以再自己修改', style: TextStyle(fontSize: 13, color: Colors.green)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildProcessing(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return _BannerBox(
      color: primaryColor,
      children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('AI 整理中…完成後會自動出現在「整理後內容」（通常幾秒到一分鐘，可以先離開這頁）'),
        ),
      ],
    );
  }

  Widget _buildFailed(BuildContext context, DateTime now) {
    String reason = record.failureReason ?? '';
    if (record.isOrganizeStale(now)) reason = '超過 5 分鐘沒有完成';
    if (reason.isEmpty) reason = '原因不明';
    return _BannerBox(
      color: Colors.redAccent,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent),
        const SizedBox(width: 12),
        Expanded(child: Text('AI 整理失敗：$reason。原始轉錄都還在，可以重新整理。')),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: isRequesting ? null : onRetry,
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(isRequesting ? '送出中…' : '重新整理'),
        ),
      ],
    );
  }
}

class _BannerBox extends StatelessWidget {
  final Color color;
  final List<Widget> children;

  const _BannerBox({required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: children),
    );
  }
}
