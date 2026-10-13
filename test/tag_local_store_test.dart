import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/tag_local_store.dart';
import 'package:insurance_helper/services/tag_models.dart';

void main() {
  group('normalizeColorHex 顏色檢查', () {
    test('合格的 #RRGGBB 轉成大寫', () {
      expect(TagLocalStore.normalizeColorHex('#0369a1'), '#0369A1');
    });

    test('舊資料的顏色名稱、空值、格式錯誤都回傳 null', () {
      expect(TagLocalStore.normalizeColorHex('blue'), isNull);
      expect(TagLocalStore.normalizeColorHex(null), isNull);
      expect(TagLocalStore.normalizeColorHex('#12345'), isNull);
    });
  });

  group('buildMigrationPlan 第一次搬家', () {
    test('本機沒有資料時：搬預設 5 類與 17 個子標籤', () {
      final MigrationPlan plan = TagLocalStore.buildMigrationPlan(
        TagLocalStore.defaultCategories,
        TagLocalStore.defaultTags,
      );
      expect(plan.categoryRows.length, 5);
      expect(plan.tags.length, 17);
      expect(plan.categoryRows.first['name'], '客戶身分');
      expect(plan.categoryRows.first['sort_order'], 1);
    });

    test('別人建的空分類（例：67）不搬；有子標籤的自訂分類要搬', () {
      final List<TagCategoryModel> categories = [
        ...TagLocalStore.defaultCategories,
        TagCategoryModel(id: 'cat_67', name: '67', colorHex: 'blue'),
        TagCategoryModel(id: 'cat_vip', name: 'VIP', colorHex: 'red'),
      ];
      final List<TagItemModel> tags = [
        TagItemModel(id: 't_vip', categoryId: 'cat_vip', name: '大客戶', colorHex: '#ff0000'),
      ];
      final MigrationPlan plan = TagLocalStore.buildMigrationPlan(categories, tags);

      final List<String> categoryNames = plan.categoryRows.map((row) => row['name'] as String).toList();
      expect(categoryNames.contains('67'), isFalse);
      expect(categoryNames.contains('VIP'), isTrue);
      // 顏色名稱 'red' 不合格，改用預設色
      final Map<String, dynamic> vipRow = plan.categoryRows.firstWhere((row) => row['name'] == 'VIP');
      expect(vipRow['color_hex'], TagLocalStore.defaultColorHex);
      expect(plan.tags.single.categoryName, 'VIP');
      expect(plan.tags.single.colorHex, '#FF0000');
    });

    test('重複名稱（不分大小寫）與找不到大分類的子標籤會略過', () {
      final List<TagItemModel> tags = [
        TagItemModel(id: 'a', categoryId: 'cat_identity', name: 'VIP'),
        TagItemModel(id: 'b', categoryId: 'cat_identity', name: 'vip'),
        TagItemModel(id: 'c', categoryId: 'cat_missing', name: '孤兒標籤'),
      ];
      final MigrationPlan plan = TagLocalStore.buildMigrationPlan(TagLocalStore.defaultCategories, tags);
      expect(plan.tags.length, 1);
      expect(plan.tags.single.name, 'VIP');
    });

    test('預設分類被舊版換了編號：子標籤仍對回預設分類，預設 5 類一定搬', () {
      // 本機的「生活興趣」編號被換成共用表的 uuid，清單裡也沒有其他預設分類
      final List<TagCategoryModel> categories = [
        TagCategoryModel(id: 'uuid-123', name: '生活興趣', colorHex: '#B45309'),
      ];
      final List<TagItemModel> tags = [
        TagItemModel(id: 't_11', categoryId: 'cat_interests', name: '高爾夫'),
      ];
      final MigrationPlan plan = TagLocalStore.buildMigrationPlan(categories, tags);
      expect(plan.categoryRows.length, 5);
      expect(plan.tags.single.categoryName, '生活興趣');
    });
  });
}
