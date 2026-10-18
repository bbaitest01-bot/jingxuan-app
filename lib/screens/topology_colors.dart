import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 人脈拓撲的顏色（2026-10-19 沛沛決定）：
/// 關係線和客戶管理的關係類型同一組分類色；轉介紹對業務最重要，用主題色。
Color topologyEdgeColor(BuildContext context, String type) {
  if (type == 'referral') return context.appColors.acc;
  if (type == 'family') return AppCategoryColors.blue.solid(context);
  if (type == 'colleague' || type == 'workplace') return AppCategoryColors.teal.solid(context);
  if (type == 'social') return AppCategoryColors.orange.solid(context);
  return AppCategoryColors.gray.solid(context);
}

/// 客戶圓點：人脈越多，主題色越濃（0 條 → 最淡，3 條以上 → 主題色本身）。
/// 最淡也保留六成主題色，圓點上的 `onAcc` 字才看得清楚
Color topologyNodeColor(BuildContext context, int degree) {
  final AppColors colors = context.appColors;
  double strength = 0.6;
  if (degree >= 3) {
    strength = 1.0;
  } else if (degree == 2) {
    strength = 0.86;
  } else if (degree == 1) {
    strength = 0.72;
  }
  return Color.lerp(colors.surface, colors.acc, strength)!;
}
