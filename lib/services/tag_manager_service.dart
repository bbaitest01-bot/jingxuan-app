import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'tag_categorizer.dart';
import 'tag_local_store.dart';
import 'tag_models.dart';

// 呼叫端原本從這個檔案取得資料模型，繼續提供
export 'tag_models.dart';

/// 標籤（大分類＋子標籤）的讀寫。
/// 2026-10-13（3-E）起存在每位業務員自己的資料表 `user_tag_categories`、`user_tags`（RLS 只能讀寫自己的），
/// 換裝置也看得到同一套。離線預覽模式才用瀏覽器本機。
/// 客戶身上的標籤仍存在 `customers.tags`（標籤名稱）。
class TagManagerService {
  static const String _defaultColorHex = TagLocalStore.defaultColorHex;
  static const int _maxNameLength = TagLocalStore.maxNameLength;

  // 第一次搬家只跑一次（同一個登入者），避免好幾個畫面同時讀取時重複建立
  static Future<void>? _migrationFuture;
  static String? _migrationUserId;

  static SupabaseClient get _supabase => Supabase.instance.client;

  /// 連線模式且已登入時用資料庫；否則（離線預覽）用瀏覽器本機
  static bool get _useDatabase {
    if (isOfflineMode) return false;
    return _supabase.auth.currentUser != null;
  }

  // ---------------------------------------------------------------------------
  // 讀取
  // ---------------------------------------------------------------------------

  /// 讀取自己的大分類（依排序）
  static Future<List<TagCategoryModel>> getCategories() async {
    if (!_useDatabase) return TagLocalStore.loadCategories();

    try {
      await _ensureMigrated();
      final rows = await _supabase
          .from('user_tag_categories')
          .select('id, name, color_hex, sort_order')
          .order('sort_order')
          .order('created_at');
      return List<Map<String, dynamic>>.from(rows).map((row) {
        return TagCategoryModel(
          id: row['id'].toString(),
          name: row['name'] as String,
          colorHex: row['color_hex'] as String?,
          sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('⚠️ [TagManagerService] 讀取大分類失敗: $e');
      return [];
    }
  }

  /// 讀取自己的子標籤，並把自訂顏色登記給 TagCategorizer（客戶卡片上的標籤顏色會用到）
  static Future<List<TagItemModel>> getTags() async {
    List<TagItemModel> tags;
    if (!_useDatabase) {
      tags = await TagLocalStore.loadTags();
    } else {
      try {
        await _ensureMigrated();
        final rows = await _supabase
            .from('user_tags')
            .select('id, category_id, name, color_hex')
            .order('created_at');
        tags = List<Map<String, dynamic>>.from(rows).map((row) {
          return TagItemModel(
            id: row['id'].toString(),
            categoryId: row['category_id'].toString(),
            name: row['name'] as String,
            colorHex: row['color_hex'] as String?,
          );
        }).toList();
      } catch (e) {
        debugPrint('⚠️ [TagManagerService] 讀取子標籤失敗: $e');
        tags = [];
      }
    }

    for (final TagItemModel tag in tags) {
      final String? colorHex = tag.colorHex;
      if (colorHex != null && colorHex.isNotEmpty) {
        TagCategorizer.registerCustomColor(tag.name, colorHex);
      }
    }
    return tags;
  }

  /// Checks if tag name exists (case-insensitive)
  static Future<bool> isTagNameExists(String name) async {
    final tags = await getTags();
    final target = name.trim().toLowerCase();
    return tags.any((t) => t.name.trim().toLowerCase() == target);
  }

  // ---------------------------------------------------------------------------
  // 大分類：新增／修改／刪除
  // ---------------------------------------------------------------------------

  /// 新增大分類；名稱重複或寫入失敗回傳 null
  static Future<TagCategoryModel?> addCategory(String name, {String? colorHex}) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > _maxNameLength) return null;

    final categories = await getCategories();
    if (categories.any((c) => c.name.toLowerCase() == trimmedName.toLowerCase())) {
      return null; // Duplicate category name
    }
    final String finalColor = TagLocalStore.normalizeColorHex(colorHex) ?? _defaultColorHex;
    final int sortOrder = categories.length + 1;

    if (!_useDatabase) {
      final newCat = TagCategoryModel(
        id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
        name: trimmedName,
        colorHex: finalColor,
        sortOrder: sortOrder,
      );
      await TagLocalStore.saveCategories([...categories, newCat]);
      return newCat;
    }

    try {
      final row = await _supabase
          .from('user_tag_categories')
          .insert({'name': trimmedName, 'color_hex': finalColor, 'sort_order': sortOrder})
          .select('id')
          .single();
      return TagCategoryModel(id: row['id'].toString(), name: trimmedName, colorHex: finalColor, sortOrder: sortOrder);
    } catch (e) {
      debugPrint('⚠️ [TagManagerService] 新增大分類失敗: $e');
      return null;
    }
  }

  /// 修改大分類名稱與顏色
  static Future<bool> editCategory(String categoryId, {required String newName, String? colorHex}) async {
    final String trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed.length > _maxNameLength) return false;

    final categories = await getCategories();
    final int index = categories.indexWhere((c) => c.id == categoryId);
    if (index == -1) return false;
    final TagCategoryModel oldCat = categories[index];
    final String? finalColor = TagLocalStore.normalizeColorHex(colorHex) ?? oldCat.colorHex;

    if (!_useDatabase) {
      categories[index] = TagCategoryModel(id: oldCat.id, name: trimmed, colorHex: finalColor, sortOrder: oldCat.sortOrder);
      await TagLocalStore.saveCategories(categories);
      return true;
    }

    try {
      await _supabase
          .from('user_tag_categories')
          .update({'name': trimmed, 'color_hex': finalColor})
          .eq('id', categoryId);
      return true;
    } catch (e) {
      debugPrint('⚠️ [TagManagerService] 修改大分類失敗: $e');
      return false;
    }
  }

