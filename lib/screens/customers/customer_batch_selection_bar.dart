import 'package:flutter/material.dart';
import '../../services/app_settings.dart';

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
    final Color primaryColor = AppSettings.instance.primaryColor;
    final bool isWideScreen = MediaQuery.of(context).size.width >= 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 20 : 14,
        vertical: isWideScreen ? 10 : 12,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0EA5E9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: isWideScreen
          ? Row(
              children: [
                Checkbox(
                  value: isAllSelected,
                  onChanged: onSelectAllChanged,
                  activeColor: const Color(0xFF0EA5E9),
                ),
                const SizedBox(width: 8),
                Text(
                  '全選 ($selectedCount / $allFilteredCount)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: selectedCount == 0 ? null : onExport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
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
                    foregroundColor: Colors.white,
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
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text('移至垃圾桶 ($selectedCount)', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: onExitSelection,
                  icon: const Icon(Icons.close, color: Colors.white70),
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
                      activeColor: const Color(0xFF0EA5E9),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '已選 $selectedCount 位 / 共 $allFilteredCount 位',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: onExitSelection,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, color: Colors.white70, size: 20),
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
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
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
                          foregroundColor: Colors.white,
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
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
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
