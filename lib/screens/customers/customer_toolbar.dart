import 'package:flutter/material.dart';
import '../../services/app_localizations.dart';
import '../../services/app_settings.dart';
import 'customer_top_panels.dart';

/// 客戶管理頂部的搜尋列與按鈕列：搜尋、切換卡片／條列、匯出、批次匯入、批量管理、新增客戶。
/// 電腦版（寬度 ≥ 768）排成一列；手機版搜尋列在上、按鈕在下。
class CustomerToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String viewMode;
  final bool isSelectionMode;
  final bool isDevUser;
  final bool devOnlyMine;
  final ValueChanged<bool> onDevScopeChanged;
  final VoidCallback onToggleViewMode;
  final VoidCallback onShareExport;
  final VoidCallback onBatchImport;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onAddCustomer;

  const CustomerToolbar({
    super.key,
    required this.searchController,
    required this.viewMode,
    required this.isSelectionMode,
    required this.isDevUser,
    required this.devOnlyMine,
    required this.onDevScopeChanged,
    required this.onToggleViewMode,
    required this.onShareExport,
    required this.onBatchImport,
    required this.onToggleSelectionMode,
    required this.onAddCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;

    final Color searchBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color searchBorder = isDark ? const Color(0xFF30363D) : Colors.grey.shade300;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color iconColor = isDark ? Colors.white54 : Colors.black45;
    final Widget devScopeSwitcher = CustomerDevScopeSwitcher(
      isDark: isDark,
      onlyMine: devOnlyMine,
      onScopeChanged: onDevScopeChanged,
    );

    return isWideScreen
        ? Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: context.l10n('customer_search_hint'),
                      hintStyle: TextStyle(color: iconColor),
                      prefixIcon: Icon(Icons.search, color: iconColor),
                      fillColor: searchBg,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: searchBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: searchBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // View Mode Toggle Button
              SizedBox(
                width: 48,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: searchBorder),
                  ),
                  child: IconButton(
                    onPressed: onToggleViewMode,
                    icon: Icon(
                      viewMode == 'list'
                          ? Icons.grid_view_outlined
                          : Icons.view_list_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                    tooltip: viewMode == 'list'
                        ? context.l10n('view_3d_card')
                        : context.l10n('view_list_view'),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Share / Export Button
              SizedBox(
                width: 48,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: searchBorder),
                  ),
                  child: IconButton(
                    onPressed: onShareExport,
                    icon: Icon(Icons.ios_share_outlined, color: primaryColor, size: 20),
                    tooltip: '匯出與分享選項',
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isDevUser) ...[
                devScopeSwitcher,
                const SizedBox(width: 12),
              ],
              OutlinedButton.icon(
                onPressed: onBatchImport,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.file_upload_outlined, size: 20),
                label: const Text('批次匯入 📥', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onToggleSelectionMode,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isSelectionMode ? const Color(0xFF38BDF8) : primaryColor,
                  side: BorderSide(color: isSelectionMode ? const Color(0xFF0EA5E9) : primaryColor, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  backgroundColor: isSelectionMode ? const Color(0xFF0EA5E9).withValues(alpha: 0.15) : Colors.transparent,
                ),
                icon: Icon(isSelectionMode ? Icons.check_box_outlined : Icons.checklist_outlined, size: 20),
                label: Text(isSelectionMode ? '結束多選 ✖' : '批量管理 📋', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onAddCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add, size: 20),
                label: Text(context.l10n('customer_add_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: searchController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: context.l10n('customer_search_hint'),
                          hintStyle: TextStyle(color: iconColor),
                          prefixIcon: Icon(Icons.search, color: iconColor),
                          fillColor: searchBg,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: searchBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: searchBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: searchBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: searchBorder),
                      ),
                      child: IconButton(
                        onPressed: onToggleViewMode,
                        icon: Icon(
                          viewMode == 'list'
                              ? Icons.grid_view_outlined
                              : Icons.view_list_outlined,
                          color: primaryColor,
                          size: 18,
                        ),
                        tooltip: viewMode == 'list'
                            ? context.l10n('view_3d_card')
                            : context.l10n('view_list_view'),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: searchBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: searchBorder),
                      ),
                      child: IconButton(
                        onPressed: onShareExport,
                        icon: Icon(Icons.ios_share_outlined, color: primaryColor, size: 18),
                        tooltip: '匯出與分享選項',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onBatchImport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text('批次匯入 📥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  OutlinedButton.icon(
                    onPressed: onToggleSelectionMode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isSelectionMode ? const Color(0xFF38BDF8) : primaryColor,
                      side: BorderSide(color: isSelectionMode ? const Color(0xFF0EA5E9) : primaryColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      backgroundColor: isSelectionMode ? const Color(0xFF0EA5E9).withValues(alpha: 0.15) : Colors.transparent,
                    ),
                    icon: Icon(isSelectionMode ? Icons.check_box_outlined : Icons.checklist_outlined, size: 18),
                    label: Text(isSelectionMode ? '結束多選 ✖' : '批量管理 📋', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  ElevatedButton.icon(
                    onPressed: onAddCustomer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n('customer_add_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              if (isDevUser) ...[
                const SizedBox(height: 10),
                devScopeSwitcher,
              ],
            ],
          );
  }
}
