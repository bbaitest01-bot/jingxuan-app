import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show isOfflineMode;
import '../models/saved_comparison.dart';
import 'customer_service.dart';
import 'scenario/claim_scenario.dart';

/// 存比較失敗時要告訴業務員的原因（訊息可以直接顯示在畫面上）
class SavedComparisonException implements Exception {
  final String message;

  const SavedComparisonException(this.message);

  @override
  String toString() => message;
}

/// 比較清單的讀寫（D36，全景地圖 4-R）。誰能看由資料庫權限把關，只會讀到自己名下客戶的比較
class SavedComparisonService {
  static const int minimumProductCount = 2;
  static const int maximumProductCount = 8;
  static const int maximumNameLength = 30;

  // 資料庫回報「違反不可重複」的錯誤代碼
  static const String _uniqueViolationCode = '23505';

  static final SavedComparisonService instance = SavedComparisonService._internal();
  SavedComparisonService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  static const String _tableName = 'customer_saved_comparisons';

  /// 客戶編號 → 存了幾筆比較；卡片聽這個決定要不要顯示按鈕，不用每張卡片各查一次
  final ValueNotifier<Map<String, int>> countByCustomer = ValueNotifier(const {});

  /// 把一列列資料算成每位客戶有幾筆
  static Map<String, int> countRowsByCustomer(List<dynamic> rows) {
    final Map<String, int> counts = {};
    for (final dynamic row in rows) {
      final String customerId = row['customer_id'].toString();
      counts[customerId] = (counts[customerId] ?? 0) + 1;
    }
    return counts;
  }

  /// 去掉頭尾空白並檢查長度；資料庫算的是「字數」，罕見字要用 runes 才不會多算
  static String normalizeName(String name) {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const SavedComparisonException('請幫這次比較取個名稱');
    }
    if (trimmedName.runes.length > maximumNameLength) {
      throw const SavedComparisonException('名稱最多 $maximumNameLength 個字');
    }
    return trimmedName;
  }

  static void validateItems(List<SavedComparisonItem> items) {
    if (items.length < minimumProductCount) {
      throw const SavedComparisonException('至少要有 $minimumProductCount 款商品才能存成比較');
    }
    if (items.length > maximumProductCount) {
      throw const SavedComparisonException('最多只能存 $maximumProductCount 款商品');
    }
  }

  /// 只留下自己名下的客戶：管理者、開發者讀得到別人的客戶，但比較只能存在自己的客戶底下
  static List<Map<String, dynamic>> keepOwnCustomers(List<Map<String, dynamic>> customers, String? userId) {
    final List<Map<String, dynamic>> ownCustomers = [];
    for (final Map<String, dynamic> customer in customers) {
      if (customer['profile_id']?.toString() == userId) {
        ownCustomers.add(customer);
      }
    }
    return ownCustomers;
  }

  /// 存檔時可以選的客戶：自己名下、不在垃圾桶
  Future<List<Map<String, dynamic>>> fetchSelectableCustomers() async {
    final CustomerService customerService = CustomerService.instance;
    final List<Map<String, dynamic>> customers = await customerService.fetchActiveCustomers();
    return keepOwnCustomers(customers, customerService.currentUserId);
  }

  /// 重新讀每位客戶的筆數；客戶管理載入時、存檔或刪除後呼叫
  Future<void> refreshCounts() async {
    if (isOfflineMode) return;
    try {
      final List<dynamic> rows = await _supabase.from(_tableName).select('customer_id');
      countByCustomer.value = countRowsByCustomer(rows);
    } catch (error) {
      // 讀不到筆數只是暫時不顯示按鈕，不影響客戶管理其他功能
      if (kDebugMode) print('讀比較清單筆數失敗: $error');
    }
  }

  /// 這位客戶的比較，最近存的排最前面
  Future<List<SavedComparison>> fetchForCustomer(String customerId) async {
    if (isOfflineMode) return const [];
    final List<dynamic> rows = await _supabase
        .from(_tableName)
        .select()
        .eq('customer_id', customerId)
        .order('updated_at', ascending: false);
    final List<SavedComparison> comparisons = [];
    for (final dynamic row in rows) {
      comparisons.add(SavedComparison.fromJson(Map<String, dynamic>.from(row as Map)));
    }
    return comparisons;
  }

  /// 存成新的一筆（第一次存、或「另存新的」）
  Future<SavedComparison> create({
    required String customerId,
    required String name,
    required ClaimScenarioInput scenario,
    required List<SavedComparisonItem> items,
  }) async {
    _ensureOnline();
    final String normalizedName = normalizeName(name);
    validateItems(items);
    final Map<String, dynamic> row = await _runWrite(() {
      return _supabase
          .from(_tableName)
          .insert({
            'customer_id': customerId,
            'name': normalizedName,
            'scenario': SavedComparisonScenario.toJson(scenario),
            'items': _itemsToJson(items),
          })
          .select()
          .single();
    });
    await refreshCounts();
    return SavedComparison.fromJson(row);
  }

  /// 「更新這筆」：名稱不變，換掉商品與數字
  Future<SavedComparison> updateContent({
    required String comparisonId,
    required ClaimScenarioInput scenario,
    required List<SavedComparisonItem> items,
  }) async {
    _ensureOnline();
    validateItems(items);
    final Map<String, dynamic> row = await _runWrite(() {
      return _supabase
          .from(_tableName)
          .update({
            'scenario': SavedComparisonScenario.toJson(scenario),
            'items': _itemsToJson(items),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', comparisonId)
          .select()
          .single();
    });
    return SavedComparison.fromJson(row);
  }

  Future<void> rename({required String comparisonId, required String newName}) async {
    _ensureOnline();
    final String normalizedName = normalizeName(newName);
    await _runWrite(() {
      return _supabase
          .from(_tableName)
          .update({
            'name': normalizedName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', comparisonId)
          .select()
          .single();
    });
  }

  Future<void> delete(String comparisonId) async {
    _ensureOnline();
    await _supabase.from(_tableName).delete().eq('id', comparisonId);
    await refreshCounts();
  }

  void _ensureOnline() {
    if (isOfflineMode) {
      throw const SavedComparisonException('離線模式無法使用比較清單');
    }
  }

  List<Map<String, dynamic>> _itemsToJson(List<SavedComparisonItem> items) {
    final List<Map<String, dynamic>> itemRows = [];
    for (final SavedComparisonItem item in items) {
      itemRows.add(item.toJson());
    }
    return itemRows;
  }

  /// 執行寫入；同一位客戶名稱重複時，轉成業務員看得懂的訊息
  Future<Map<String, dynamic>> _runWrite(Future<Map<String, dynamic>> Function() write) async {
    try {
      return await write();
    } on PostgrestException catch (error) {
      if (error.code == _uniqueViolationCode) {
        throw const SavedComparisonException('這位客戶已經有同名的比較，請換一個名稱');
      }
      rethrow;
    }
  }
}
