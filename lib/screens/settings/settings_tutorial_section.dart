import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'settings_parts.dart';

/// 教學中心裡的一頁：名稱、圖示、有沒有示範影片
class _TutorialPage {
  final String name;
  final IconData icon;
  final bool hasVideo;

  const _TutorialPage(this.name, this.icon, {this.hasVideo = true});
}

/// 系統設定第 3 區「教學中心」（2026-11-01 沛沛定案的位置與樣子）
///
/// - 大教學：「開始導覽」在真的畫面上一步步標出來
/// - 每一頁：「畫面帶看」只看那一頁；「影片」是截圖做的示範影片（垃圾桶、設定只有畫面帶看）
/// 導覽、每頁的帶看與影片都還在製作，先顯示「製作中」、不能按
/// （2026-11-01 沛沛：「開始導覽」之後就是第一次登入時的大功能導覽，同一套；舊導覽內容過時先不開放）
class SettingsTutorialSection extends StatelessWidget {
  const SettingsTutorialSection({super.key});

  static const List<_TutorialPage> _pages = [
    _TutorialPage('今日行程', Icons.calendar_today_outlined),
    _TutorialPage('客戶管理', Icons.people_outline),
    _TutorialPage('專案拜訪', Icons.assignment_outlined),
    _TutorialPage('拜訪紀錄', Icons.record_voice_over_outlined),
    _TutorialPage('人脈拓撲', Icons.hub_outlined),
    _TutorialPage('數據戰情', Icons.bar_chart_outlined),
    _TutorialPage('新聞頭條', Icons.newspaper_outlined),
    _TutorialPage('個人帳號', Icons.account_circle_outlined),
    _TutorialPage('垃圾桶', Icons.delete_outline, hasVideo: false),
    _TutorialPage('系統設定', Icons.settings_outlined, hasVideo: false),
  ];

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> pageRows = [];
    for (final _TutorialPage page in _pages) {
      pageRows.add(_TutorialPageRow(page: page));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(icon: Icons.school_outlined, title: '教學中心'),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsRow(
                icon: Icons.explore_outlined,
                title: '第一次用？從頭帶你走一遍',
                description: '在真的畫面上一步一步標出來',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _MakingBadge(),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('開始導覽'),
                    ),
                  ],
                ),
              ),
              const SettingsDivider(),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('只想看某一頁', style: TextStyle(fontSize: 13, color: colors.ink3)),
                  const SizedBox(width: 8),
                  const _MakingBadge(),
                ],
              ),
              const SizedBox(height: 4),
              ...pageRows,
            ],
          ),
        ),
      ],
    );
  }
}

/// 教學中心的一頁：左邊頁名，右邊「畫面帶看」「影片」
class _TutorialPageRow extends StatelessWidget {
  final _TutorialPage page;

  const _TutorialPageRow({required this.page});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(page.icon, size: 18, color: colors.ink2),
          const SizedBox(width: 12),
          Expanded(child: Text(page.name, style: TextStyle(fontSize: 14, color: colors.ink))),
          const _TutorialAction(icon: Icons.ads_click_rounded, label: '畫面帶看'),
          const SizedBox(width: 18),
          SizedBox(
            width: 62,
            child: page.hasVideo ? const _TutorialAction(icon: Icons.smart_display_outlined, label: '影片') : null,
          ),
        ],
      ),
    );
  }
}

/// 帶看／影片的小連結（還在製作，先用淡色、不能按）
class _TutorialAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TutorialAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final Color color = context.appColors.ink3.withValues(alpha: 0.7);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}

/// 「製作中」小標
class _MakingBadge extends StatelessWidget {
  const _MakingBadge();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(color: colors.warnSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text('製作中', style: TextStyle(fontSize: 11, color: colors.warn)),
    );
  }
}
