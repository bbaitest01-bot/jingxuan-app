import 'package:flutter/material.dart';

import '../../widgets/tutorial_walkthrough_dialog.dart';

/// 今日行程的 4 步原生向量操作腳本（2026-11-01 沛沛定案：極致清晰向量渲染、零模糊、完全穩定不晃動）
List<WalkthroughStep> buildScheduleWalkthroughSteps(BuildContext context) {
  return const [
    // 步驟 1：點擊「路線規劃」按鈕
    WalkthroughStep(
      title: '多站順路路線規劃',
      description: '出門拜訪怕繞路？點擊右上角「路線規劃」，系統將依當日所有拜訪地點排出最佳順路順序。',
      actionBadge: '點擊「路線規劃」',
      cursorFraction: Offset(0.665, 0.088),
      screen: _Step1Screen(),
    ),

    // 步驟 2：開啟 Google 地圖導航
    WalkthroughStep(
      title: '一鍵開啟 Google 地圖多站導航',
      description: '勾選今天想去的拜訪站點，點擊下方「開啟 Google 地圖導航」，直接在 Google Maps 展開多站駕駛路線！',
      actionBadge: '開啟 Google 地圖導航',
      cursorFraction: Offset(0.550, 0.885),
      screen: _Step2Screen(),
    ),

    // 步驟 3：用說的快速排行程
    WalkthroughStep(
      title: '用說的快速排行程',
      description: '點擊右下角麥克風直接講出拜訪對象與時間，說完按下方「完成」，AI 辨識並整理好行程內容。',
      actionBadge: '說完點擊「完成」',
      cursorFraction: Offset(0.640, 0.885),
      screen: _Step3Screen(),
    ),

    // 步驟 4：單向推送至 Google 日曆（無自動誤導字眼）
    WalkthroughStep(
      title: '可單向推送至 Google 日曆',
      description: '若在「系統設定」開啟 Google 連線，排定行程時即可單向推送到你的 Google 日曆，在手機上也能收到通知提醒。',
      actionBadge: '開啟連線單向推送',
      cursorFraction: Offset(0.460, 0.125),
      screen: _Step4Screen(),
    ),
  ];
}

// ============================================================================
// 1. 底層真實「今日行程」全景畫面（純向量原生繪製，任何螢幕皆 100% 銳利清晰）
// ============================================================================
class _BaseScheduleView extends StatelessWidget {
  const _BaseScheduleView();

