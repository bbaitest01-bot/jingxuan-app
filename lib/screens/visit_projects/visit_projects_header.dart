import 'package:flutter/material.dart';

/// 專案拜訪頁的三個分頁（沛沛 2026-10-16 決定）
class VisitProjectsTab {
  static const int overview = 0; // 總覽：成效圖表＋我的專案
  static const int pending = 1; // 待記錄：還沒記錄結果＋已記錄（最近 7 天）
  static const int results = 2; // 拜訪紀錄：所有拜訪結果
}

/// 頁面上方：說明與「建立專案」「記錄拜訪」按鈕（頁首已顯示「專案拜訪」，這裡不重複放標題）
class VisitProjectsHeader extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onRecord;

  const VisitProjectsHeader({super.key, required this.onCreate, required this.onRecord});

  @override
  Widget build(BuildContext context) {
    // 外層給滿寬，兩端對齊才會生效（說明在左、按鈕在右）
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '設定拜訪目標，追蹤每一期的進度',
            style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('建立專案'),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              FilledButton.icon(
                onPressed: onRecord,
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('記錄拜訪'),
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 分頁列：總覽／待記錄（N）／拜訪紀錄；選到的那個底下有主題色底線
class VisitProjectsTabBar extends StatelessWidget {
  final int selectedIndex;
  final int pendingCount;
  final ValueChanged<int> onChanged;

  const VisitProjectsTabBar({super.key, required this.selectedIndex, required this.pendingCount, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final List<String> labels = ['總覽', '待記錄（$pendingCount）', '拜訪紀錄'];
    final List<Widget> tabs = [];
    for (int index = 0; index < labels.length; index++) {
      tabs.add(_TabButton(label: labels[index], isSelected: index == selectedIndex, onTap: () => onChanged(index)));
    }
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: tabs),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? primaryColor : Colors.transparent, width: 3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? primaryColor : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }
}
