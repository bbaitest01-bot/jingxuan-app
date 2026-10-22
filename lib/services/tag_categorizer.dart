import 'package:flutter/material.dart';

import '../theme/app_category_colors.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart' show AppDangerColors;
import 'app_settings.dart';

class TagStyle {
  final Color backgroundColor;
  final Color textColor;
  final String categoryName;

  const TagStyle({
    required this.backgroundColor,
    required this.textColor,
    required this.categoryName,
  });
}

class TagCategorizer {
  /// 全域自訂標籤色碼快取 (Tag Name -> Custom HEX)
  static final Map<String, String> customTagColors = {};

  /// 註冊或更新自訂標籤色碼
  static void registerCustomColor(String tagName, String hex) {
    if (tagName.trim().isNotEmpty && hex.trim().isNotEmpty) {
      customTagColors[tagName.trim().toLowerCase()] = hex.trim();
    }
  }

  /// 清空自訂標籤色碼（登出或換帳號時使用）
  static void clearCustomColors() {
    customTagColors.clear();
  }

  // 目前選的主題色（「跟進狀態」用它，切換主題色時一起變）
  static AppAccent get _accent => AppSettings.instance.accent;

  /// 對比度（WCAG）：1～21，數字越大越清楚；4.5 以上一般文字就看得清楚
  static double contrastRatio(Color a, Color b) {
    final double la = a.computeLuminance();
    final double lb = b.computeLuminance();
    final double lighter = la > lb ? la : lb;
    final double darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 文字和底色對比不夠時，明亮模式往黑色調、深色模式往白色調，直到看得清楚。
  /// 底色是半透明的，先疊在頁面白底／深底上再算
  static Color readableTextColor(Color textColor, Color backgroundColor, bool isDark) {
    final Color pageColor = isDark ? const Color(0xFF151C24) : Colors.white;
    final Color solidBackground = Color.alphaBlend(backgroundColor, pageColor);
    final Color target = isDark ? Colors.white : Colors.black;
    Color result = textColor;
    double step = 0;
    while (contrastRatio(result, solidBackground) < 4.5 && step < 1) {
      step += 0.1;
      result = Color.lerp(textColor, target, step) ?? textColor;
    }
    return result;
  }

  /// Classifies a tag name and returns the background and text color based on the current theme brightness.
  static TagStyle getStyle(String tagName, bool isDark, {String? customHex}) {
    final name = tagName.trim().toLowerCase();

    // 1. 優先檢查自訂色碼 (Custom HEX from caller or registry)
    final hex = customHex ?? customTagColors[name];
    if (hex != null && hex.isNotEmpty) {
      try {
        final clean = hex.replaceAll('#', '');
        if (clean.length == 6) {
          final colorInt = int.parse('FF$clean', radix: 16);
          final baseColor = Color(colorInt);
          final Color backgroundColor = isDark
              ? baseColor.withValues(alpha: 0.28)
              : baseColor.withValues(alpha: 0.14);
          Color textColor = baseColor;
          if (isDark) textColor = Color.lerp(baseColor, Colors.white, 0.45) ?? baseColor;
          return TagStyle(
            backgroundColor: backgroundColor,
            // 選到太淺（或深色模式太暗）的顏色時，文字自動調到看得清楚（2026-10-22）
            textColor: readableTextColor(textColor, backgroundColor, isDark),
            categoryName: '自訂標籤',
          );
        }
      } catch (_) {}
    }

    // 2. 已購險種 - 主題成功綠（2026-10-22 語意配色）
    if (name.contains('險') || 
        name.contains('保單') || 
        name.contains('規劃') || 
        name.contains('儲蓄') ||
        name.contains('投保') ||
        name.contains('簽單') && !name.contains('意願')) {
      return TagStyle(
        backgroundColor: isDark ? AppColors.dark(_accent).okSoft : AppColors.light(_accent).okSoft,
        textColor: isDark ? AppColors.dark(_accent).ok : AppColors.light(_accent).ok,
        categoryName: '已購險種',
      );
    } 
    
    // 3. 保障缺口 - 主題危險紅
    if (name.contains('缺') || name.contains('未保') || name.contains('不足') || name.contains('缺口')) {
      return TagStyle(
        backgroundColor: isDark ? AppDangerColors.darkDangerSoft : AppDangerColors.lightDangerSoft,
        textColor: isDark ? AppDangerColors.darkDanger : AppDangerColors.lightDanger,
        categoryName: '保障缺口',
      );
    }

    // 4. 跟進狀態 - 主題色（跟著使用者選的主題色變）
    if (name.contains('意願') || 
        name.contains('跟進') || 
        name.contains('聯絡') || 
        name.contains('預計') ||
        name.contains('拜訪') ||
        name == '已簽單' || 
        name == '待跟進' ||
        name == '高意願' ||
        name == '跟進中') {
      return TagStyle(
        backgroundColor: isDark ? _accent.darkAccentSoft : _accent.lightAccentSoft,
        textColor: isDark ? _accent.darkAccent : _accent.lightAccent,
        categoryName: '跟進狀態',
      );
    } 
    
    // 5. 健康與體況 - 清爽組青綠
    if (name.contains('體況') || 
        name.contains('病') || 
        name.contains('血壓') || 
        name.contains('手術') || 
        name.contains('健康') || 
        name.endsWith('史') ||
        name.contains('住院')) {
      return TagStyle(
        backgroundColor: isDark ? AppCategoryColors.teal.darkSoft : AppCategoryColors.teal.lightSoft,
        textColor: isDark ? AppCategoryColors.teal.dark : AppCategoryColors.teal.light,
        categoryName: '健康與體況',
      );
    } 
    
    // 6. 生活興趣 - 清爽組橘（2026-10-22 語意配色）
    if (name.contains('愛') || 
        name.contains('喜') ||
        name.contains('興趣') ||
        name.contains('運動') || 
        name.contains('茶') || 
        name.contains('玩') || 
        name.contains('露營') || 
        name.contains('爬山') || 
        name.contains('旅遊') ||
        name.contains('高爾夫') ||
        name.contains('健身')) {
      return TagStyle(
        backgroundColor: isDark ? AppCategoryColors.orange.darkSoft : AppCategoryColors.orange.lightSoft,
        textColor: isDark ? AppCategoryColors.orange.dark : AppCategoryColors.orange.light,
        categoryName: '生活興趣',
      );
    } 

    // 7. 客戶身分（沒有歸類的標籤都在這裡）- 清爽組藍
    return TagStyle(
      backgroundColor: isDark ? AppCategoryColors.blue.darkSoft : AppCategoryColors.blue.lightSoft,
      textColor: isDark ? AppCategoryColors.blue.dark : AppCategoryColors.blue.light,
      categoryName: '客戶身分',
    );
  }
}
