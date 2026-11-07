import 'package:flutter/material.dart';

import '../../services/benefit_trial_calculator.dart';
import '../../services/scenario/claim_scenario.dart';
import '../../theme/app_theme.dart';

/// 比較頁每一欄上方的「這個情境大約可以拿」：大數字＋點開看明細＋算不出來的項目；實支實付可以選買幾張
class ScenarioResultCard extends StatefulWidget {
  final ClaimScenarioResult result;
  final String currencyUnit;
  final int copies;
  final ValueChanged<int> onCopiesChanged;

  const ScenarioResultCard({
    super.key,
    required this.result,
    required this.currencyUnit,
    required this.copies,
    required this.onCopiesChanged,
  });

  @override
  State<ScenarioResultCard> createState() => _ScenarioResultCardState();
}

class _ScenarioResultCardState extends State<ScenarioResultCard> {
  // 明細預設收起來，只看大數字
  bool _isExpanded = false;
  // 算不出來的項目太多時先顯示 3 項
  static const int _collapsedNoteCount = 3;
  bool _isShowingAllNotes = false;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final ClaimScenarioResult result = widget.result.timesCopies(widget.copies);
    final String? emptyReason = result.emptyReason;

    final List<Widget> children = [
      Text('這個情境大約可以拿', style: TextStyle(fontSize: 11, color: colors.ink3)),
    ];
    if (emptyReason != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(emptyReason, style: TextStyle(fontSize: 12, color: colors.ink2)),
      ));
    } else {
      children.add(_buildTotal(colors, result));
      if (_isExpanded) children.addAll(_buildLines(colors, result));
      if (result.notCounted.isNotEmpty) children.add(_buildNotCounted(colors, result.notCounted));
      if (result.canBuyMultipleCopies) children.add(_buildCopiesStepper(colors));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.accSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.acc),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  /// 「約 22 萬元」；有「至少」的項目加「起」；點一下展開明細
  Widget _buildTotal(AppColors colors, ClaimScenarioResult result) {
    String totalText = BenefitTrialCalculator.formatMoney(result.total.toDouble(), widget.currencyUnit);
    if (result.lines.isEmpty) totalText = '算不出來';
    String suffix = '';
    if (result.isMinimum || result.notCounted.isNotEmpty) suffix = ' 起';
    if (result.lines.isEmpty) suffix = '';
    return InkWell(
      onTap: result.lines.isEmpty ? null : () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(totalText, style: AppTextStyles.mono(fontSize: 20, fontWeight: FontWeight.bold, color: colors.acc)),
            Text(suffix, style: TextStyle(fontSize: 12, color: colors.acc)),
            const Spacer(),
            if (result.lines.isNotEmpty)
              Text(_isExpanded ? '收起明細' : '看明細', style: TextStyle(fontSize: 11, color: colors.acc)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLines(AppColors colors, ClaimScenarioResult result) {
    final List<Widget> lines = [Divider(height: 12, color: colors.line)];
    for (final ClaimScenarioLine line in result.lines) {
      lines.add(_ResultLine(line: line, currencyUnit: widget.currencyUnit));
    }
    return lines;
  }

  /// 黃色框：算不出來、沒加進去的項目（不猜）
  Widget _buildNotCounted(AppColors colors, List<String> notCounted) {
    final List<Widget> rows = [
      Text('算不出來、沒加進去：', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.warn)),
    ];
    int shownCount = notCounted.length;
    if (!_isShowingAllNotes && shownCount > _collapsedNoteCount) shownCount = _collapsedNoteCount;
    for (int index = 0; index < shownCount; index++) {
      rows.add(Text('・${notCounted[index]}', style: TextStyle(fontSize: 11, color: colors.warn)));
    }
    final int hiddenCount = notCounted.length - shownCount;
    if (hiddenCount > 0) {
      rows.add(InkWell(
        onTap: () => setState(() => _isShowingAllNotes = true),
        child: Text('還有 $hiddenCount 項，點開看', style: TextStyle(fontSize: 11, color: colors.acc)),
      ));
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: colors.warnSoft, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }

  /// 實支實付：買幾張（副本理賠，每張各自照上限賠）
  Widget _buildCopiesStepper(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('買幾張', style: TextStyle(fontSize: 12, color: colors.ink2)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '少一張',
                onPressed: widget.copies <= 1 ? null : () => widget.onCopiesChanged(widget.copies - 1),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
              ),
              Text('${widget.copies}', style: AppTextStyles.mono(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink)),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '多一張',
                onPressed: widget.copies >= 5 ? null : () => widget.onCopiesChanged(widget.copies + 1),
                icon: const Icon(Icons.add_circle_outline, size: 20),
              ),
            ],
          ),
          Text('副本理賠：每張各自照上限賠，以條款為準', style: TextStyle(fontSize: 10, color: colors.ink3)),
        ],
      ),
    );
  }
}

/// 明細的一行：左邊項目（下面小字提醒），右邊金額
class _ResultLine extends StatelessWidget {
  final ClaimScenarioLine line;
  final String currencyUnit;

  const _ResultLine({required this.line, required this.currencyUnit});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? note = line.note;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.label, style: TextStyle(fontSize: 12, color: colors.ink)),
                if (note != null) Text(note, style: TextStyle(fontSize: 10, color: colors.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(BenefitTrialCalculator.formatMoney(line.amount.toDouble(), currencyUnit),
              style: AppTextStyles.mono(fontSize: 12, color: colors.ink2)),
        ],
      ),
    );
  }
}
