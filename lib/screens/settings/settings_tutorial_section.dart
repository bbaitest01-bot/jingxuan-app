import 'package:flutter/material.dart';

import '../../services/onboarding_tour_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tutorial_walkthrough_dialog.dart';
import 'schedule_walkthrough_data.dart';
import 'settings_parts.dart';

/// 教學中心裡的一頁：名稱、重點說明、圖示
class _TutorialPage {
  final String name;
  final String description;
  final IconData icon;

  const _TutorialPage(this.name, this.description, this.icon);
}

/// 系統設定第 3 區「教學中心」（2026-11-01 沛沛定案：單一按鈕「觀看教學」＋重點功能說明）
///
/// - 大教學：「開始導覽」在真的畫面上一步步標出來
/// - 各功能：點「觀看教學」彈出擬真滑鼠指標虛擬操作播放器
class SettingsTutorialSection extends StatelessWidget {
  const SettingsTutorialSection({super.key});

  static const List<_TutorialPage> _pages = [
    _TutorialPage('今日行程', '全日拜訪日程、多站順路路線規劃與智慧語音排程', Icons.calendar_today_outlined),
    _TutorialPage('客戶管理', '卡片名單管理、快速建檔、保障健檢缺口與保單檢視', Icons.people_outline),
    _TutorialPage('專案拜訪', '批量專案行銷、未訪名單篩選與拜訪成效折線圖', Icons.assignment_outlined),
    _TutorialPage('拜訪紀錄', '語音錄製、AI 自動錯字校正與通順語意匯出', Icons.record_voice_over_outlined),
    _TutorialPage('人脈拓撲', '黑曜石動態力導向星空圖、同姓找人與轉介紹鏈', Icons.hub_outlined),
    _TutorialPage('數據戰情', '客戶概況分析、險種佔比與業績轉化視覺化圖表', Icons.bar_chart_outlined),
    _TutorialPage('新聞頭條', '經選日報報紙版面、每日保險動態與 AI 情境插圖', Icons.newspaper_outlined),
    _TutorialPage('個人帳號', '3D 反光數位名片、20 款抽屜模板與雙面圖片下載', Icons.account_circle_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

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
                trailing: FilledButton.icon(
                  onPressed: OnboardingTourService.instance.start,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('開始導覽'),
                ),
              ),
              const SettingsDivider(),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('各功能操作教學', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink2)),
                  const SizedBox(width: 8),
                  Text('點擊可觀看擬真操作影片', style: TextStyle(fontSize: 12, color: colors.ink3)),
                ],
              ),
              const SizedBox(height: 8),
              ..._pages.map((_TutorialPage page) {
                // 今日行程已完成擬真滑鼠播放器，其他功能標記製作中
                VoidCallback? onWatch;
                if (page.name == '今日行程') {
                  onWatch = () {
                    TutorialWalkthroughDialog.show(
                      context,
                      categoryName: page.name,
                      steps: buildScheduleWalkthroughSteps(context),
                    );
                  };
                }

                return _TutorialPageRow(
                  page: page,
                  onTapWatch: onWatch,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

/// 教學中心的一列：左邊圖示＋名稱＋重點說明，右邊單一按鈕「觀看教學」
class _TutorialPageRow extends StatelessWidget {
  final _TutorialPage page;
  final VoidCallback? onTapWatch;

  const _TutorialPageRow({required this.page, this.onTapWatch});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool isAvailable = onTapWatch != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Icon(page.icon, size: 18, color: colors.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  page.description,
                  style: TextStyle(fontSize: 12, color: colors.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: isAvailable ? onTapWatch : null,
            icon: Icon(
              isAvailable ? Icons.play_arrow_rounded : Icons.lock_clock_outlined,
              size: 16,
            ),
            label: Text(isAvailable ? '觀看教學' : '製作中'),
            style: FilledButton.styleFrom(
              backgroundColor: isAvailable ? colors.acc : colors.surface2,
              foregroundColor: isAvailable ? colors.onAcc : colors.ink3,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