  @override
  Widget build(BuildContext context) {
    const Color bgPage = Color(0xFFF7F5F0);
    const Color borderColor = Color(0xFFE5E2DA);
    const Color navyColor = Color(0xFF1B4977);
    const Color inkMain = Color(0xFF2C3238);
    const Color inkMuted = Color(0xFF8A929A);

    return Container(
      color: bgPage,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左側選單（簡潔微型版）
          Container(
            width: 95,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // 使用者頭像與名字
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(color: navyColor, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text('林', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    const Text('林示範', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: inkMain)),
                  ],
                ),
                const SizedBox(height: 14),
                // 選單項目
                _buildMenuItem(Icons.calendar_today_outlined, '今日行程', active: true),
                _buildMenuItem(Icons.people_outline, '客戶管理'),
                _buildMenuItem(Icons.assignment_outlined, '專案拜訪'),
                _buildMenuItem(Icons.record_voice_over_outlined, '拜訪紀錄'),
                _buildMenuItem(Icons.hub_outlined, '人脈拓撲'),
                _buildMenuItem(Icons.bar_chart_outlined, '數據戰情'),
                _buildMenuItem(Icons.newspaper_outlined, '新聞頭條'),
                _buildMenuItem(Icons.settings_outlined, '系統設定'),
              ],
            ),
          ),

          // 中間月曆主體
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 頂部列
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                  child: const Row(
                    children: [
                      Text('今日行程', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: inkMain)),
                      Spacer(),
                      Icon(Icons.notifications_outlined, size: 16, color: inkMuted),
                    ],
                  ),
                ),
                // 工具列（月份導航 ＋ 路線規劃按鈕 ＋ 視圖切換）
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Text('2026/11', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: inkMain)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_left, size: 16, color: inkMuted),
                      const Icon(Icons.chevron_right, size: 16, color: inkMuted),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: borderColor)),
                        child: const Text('回到今天', style: TextStyle(fontSize: 10, color: inkMain)),
                      ),
                      const Spacer(),
                      // 路線規劃按鈕（深藍色膠囊）
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: navyColor, borderRadius: BorderRadius.circular(6)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alt_route_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text('路線規劃', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 視圖切換
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: borderColor)),
                        child: const Row(
                          children: [
                            Icon(Icons.calendar_view_month, size: 13, color: navyColor),
                            SizedBox(width: 3),
                            Text('月網格', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: navyColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 月曆網格
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        // 星期橫列
                        Container(
                          height: 24,
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                          child: const Row(
                            children: [
                              _WeekCol('日', isWeekend: true),
                              _WeekCol('一'),
                              _WeekCol('二'),
                              _WeekCol('三'),
                              _WeekCol('四'),
                              _WeekCol('五'),
                              _WeekCol('六', isWeekend: true),
                            ],
                          ),
                        ),
                        // 5 週格子簡要展示
                        Expanded(
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 35,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.45),
                            itemBuilder: (context, i) {
                              final int day = i + 1;
                              if (day > 30) return const SizedBox.shrink();
                              return Container(
                                decoration: BoxDecoration(border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 0.5)),
                                padding: const EdgeInsets.all(3),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$day', style: const TextStyle(fontSize: 9, color: inkMuted)),
                                    if (day == 1)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                        decoration: BoxDecoration(color: const Color(0xFFF3E8DC), borderRadius: BorderRadius.circular(2)),
                                        child: const Text('關懷 吳建宏', style: TextStyle(fontSize: 8, color: Color(0xFF92400E)), maxLines: 1),
                                      ),
                                    if (day == 2)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                        decoration: BoxDecoration(color: const Color(0xFFE0EAF6), borderRadius: BorderRadius.circular(2)),
                                        child: const Text('跟進 王美華', style: TextStyle(fontSize: 8, color: navyColor), maxLines: 1),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 右側時間軸面板（100% 原生乾淨時間軸，無任何醜陋大橘塊）
          Container(
            width: 175,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 面板頂部
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 12, color: navyColor),
                      const SizedBox(width: 4),
                      const Text('11/04 行程 (1)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: inkMain)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: navyColor, borderRadius: BorderRadius.circular(3)),
                        child: const Text('+ 新增', style: TextStyle(fontSize: 9, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                // 乾淨的時間軸刻度列表
                Expanded(
                  child: Stack(
                    children: [
                      ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          _buildHourRow('09:00'),
                          _buildHourRow('10:00'),
                          _buildHourRow('11:00'),
                          _buildHourRow('12:00'),
                          _buildHourRow('13:00'),
                          _buildHourRow('14:00'),
                          _buildHourRow('15:00'),
                          _buildHourRow('16:00'),
                          _buildHourRow('17:00'),
                        ],
                      ),
                      // 14:00 的精緻乾淨拜訪卡片
                      Positioned(
                        top: 76,
                        left: 42,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF4ED),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE8C8A5)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('吳建宏 生日關懷', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: inkMain)),
                              SizedBox(height: 1),
                              Text('10:00 - 11:00 · 關懷', style: TextStyle(fontSize: 8, color: Color(0xFF92400E))),
                            ],
                          ),
                        ),
                      ),
                      // 右下角語音輸入懸浮按鈕
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: navyColor, shape: BoxShape.circle),
                          child: const Icon(Icons.mic, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildMenuItem(IconData icon, String title, {bool active = false}) {
    const Color navyColor = Color(0xFF1B4977);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF1F8) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: active ? navyColor : const Color(0xFF6E7781)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? navyColor : const Color(0xFF424A53),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildHourRow(String hour) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Text(hour, style: const TextStyle(fontSize: 9, color: Color(0xFF9AA0A6))),
          const SizedBox(width: 4),
          const Expanded(child: Divider(color: Color(0xFFECEAE4), thickness: 0.8)),
        ],
      ),
    );
  }
}

