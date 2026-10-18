import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 客戶管理「批量管理」模式下的多選操作列：全選、匯出、建立專案、移至垃圾桶、退出多選。
/// 電腦版（寬度 ≥ 768）單行排列；手機版上下兩層、三顆按鈕等寬。
class CustomerBatchSelectionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final ValueChanged<bool?> onSelectAllChanged;
  final VoidCallback onExport;
  final VoidCallback onCreateProject;
  final VoidCallback onBatchDelete;
  final VoidCallback onExitSelection;

  const CustomerBatchSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAllChanged,
    required this.onExport,
    required this.onCreateProject,
    required this.onBatchDelete,
    required this.onExitSelection,
  });

  @override
  Widget build(BuildContext context) {
    final int allFilteredCount = totalCount;
    final bool isAllSelected = selectedCount > 0 && selectedCount == allFilteredCount;
    final Color primaryColor = context.appColors.acc;
    final bool isWideScreen = MediaQuery.of(context).size.width >= 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 20 : 14,
        vertical: isWideScreen ? 10 : 12,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        // 浮在清單上方的工具列：白底、細框、淡陰影（原本是深藍底＋發光框）
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isWideScreen
          ? Row(
              children: [
                Checkbox(
                  value: isAllSelected,
                  onChanged: onSelectAllChanged,
                  activeColor: context.appColors.acc,
                ),
                const SizedBox(width: 8),
                Text(
                  '全選 ($selectedCount / $allFilteredCount)',
                  style: TextStyle(color: context.appColors.ink, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: selectedCount == 0 ? null : onExport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appColors.surface2,
                    foregroundColor: context.appColors.ink,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text('匯出選取 ($selectedCount)', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: selectedCount == 0 ? null : onCreateProject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: context.appColors.onAcc,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: Text('建立專案 ($selectedCount)', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: selectedCount == 0 ? null : onBatchDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text('移至垃圾桶 ($selectedCount)', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onExitSelection,
                  icon: Icon(Icons.close, color: context.appColors.ink3),
                  tooltip: '退出多選',
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Selection state and exit button
                Row(
                  children: [
                    Checkbox(
                      value: isAllSelected,
                      onChanged: onSelectAllChanged,
                      activeColor: context.appColors.acc,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '已選 $selectedCount 位 / 共 $allFilteredCount 位',
                        style: TextStyle(
                          color: context.appColors.ink,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: onExitSelection,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.close, color: context.appColors.ink3, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Bottom Row: 3 equal-width action buttons (Plan A)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedCount == 0 ? null : onExport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.appColors.surface2,
                          foregroundColor: context.appColors.ink,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.ios_share_rounded, size: 15),
                            SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '匯出',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedCount == 0 ? null : onCreateProject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: context.appColors.onAcc,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 15),
                            SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '建立專案',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedCount == 0 ? null : onBatchDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 15),
                            SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '移至垃圾桶',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
