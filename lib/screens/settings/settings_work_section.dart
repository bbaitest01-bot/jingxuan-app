import 'package:flutter/material.dart';

import '../../services/app_settings.dart';
import '../tag_manager_screen.dart';
import 'settings_parts.dart';

/// 系統設定第 2 區「使用習慣」：客戶怎麼排、左邊選單收合、標籤與資料夾
/// （2026-11-01 沛沛：原本獨立一區的「標籤管理」併進來）
class SettingsWorkSection extends StatelessWidget {
  final AppSettings settings;

  const SettingsWorkSection({super.key, required this.settings});

  void _openTagManager(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) => const TagManagerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(icon: Icons.tune_rounded, title: '使用習慣'),
        SettingsCard(
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.view_agenda_outlined,
                title: '客戶一開始怎麼排',
                description: '打開客戶管理時，先用卡片還是清單',
                trailing: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'card', label: Text('卡片'), icon: Icon(Icons.grid_view_outlined, size: 16)),
                    ButtonSegment(value: 'list', label: Text('清單'), icon: Icon(Icons.table_rows_outlined, size: 16)),
                  ],
                  selected: {settings.defaultCustomerViewMode},
                  onSelectionChanged: (Set<String> selection) => settings.setDefaultCustomerViewMode(selection.first),
                ),
              ),
              const SettingsDivider(),
              SettingsRow(
                icon: Icons.view_sidebar_outlined,
                title: '左邊選單平常收起來',
                description: '只顯示圖示，畫面比較寬；按選單下方的箭頭可以再展開',
                trailing: Switch(
                  value: settings.isSidebarCollapsedByDefault,
                  onChanged: (bool value) => settings.setSidebarCollapsedByDefault(value),
                ),
              ),
              const SettingsDivider(),
              SettingsRow(
                icon: Icons.local_offer_outlined,
                title: '標籤與資料夾',
                description: '新增、改名、合併客戶標籤',
                trailing: OutlinedButton(
                  onPressed: () => _openTagManager(context),
                  child: const Text('管理'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