class _WeekCol extends StatelessWidget {
  final String label;
  final bool isWeekend;
  const _WeekCol(this.label, {this.isWeekend = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isWeekend ? const Color(0xFFC0392B) : const Color(0xFF5F6368),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 步驟 1 畫面：主日程全貌
// ============================================================================
class _Step1Screen extends StatelessWidget {
  const _Step1Screen();

  @override
  Widget build(BuildContext context) {
    return const _BaseScheduleView();
  }
}

// ============================================================================
// 步驟 2 畫面：行程路線規劃視窗（含 6 個真實站點與 Google 導航按鈕）
// ============================================================================
class _Step2Screen extends StatelessWidget {
  const _Step2Screen();

  @override
  Widget build(BuildContext context) {
    const Color navyColor = Color(0xFF1B4977);
    const Color inkMain = Color(0xFF2C3238);

    return Stack(
      children: [
        const _BaseScheduleView(),
        // 柔和暗色背景遮罩
        Container(color: Colors.black.withValues(alpha: 0.42)),
        // 中央「行程路線規劃」真實彈窗
        Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 標題列
                const Row(
                  children: [
                    Icon(Icons.alt_route_rounded, size: 16, color: navyColor),
                    SizedBox(width: 6),
                    Text('行程路線規劃 (2026年11月01日)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: inkMain)),
                    Spacer(),
                    Icon(Icons.close, size: 16, color: Colors.black45),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('起點為目前位置。依時間順序在 Google Maps 規劃多站駕駛路線：', style: TextStyle(fontSize: 10, color: Color(0xFF6E7781))),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Text('☑ 全選   ☐ 全不選', style: TextStyle(fontSize: 10, color: navyColor)),
                    Spacer(),
                    Text('已選擇 6 / 6 站', style: TextStyle(fontSize: 10, color: navyColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 12),
                // 6 個真實站點清單
                _buildRouteItem('1', '10:00 楊志明 退休規劃聊聊', '學校'),
                _buildRouteItem('2', '14:00 蔡宜君 實支實付說明', '蔡宜君公司樓下'),
                _buildRouteItem('3', '09:00 團隊晨會', '通訊處會議室'),
                _buildRouteItem('4', '10:30 林佳穎 醫療險需求訪談', '信義區示範咖啡廳'),
                _buildRouteItem('5', '14:30 許董 員工團保與傳承規劃', '許董公司（內湖）'),
                _buildRouteItem('6', '10:00 王大明 保單送件', '台北分公司'),
                const SizedBox(height: 10),
                // 底部按鈕
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: const Text('取消', style: TextStyle(fontSize: 11, color: Color(0xFF6E7781))),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: navyColor, borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.navigation_outlined, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text('開啟 Google 地圖導航 (免費)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildRouteItem(String index, String title, String address) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: const BoxDecoration(color: Color(0xFF1B4977), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(index, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2C3238))),
                Text(address, style: const TextStyle(fontSize: 8.5, color: Color(0xFF6E7781))),
              ],
            ),
          ),
          const Icon(Icons.check_box, size: 15, color: Color(0xFF1B4977)),
        ],
      ),
    );
  }
}

// ============================================================================
// 步驟 3 畫面：語音排行程畫面（麥克風脈衝與完成按鈕）
// ============================================================================
class _Step3Screen extends StatelessWidget {
  const _Step3Screen();

  @override
  Widget build(BuildContext context) {
    const Color navyColor = Color(0xFF1B4977);

    return Stack(
      children: [
        const _BaseScheduleView(),
        // 語音輸入覆蓋層
        Container(
          color: Colors.white.withValues(alpha: 0.92),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 大麥克風光圈
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2EAF4),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC5D7ED), width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(color: navyColor, shape: BoxShape.circle),
                      child: const Icon(Icons.mic, size: 28, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('00:07', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyColor, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                const Text('🎙️ 請開始說話', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2C3238))),
                const SizedBox(height: 2),
                const Text('說完後按下方「完成」送出', style: TextStyle(fontSize: 10, color: Color(0xFF6E7781))),
                const SizedBox(height: 28),
                // 底部按鈕
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD0D7DE)),
                      ),
                      child: const Text('取消', style: TextStyle(fontSize: 11, color: Color(0xFF57606A))),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
                      decoration: BoxDecoration(
                        color: navyColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('完成', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 步驟 4 畫面：編輯行程視窗（單向推送 Google 標籤）
// ============================================================================
class _Step4Screen extends StatelessWidget {
  const _Step4Screen();

  @override
  Widget build(BuildContext context) {
    const Color navyColor = Color(0xFF1B4977);
    const Color inkMain = Color(0xFF2C3238);
    const Color borderColor = Color(0xFFE5E2DA);

    return Stack(
      children: [
        const _BaseScheduleView(),
        // 柔和暗色遮罩
        Container(color: Colors.black.withValues(alpha: 0.42)),
        // 中央「編輯行程」真實彈窗
        Center(
          child: Container(
            width: 410,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 標題列 ＋「單向推送 Google」標籤
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 16, color: navyColor),
                    const SizedBox(width: 6),
                    const Text('編輯行程', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: inkMain)),
                    const SizedBox(width: 8),
                    // 單向推送 Google 標籤（無「自動」字眼）
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EFF8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFC2D6ED)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync, size: 11, color: navyColor),
                          SizedBox(width: 3),
                          Text('單向推送 Google', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: navyColor)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.close, size: 16, color: Colors.black45),
                  ],
                ),
                const SizedBox(height: 10),
                // 關聯客戶
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(5)),
                  child: const Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: navyColor),
                      SizedBox(width: 6),
                      Text('鄭雅文 (0900-000-112)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: inkMain)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 行程標題
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: borderColor)),
                  child: const Text('鄭雅文 意外險說明', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: inkMain)),
                ),
                const SizedBox(height: 8),
                // 開始與結束時間
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: borderColor)),
                        child: const Text('2026/11/04 下午 12:00', style: TextStyle(fontSize: 9.5, color: inkMain)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: borderColor)),
                        child: const Text('下午 1:00', style: TextStyle(fontSize: 9.5, color: inkMain)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 地點
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: borderColor)),
                  child: const Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF6E7781)),
                      SizedBox(width: 4),
                      Text('學校附近', style: TextStyle(fontSize: 10, color: inkMain)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 標籤列
                const Wrap(
                  spacing: 4,
                  children: [
                    _TagChip('跟進狀態', Color(0xFF6B21A8)),
                    _TagChip('意外險', Color(0xFF15803D)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
