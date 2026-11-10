import 'package:flutter/material.dart';
import '../../models/visit_record.dart';
import '../../models/visit_record_insights.dart';
import '../../theme/app_theme.dart';

/// 單篇頁的「重點」與「待辦草稿」區塊（全景地圖 4-Q）。
/// AI 整理的內容都只是建議：待辦要使用者按「建立行程」並儲存才會生效。
class VisitRecordInsightsPanel extends StatelessWidget {
  final VisitRecord record;
  // 正在更新狀態的草稿編號；更新中的那筆按鈕先停用
  final String? busyDraftId;
  final ValueChanged<VisitFollowUpDraft> onCreateEvent;
  final ValueChanged<VisitFollowUpDraft> onDismiss;

  const VisitRecordInsightsPanel({
    super.key,
    required this.record,
    required this.onCreateEvent,
    required this.onDismiss,
    this.busyDraftId,
  });

  @override
  Widget build(BuildContext context) {
    // 整理中先不顯示，重新整理時才不會看到上一次的結果
    if (record.isOrganizeRunning(DateTime.now())) return const SizedBox.shrink();

    final VisitKeyPoints? keyPoints = record.keyPoints;
    final bool hasKeyPoints = keyPoints != null && !keyPoints.isEmpty;
    final List<VisitFollowUpDraft> visibleDrafts = [];
    for (final VisitFollowUpDraft draft in record.followUpDrafts) {
      if (draft.isPending || draft.isAccepted) visibleDrafts.add(draft);
    }
    if (!hasKeyPoints && visibleDrafts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasKeyPoints) _KeyPointsCard(keyPoints: keyPoints),
          if (hasKeyPoints && visibleDrafts.isNotEmpty) const SizedBox(height: 12),
          if (visibleDrafts.isNotEmpty) _buildDraftsCard(context, visibleDrafts),
        ],
      ),
    );
  }

  Widget _buildDraftsCard(BuildContext context, List<VisitFollowUpDraft> drafts) {
    return _InsightCard(
      title: '待辦草稿',
      subtitle: 'AI 從內容找出的下一步，建立前請確認時間',
      children: [
        for (final VisitFollowUpDraft draft in drafts)
          _FollowUpDraftRow(
            draft: draft,
            isBusy: busyDraftId == draft.draftId,
            onCreateEvent: () => onCreateEvent(draft),
            onDismiss: () => onDismiss(draft),
          ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _InsightCard({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: context.appColors.ink3)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _KeyPointsCard extends StatelessWidget {
  final VisitKeyPoints keyPoints;

  const _KeyPointsCard({required this.keyPoints});

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      title: '重點',
      subtitle: '由 AI 整理，請以原始轉錄為準',
      children: [
        _KeyPointRow(label: '訪談對象', text: keyPoints.interviewee),
        _KeyPointRow(label: '客戶需求', text: keyPoints.needs.join('、')),
        _KeyPointRow(label: '體況疑慮', text: keyPoints.healthConcerns.join('、')),
        _KeyPointRow(label: '提到的險種', text: keyPoints.insuranceMentioned.join('、')),
        _KeyPointRow(label: '後續行動', text: keyPoints.nextSteps.join('、')),
      ],
    );
  }
}

class _KeyPointRow extends StatelessWidget {
  final String label;
  final String text;

  const _KeyPointRow({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: TextStyle(fontSize: 13, color: context.appColors.ink3)),
          ),
          Expanded(child: SelectableText(text, style: const TextStyle(fontSize: 14, height: 1.5))),
        ],
      ),
    );
  }
}

class _FollowUpDraftRow extends StatelessWidget {
  final VisitFollowUpDraft draft;
  final bool isBusy;
  final VoidCallback onCreateEvent;
  final VoidCallback onDismiss;

  const _FollowUpDraftRow({
    required this.draft,
    required this.isBusy,
    required this.onCreateEvent,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final Widget description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(draft.whenLabel, style: AppTextStyles.mono(fontSize: 13, color: context.appColors.ink2)),
        const SizedBox(height: 2),
        Text(draft.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        if (draft.location != null)
          Text(draft.location ?? '', style: TextStyle(fontSize: 12, color: context.appColors.ink3)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        spacing: 12,
        children: [
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: description),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (draft.isAccepted) {
      return Text('✓ 已建立行程', style: TextStyle(fontSize: 13, color: context.appColors.ok));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(onPressed: isBusy ? null : onDismiss, child: const Text('略過')),
        const SizedBox(width: 4),
        FilledButton(
          onPressed: isBusy ? null : onCreateEvent,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: const Text('建立行程'),
        ),
      ],
    );
  }
}
