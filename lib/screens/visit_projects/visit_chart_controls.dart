import 'package:flutter/material.dart';
import '../../models/visit_chart.dart';
import '../../models/visit_result.dart';

/// 「按標籤」下拉選單的一組：大分類＋底下的標籤
class VisitChartTagGroup {
  final String categoryName;
  final List<String> tagNames;

  const VisitChartTagGroup({required this.categoryName, required this.tagNames});
}

/// 圖例的一項：一條線的名稱、顏色、這一期合計、是否隱藏
class VisitChartLegendItem {
  final String id;
  final String name;
  final Color color;
  final int total;
  final bool isHidden;

  const VisitChartLegendItem({
    required this.id,
    required this.name,
    required this.color,
    required this.total,
    required this.isHidden,
  });
}

/// 圖表上方的切換：週／月／年、‹ 期間 ›、按結果／專案／標籤（＋標籤下拉）
class VisitChartControls extends StatelessWidget {
  final String range;
  final String mode;
  final String periodTitle;
  final bool canGoNext;
  final String tag;
  final List<VisitChartTagGroup> tagGroups;
  final ValueChanged<String> onRangeChanged;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<String> onTagChanged;

  const VisitChartControls({
    super.key,
    required this.range,
    required this.mode,
    required this.periodTitle,
    required this.canGoNext,
    required this.tag,
    required this.tagGroups,
    required this.onRangeChanged,
    required this.onModeChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onTagChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Column 改成撐滿寬度，底下兩列的「兩端對齊」才會生效：標題／期間在左，週月年／‹ › 在右
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('拜訪成效', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: VisitChartRange.week, label: Text('週')),
                ButtonSegment<String>(value: VisitChartRange.month, label: Text('月')),
                ButtonSegment<String>(value: VisitChartRange.year, label: Text('年')),
              ],
              selected: {range},
              showSelectedIcon: false,
              onSelectionChanged: (Set<String> value) => onRangeChanged(value.first),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(value: VisitChartMode.byResult, label: Text('按結果')),
                    ButtonSegment<String>(value: VisitChartMode.byProject, label: Text('按專案')),
                    ButtonSegment<String>(value: VisitChartMode.byTag, label: Text('按標籤')),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<String> value) => onModeChanged(value.first),
                ),
                if (mode == VisitChartMode.byTag && tagGroups.isNotEmpty) _TagDropdown(tag: tag, groups: tagGroups, onChanged: onTagChanged),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left), tooltip: '上一期'),
                Text(periodTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(onPressed: canGoNext ? onNext : null, icon: const Icon(Icons.chevron_right), tooltip: '下一期'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// 標籤下拉：大分類當小標題（不能選），底下列標籤
class _TagDropdown extends StatelessWidget {
  final String tag;
  final List<VisitChartTagGroup> groups;
  final ValueChanged<String> onChanged;

  const _TagDropdown({required this.tag, required this.groups, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<String>> items = [];
    for (final VisitChartTagGroup group in groups) {
      items.add(DropdownMenuItem<String>(
        enabled: false,
        value: '__category_${group.categoryName}',
        child: Text(group.categoryName, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      ));
      for (final String name in group.tagNames) {
        items.add(DropdownMenuItem<String>(value: name, child: Text('　$name')));
      }
    }
    String? value;
    if (items.any((item) => item.value == tag)) value = tag;
    return DropdownButton<String>(
      value: value,
      items: items,
      hint: const Text('選擇標籤'),
      onChanged: (String? picked) {
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// 圖表上方一行小計，例：「這一期總共 18 次　✔ 5　△ 9　✖ 4」
class VisitChartSummary extends StatelessWidget {
  final String mode;
  final List<VisitChartLegendItem> items;
  final String tag;

  const VisitChartSummary({super.key, required this.mode, required this.items, required this.tag});

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> spans = [];
    if (mode == VisitChartMode.byTag && tag.isNotEmpty) {
      spans.add(TextSpan(text: '標籤「$tag」的客戶　', style: TextStyle(color: Theme.of(context).hintColor)));
    }
    for (final VisitChartLegendItem item in items) {
      if (item.id == 'total') {
        spans.insert(0, TextSpan(text: '這一期總共 ${item.total} 次　', style: const TextStyle(fontWeight: FontWeight.bold)));
        continue;
      }
      String label = item.name;
      // 結果只放符號，避免太長
      if (VisitChartLegend.isResultId(item.id)) label = item.name.split(' ').first;
      spans.add(TextSpan(text: '$label ${item.total}　', style: TextStyle(color: item.color, fontWeight: FontWeight.bold)));
    }
    return Text.rich(TextSpan(children: spans), style: const TextStyle(fontSize: 13));
  }
}

/// 圖例：點一下隱藏或顯示那條線
class VisitChartLegend extends StatelessWidget {
  final List<VisitChartLegendItem> items;
  final ValueChanged<String> onToggle;

  const VisitChartLegend({super.key, required this.items, required this.onToggle});

  static bool isResultId(String id) => VisitResult.resultOptions.contains(id);

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = [];
    for (final VisitChartLegendItem item in items) {
      chips.add(InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onToggle(item.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 3, color: item.isHidden ? Theme.of(context).disabledColor : item.color),
              const SizedBox(width: 6),
              Text(
                item.name,
                style: TextStyle(
                  fontSize: 13,
                  color: item.isHidden ? Theme.of(context).disabledColor : null,
                  decoration: item.isHidden ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ));
    }
    chips.add(Text('（點圖例可隱藏線條）', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)));
    return Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: chips);
  }
}
