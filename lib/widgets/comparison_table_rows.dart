import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'benefit_item_comparison.dart';
import 'benefit_plan_comparison.dart';

/// 保單比較表的區塊標題與一列（從 policy_comparison_screen.dart 拆出，維持 500 行內）

class ComparisonSectionHeader extends StatelessWidget {
  final String title;

  const ComparisonSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: colors.surface2,
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.ink3)),
    );
  }
}

class ComparisonSpecRow extends StatelessWidget {
  final String label;
  final String value;
  // 給付項目的格子：點了看條款原文；其他格子是 null
  final VoidCallback? onTap;

  const ComparisonSpecRow({super.key, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    // 沒有資料（—）、不是實支實付、不分項目的格子用淡色，和真實數字區分
    Color valueColor = colors.ink;
    FontWeight valueWeight = FontWeight.bold;
    final bool isPlaceholder = value.startsWith('—') ||
        value == notReimbursementText ||
        value == notItemizedText ||
        value == benefitItemNotIncludedText;
    if (isPlaceholder) {
      valueColor = colors.ink3;
      valueWeight = FontWeight.normal;
    }

    // 兩行的格子（金額＋算法、算法＋每萬元換算）：第一行粗體是重點，第二行小字補充
    final int lineBreak = value.indexOf('\n');
    String mainText = value;
    String? detailText;
    if (lineBreak != -1) {
      mainText = value.substring(0, lineBreak);
      detailText = value.substring(lineBreak + 1);
    }
    final List<Widget> valueLines = [
      Text(mainText, style: TextStyle(fontSize: 11.5, fontWeight: valueWeight, color: valueColor)),
    ];
    if (detailText != null) {
      valueLines.add(Text(detailText, style: TextStyle(fontSize: 10.5, color: colors.ink3)));
    }

    final List<Widget> rowChildren = [
      SizedBox(width: 92, child: Text(label, style: TextStyle(fontSize: 11, color: colors.ink3))),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: valueLines),
      ),
    ];
    // 可以點的格子（給付項目）後面加一個小圖示，提示可看原文
    if (onTap != null) {
      rowChildren.add(Icon(Icons.article_outlined, size: 13, color: colors.ink3));
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line, width: 0.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowChildren),
      ),
    );
  }
}
