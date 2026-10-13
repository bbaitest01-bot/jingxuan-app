import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'tag_models.dart';

/// 標籤的瀏覽器本機存放（離線預覽模式用），以及第一次把本機標籤搬進資料庫時「要搬哪些」的計算。
class TagLocalStore {
  static const String _prefCategoriesKey = 'tag_categories_custom';
  static const String _prefTagsKey = 'tags_custom';
  static const String defaultColorHex = '#0369A1';
  static const int maxNameLength = 30;

  // 5 Default Categories
  static final List<TagCategoryModel> defaultCategories = [
    TagCategoryModel(id: 'cat_identity', name: '客戶身分', colorHex: '#0369A1', sortOrder: 1),
    TagCategoryModel(id: 'cat_insurance', name: '已購險種', colorHex: '#15803D', sortOrder: 2),
    TagCategoryModel(id: 'cat_interests', name: '生活興趣', colorHex: '#B45309', sortOrder: 3),
    TagCategoryModel(id: 'cat_health', name: '健康與體況', colorHex: '#BE123C', sortOrder: 4),
    TagCategoryModel(id: 'cat_followup', name: '跟進狀態', colorHex: '#6B21A8', sortOrder: 5),
  ];

  // Default initial sub-tags
  static final List<TagItemModel> defaultTags = [
    TagItemModel(id: 't_1', categoryId: 'cat_identity', name: '青年(18-35)'),
    TagItemModel(id: 't_2', categoryId: 'cat_identity', name: '中年(36-60)'),
    TagItemModel(id: 't_3', categoryId: 'cat_identity', name: '高資產'),
    TagItemModel(id: 't_4', categoryId: 'cat_identity', name: '單身'),
    TagItemModel(id: 't_5', categoryId: 'cat_insurance', name: '醫療險'),
    TagItemModel(id: 't_6', categoryId: 'cat_insurance', name: '意外險'),
    TagItemModel(id: 't_7', categoryId: 'cat_insurance', name: '防癌險'),
    TagItemModel(id: 't_8', categoryId: 'cat_insurance', name: '儲蓄險'),
    TagItemModel(id: 't_9', categoryId: 'cat_insurance', name: '車險'),
    TagItemModel(id: 't_10', categoryId: 'cat_interests', name: '露營'),
    TagItemModel(id: 't_11', categoryId: 'cat_interests', name: '高爾夫'),
    TagItemModel(id: 't_12', categoryId: 'cat_interests', name: '爬山'),
    TagItemModel(id: 't_13', categoryId: 'cat_health', name: '健康'),
    TagItemModel(id: 't_14', categoryId: 'cat_health', name: '高血壓'),
    TagItemModel(id: 't_15', categoryId: 'cat_followup', name: '高意願'),
    TagItemModel(id: 't_16', categoryId: 'cat_followup', name: '定期聯繫'),
    TagItemModel(id: 't_17', categoryId: 'cat_followup', name: '觀望中'),
  ];

  /// 決定要搬哪些大分類與子標籤（純計算，方便測試）
  static MigrationPlan buildMigrationPlan(List<TagCategoryModel> categories, List<TagItemModel> tags) {
    final Set<String> defaultNames = defaultCategories.map((c) => c.name).toSet();
    final Map<String, TagCategoryModel> categoryById = {for (final c in categories) c.id: c};
    // 舊版會用共用表的同名分類蓋掉預設分類（編號跟著換掉），子標籤記的還是預設編號（例：cat_interests），
    // 所以本機清單找不到時，再用預設分類的編號對回名稱
    for (final TagCategoryModel defaultCategory in defaultCategories) {
      categoryById.putIfAbsent(defaultCategory.id, () => defaultCategory);
    }

    // 子標籤：名稱合法、不重複（不分大小寫）、有對應的大分類
    final List<MigrationTag> migrationTags = [];
    final Set<String> seenTagNames = {};
    for (final TagItemModel tag in tags) {
      final String name = tag.name.trim();
      final TagCategoryModel? category = categoryById[tag.categoryId];
      if (name.isEmpty || name.length > maxNameLength || category == null) continue;
      if (!seenTagNames.add(name.toLowerCase())) continue;
      migrationTags.add(MigrationTag(category.name.trim(), name, normalizeColorHex(tag.colorHex)));
    }

    // 大分類：預設 5 類＋有子標籤的分類
    final Set<String> usedCategoryNames = migrationTags.map((t) => t.categoryName).toSet();
    final List<Map<String, dynamic>> categoryRows = [];
    final Set<String> seenCategoryNames = {};
    // 預設 5 類排在本機清單後面補上，本機清單裡已有同名的就略過
    final List<TagCategoryModel> candidates = [...categories, ...defaultCategories];
    for (final TagCategoryModel category in candidates) {
      final String name = category.name.trim();
      if (name.isEmpty || name.length > maxNameLength) continue;
      if (!defaultNames.contains(name) && !usedCategoryNames.contains(name)) continue;
      if (!seenCategoryNames.add(name.toLowerCase())) continue;
      categoryRows.add({
        'name': name,
        'color_hex': normalizeColorHex(category.colorHex) ?? defaultColorHex,
        'sort_order': categoryRows.length + 1,
      });
    }
    return MigrationPlan(categoryRows, migrationTags);
  }

  /// 顏色只接受 #RRGGBB（例如舊資料的 'blue' 不合格），不合格回傳 null
  static String? normalizeColorHex(String? hex) {
    if (hex == null) return null;
    final String trimmed = hex.trim();
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(trimmed)) return null;
    return trimmed.toUpperCase();
  }

  static Future<List<TagCategoryModel>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cached = prefs.getString(_prefCategoriesKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(cached);
        final List<TagCategoryModel> result = list.map((e) => TagCategoryModel.fromJson(e)).toList();
        if (result.isNotEmpty) return result;
      } catch (_) {}
    }
    return List.from(defaultCategories);
  }

  static Future<List<TagItemModel>> loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cached = prefs.getString(_prefTagsKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(cached);
        final List<TagItemModel> result = list.map((e) => TagItemModel.fromJson(e)).toList();
        if (result.isNotEmpty) return result;
      } catch (_) {}
    }
    return List.from(defaultTags);
  }

  static Future<void> saveCategories(List<TagCategoryModel> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCategoriesKey, jsonEncode(categories.map((e) => e.toJson()).toList()));
  }

  static Future<void> saveTags(List<TagItemModel> tags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTagsKey, jsonEncode(tags.map((e) => e.toJson()).toList()));
  }
}

/// 第一次搬家要建立的內容
class MigrationPlan {
  final List<Map<String, dynamic>> categoryRows;
  final List<MigrationTag> tags;

  const MigrationPlan(this.categoryRows, this.tags);
}

/// 要搬的一個子標籤（用大分類名稱對應，因為資料庫的大分類 id 搬家後才產生）
class MigrationTag {
  final String categoryName;
  final String name;
  final String? colorHex;

  const MigrationTag(this.categoryName, this.name, this.colorHex);
}