  /// 刪除大分類（底下的子標籤一起刪除；資料庫由外鍵 ON DELETE CASCADE 處理）
  static Future<bool> deleteCategory(String categoryId) async {
    if (!_useDatabase) {
      final categories = await TagLocalStore.loadCategories();
      categories.removeWhere((c) => c.id == categoryId);
      await TagLocalStore.saveCategories(categories);
      final tags = await TagLocalStore.loadTags();
      tags.removeWhere((t) => t.categoryId == categoryId);
      await TagLocalStore.saveTags(tags);
      return true;
    }

    try {
      await _supabase.from('user_tag_categories').delete().eq('id', categoryId);
      return true;
    } catch (e) {
      debugPrint('⚠️ [TagManagerService] 刪除大分類失敗: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 子標籤：新增／修改／刪除／合併
  // ---------------------------------------------------------------------------

  /// 新增子標籤；名稱重複或寫入失敗回傳 null
  static Future<TagItemModel?> addTag({
    required String categoryId,
    required String name,
    String? colorHex,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > _maxNameLength) return null;
    if (await isTagNameExists(trimmed)) {
      return null; // Duplicate
    }
    final String? finalColor = TagLocalStore.normalizeColorHex(colorHex);

    if (!_useDatabase) {
      final tags = await TagLocalStore.loadTags();
      final newTag = TagItemModel(
        id: 'tag_${DateTime.now().millisecondsSinceEpoch}',
        categoryId: categoryId,
        name: trimmed,
        colorHex: finalColor,
      );
      await TagLocalStore.saveTags([...tags, newTag]);
      return newTag;
    }

    try {
      final row = await _supabase
          .from('user_tags')
          .insert({'category_id': categoryId, 'name': trimmed, 'color_hex': finalColor})
          .select('id')
          .single();
      if (finalColor != null) TagCategorizer.registerCustomColor(trimmed, finalColor);
      return TagItemModel(id: row['id'].toString(), categoryId: categoryId, name: trimmed, colorHex: finalColor);
    } catch (e) {
      debugPrint('⚠️ [TagManagerService] 新增子標籤失敗: $e');
      return null;
    }
  }

  /// 修改子標籤；改名時同步更新客戶身上的標籤（問題 G6）
  static Future<bool> editTag(String tagId, {String? newName, String? colorHex, String? newCategoryId}) async {
    final tags = await getTags();
    final int index = tags.indexWhere((t) => t.id == tagId);
    if (index == -1) return false;

    final TagItemModel oldTag = tags[index];
    final String updatedName = newName != null ? newName.trim() : oldTag.name;
    if (updatedName.isEmpty || updatedName.length > _maxNameLength) return false;

    // Check duplicate name if renamed
    final bool isRenamed = updatedName.toLowerCase() != oldTag.name.toLowerCase();
    if (isRenamed && tags.any((t) => t.id != tagId && t.name.toLowerCase() == updatedName.toLowerCase())) {
      return false; // Duplicate name
    }

    final TagItemModel updatedTag = oldTag.copyWith(
      name: updatedName,
      colorHex: TagLocalStore.normalizeColorHex(colorHex) ?? oldTag.colorHex,
      categoryId: newCategoryId ?? oldTag.categoryId,
    );

    if (!_useDatabase) {
      tags[index] = updatedTag;
      await TagLocalStore.saveTags(tags);
      return true;
    }

    try {
      await _supabase.from('user_tags').update({
        'name': updatedTag.name,
        'color_hex': updatedTag.colorHex,
        'category_id': updatedTag.categoryId,
      }).eq('id', tagId);
    } catch (e) {
      debugPrint('⚠️ [TagManagerService] 修改子標籤失敗: $e');
      return false;
    }

    final String? newColor = updatedTag.colorHex;
    if (newColor != null) TagCategorizer.registerCustomColor(updatedTag.name, newColor);
    if (updatedTag.name != oldTag.name) {
      await _replaceTagOnCustomers(oldTag.name, [updatedTag.name]);
    }
    return true;
  }

  /// 刪除子標籤，並從客戶身上拿掉這個標籤
  static Future<bool> deleteTag(String tagId) async {
    final tags = await getTags();
    final TagItemModel tag = tags.firstWhere((t) => t.id == tagId, orElse: () => TagItemModel(id: '', categoryId: '', name: ''));
    if (tag.id.isEmpty) return false;

    if (!_useDatabase) {
      tags.removeWhere((t) => t.id == tagId);
      await TagLocalStore.saveTags(tags);
      return true;
    }

    try {
      await _supabase.from('user_tags').delete().eq('id', tagId);
    } catch (e) {
      debugPrint('⚠️ [TagManagerService] 刪除子標籤失敗: $e');
      return false;
    }
    await _replaceTagOnCustomers(tag.name, []);
    return true;
  }

  /// 把多個標籤合併成目標標籤：刪除來源標籤，客戶身上的來源標籤換成目標標籤
  static Future<bool> mergeTags({
    required String targetTagName,
    required List<String> sourceTagNames,
  }) async {
    if (sourceTagNames.isEmpty) return false;

    if (!_useDatabase) {
      final tags = await TagLocalStore.loadTags();
      tags.removeWhere((t) => sourceTagNames.contains(t.name));
      await TagLocalStore.saveTags(tags);
      return true;
    }

    try {
      await _supabase.from('user_tags').delete().inFilter('name', sourceTagNames);
    } catch (e) {
      debugPrint('⚠️ [TagManagerService] 合併標籤失敗: $e');
      return false;
    }
    for (final String sourceName in sourceTagNames) {
      await _replaceTagOnCustomers(sourceName, [targetTagName]);
    }
    return true;
  }

  // 把自己客戶身上的某個標籤換成新的（傳空清單就是移除）。
  // 以前用了不存在的 customers.user_id 欄位，每次都失敗（問題 G6），改用 profile_id
  static Future<void> _replaceTagOnCustomers(String oldName, List<String> newNames) async {
    try {
      final User? user = _supabase.auth.currentUser;
      if (user == null) return;

      final rows = await _supabase
          .from('customers')
          .select('id, tags')
          .eq('profile_id', user.id)
          .contains('tags', [oldName]);

      for (final Map<String, dynamic> row in List<Map<String, dynamic>>.from(rows)) {
        final List<String> currentTags = List<String>.from(row['tags'] ?? []);
        currentTags.remove(oldName);
        for (final String newName in newNames) {
          if (!currentTags.contains(newName)) currentTags.add(newName);
        }
        await _supabase.from('customers').update({'tags': currentTags}).eq('id', row['id']);
      }
    } catch (e) {
      debugPrint('⚠️ [TagManagerService] 同步客戶標籤失敗: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 第一次使用：把瀏覽器本機的標籤搬進資料庫
  // ---------------------------------------------------------------------------

  static Future<void> _ensureMigrated() {
    final String? userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Future.value();
    if (_migrationUserId != userId || _migrationFuture == null) {
      _migrationUserId = userId;
      _migrationFuture = _migrateLocalTagsIfEmpty().catchError((Object e) {
        debugPrint('⚠️ [TagManagerService] 標籤搬家失敗: $e');
        _migrationFuture = null; // 下次讀取再試一次
      });
    }
    return _migrationFuture!;
  }

  // 資料庫裡還沒有自己的大分類時，把本機（沒有就用預設）的標籤搬上去。
  // 只搬「有子標籤的大分類」＋預設 5 類，像別人建的空分類（例：67）就不搬
  static Future<void> _migrateLocalTagsIfEmpty() async {
    final existing = await _supabase.from('user_tag_categories').select('id').limit(1);
    if (List.from(existing).isNotEmpty) return;

    final List<TagCategoryModel> localCategories = await TagLocalStore.loadCategories();
    final List<TagItemModel> localTags = await TagLocalStore.loadTags();
    final MigrationPlan plan = TagLocalStore.buildMigrationPlan(localCategories, localTags);

    final insertedCategories = await _supabase
        .from('user_tag_categories')
        .insert(plan.categoryRows)
        .select('id, name');
    final Map<String, String> categoryIdByName = {};
    for (final Map<String, dynamic> row in List<Map<String, dynamic>>.from(insertedCategories)) {
      categoryIdByName[row['name'] as String] = row['id'].toString();
    }

    final List<Map<String, dynamic>> tagRows = [];
    for (final MigrationTag tag in plan.tags) {
      final String? categoryId = categoryIdByName[tag.categoryName];
      if (categoryId == null) continue;
      tagRows.add({'category_id': categoryId, 'name': tag.name, 'color_hex': tag.colorHex});
    }
    if (tagRows.isNotEmpty) {
      await _supabase.from('user_tags').insert(tagRows);
    }
  }
}
