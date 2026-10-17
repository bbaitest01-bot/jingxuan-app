import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/theme/app_theme.dart';

void main() {
  group('舊版主題色對應到新的四種主題色', () {
    test('舊的五種顏色各自對應', () {
      expect(AppThemeColors.accentFromStoredValue(0xFF00ADB5).id, 'deep_sea');
      expect(AppThemeColors.accentFromStoredValue(0xFF2563EB).id, 'deep_sea');
      expect(AppThemeColors.accentFromStoredValue(0xFF10B981).id, 'ink_green');
      expect(AppThemeColors.accentFromStoredValue(0xFF8B5CF6).id, 'wine');
      expect(AppThemeColors.accentFromStoredValue(0xFFF59E0B).id, 'graphite');
    });

    test('新值讀回來還是同一種', () {
      for (final AppAccent accent in AppThemeColors.palette) {
        expect(AppThemeColors.accentFromStoredValue(accent.storedValue).id, accent.id);
      }
    });

    test('沒存過或看不懂的值一律用深海藍', () {
      expect(AppThemeColors.accentFromStoredValue(null).id, 'deep_sea');
      expect(AppThemeColors.accentFromStoredValue(0xFF123456).id, 'deep_sea');
      expect(AppThemeColors.accentFromStoredValue(0).id, 'deep_sea');
    });
  });

  group('主題 token', () {
    test('明亮、深色的主題色取對應模式的顏色', () {
      final AppColors lightColors = AppColors.light(AppThemeColors.wine);
      final AppColors darkColors = AppColors.dark(AppThemeColors.wine);
      expect(lightColors.acc, const Color(0xFF7A2B3A));
      expect(lightColors.onAcc, const Color(0xFFFFFFFF));
      expect(darkColors.acc, const Color(0xFFE39AA6));
      expect(darkColors.onAcc, const Color(0xFF0E1319));
      expect(lightColors.bg, const Color(0xFFF6F5F1));
      expect(darkColors.bg, const Color(0xFF0E1319));
    });

    testWidgets('context.appColors 取得目前主題的 token；沒套主題時不當掉', (WidgetTester tester) async {
      AppColors? themedColors;
      AppColors? fallbackColors;
      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            Theme(
              data: ThemeData(extensions: [AppColors.dark(AppThemeColors.inkGreen)]),
              child: Builder(builder: (BuildContext context) {
                themedColors = context.appColors;
                return const SizedBox();
              }),
            ),
            Theme(
              data: ThemeData(),
              child: Builder(builder: (BuildContext context) {
                fallbackColors = context.appColors;
                return const SizedBox();
              }),
            ),
          ],
        ),
      ));
      expect(themedColors?.acc, const Color(0xFF82C4AE));
      expect(fallbackColors?.acc, AppThemeColors.deepSea.lightAccent);
    });
  });

  // UI-3（問題總表 X16）：字型都改成內建的，網頁版第一個畫面就是正確的字
  group('內建字型', () {
    test('內文用思源黑體，沒有被預設的 Roboto 蓋掉', () {
      final ThemeData theme = AppTheme.light(AppThemeColors.deepSea);
      expect(theme.textTheme.bodyMedium?.fontFamily, AppTextStyles.bodyFamily);
      expect(theme.textTheme.labelLarge?.fontFamily, AppTextStyles.bodyFamily);
    });

    test('標題用思源宋體，明亮和深色都一樣', () {
      final ThemeData lightTheme = AppTheme.light(AppThemeColors.deepSea);
      final ThemeData darkTheme = AppTheme.dark(AppThemeColors.wine);
      expect(lightTheme.textTheme.titleLarge?.fontFamily, AppTextStyles.titleFamily);
      expect(darkTheme.textTheme.headlineSmall?.fontFamily, AppTextStyles.titleFamily);
      expect(lightTheme.textTheme.titleLarge?.fontWeight, AppTextStyles.titleWeight);
    });

    test('等寬字裡沒有的中文改用內建黑體', () {
      final TextStyle monoStyle = AppTextStyles.mono(fontSize: 14);
      expect(monoStyle.fontFamily, AppTextStyles.monoFamily);
      expect(monoStyle.fontFamilyFallback, contains(AppTextStyles.bodyFamily));
    });
  });
}
