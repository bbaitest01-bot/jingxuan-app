import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 登入頁左欄：品牌、標語、三項功能、頁尾。
/// 寬螢幕時是整個左半邊；窄螢幕（手機）時用 [isCompact] 縮成表單上方的精簡版。
class LoginBrandPanel extends StatelessWidget {
  final bool isCompact;

  const LoginBrandPanel({super.key, this.isCompact = false});

  static const List<String> _features = [
    '行程與拜訪紀錄，一處掌握',
    '拜訪錄音交給 AI 整理成紀錄',
    '客戶的人脈關係，一眼看懂',
  ];

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  // 寬螢幕：品牌在上、標語與功能在中間、頁尾在下
  Widget _buildFull(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandLockup(),
          const Spacer(),
          const _AccentRule(),
          const SizedBox(height: 28),
          Text(
            '把每一位客戶，\n經營成長久的信任。',
            style: AppTextStyles.serif(fontSize: 46, color: colors.ink).copyWith(height: 1.35),
          ),
          const SizedBox(height: 40),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: const _FeatureList(features: _features),
          ),
          const Spacer(),
          Text(
            '專題作品 · 2026',
            style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w400, color: colors.ink3),
          ),
        ],
      ),
    );
  }

  // 窄螢幕：只留品牌與標語，下面一條細線和表單分開
  Widget _buildCompact(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandLockup(),
          const SizedBox(height: 28),
          const _AccentRule(),
          const SizedBox(height: 16),
          Text(
            '把每一位客戶，\n經營成長久的信任。',
            style: AppTextStyles.serif(fontSize: 26, color: colors.ink).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// 品牌：方框裡的「經」字＋「經選助手」與英文小字
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: colors.acc, width: 1.5),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text('經', style: AppTextStyles.serif(fontSize: 20, color: colors.acc)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '經選助手',
              // 字距 0.06em：18 × 0.06 ≈ 1.1
              style: AppTextStyles.serif(fontSize: 18, color: colors.ink).copyWith(letterSpacing: 1.1),
            ),
            const SizedBox(height: 2),
            Text(
              'JINGXUAN',
              // 字距 0.2em：10 × 0.2 = 2
              style: AppTextStyles.mono(fontSize: 10, fontWeight: FontWeight.w400, color: colors.ink3)
                  .copyWith(letterSpacing: 2),
            ),
          ],
        ),
      ],
    );
  }
}

/// 標語上方的主題色短線（48 × 2）
class _AccentRule extends StatelessWidget {
  const _AccentRule();

  @override
  Widget build(BuildContext context) {
    return Container(width: 48, height: 2, color: context.appColors.acc);
  }
}

/// 三列功能清單：每列上下有細線，前面是等寬字的編號
class _FeatureList extends StatelessWidget {
  final List<String> features;

  const _FeatureList({required this.features});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> rows = [];
    for (int index = 0; index < features.length; index++) {
      final String number = (index + 1).toString().padLeft(2, '0');
      rows.add(Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line))),
        child: Row(
          children: [
            Text(number, style: AppTextStyles.mono(fontSize: 13, color: colors.acc)),
            const SizedBox(width: 18),
            Expanded(
              child: Text(features[index], style: TextStyle(fontSize: 15, color: colors.ink2)),
            ),
          ],
        ),
      ));
    }
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line))),
      child: Column(children: rows),
    );
  }
}
