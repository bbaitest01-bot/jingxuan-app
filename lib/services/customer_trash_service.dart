import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// 垃圾桶裡的客戶：讀取、還原、永久刪除。
/// 2026-10-14（4-D）從 trash_bin_screen.dart 搬出來，畫面只負責顯示（CLAUDE.md：業務邏輯寫在 services）。
class CustomerTrashService {
  static final CustomerTrashService instance = CustomerTrashService._internal();
  CustomerTrashService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 已放進垃圾桶的客戶（最近刪除的在前）
  Future<List<Map<String, dynamic>>> fetchDeletedCustomers() async {
    if (isOfflineMode) {
      return OfflineDataStore.customers.where((customer) => customer['deleted_at'] != null).toList();
    }

    final List<dynamic> rows = await _supabase
        .from('customers')
        .select()
        .not('deleted_at', 'is', null)
        .order('deleted_at', ascending: false);

    final List<Map<String, dynamic>> customers = [];
    for (final dynamic row in rows) {
      final Map<String, dynamic> data = row as Map<String, dynamic>;
      customers.add({
        'id': data['id'],
        'name': data['name'],
        'nickname': data['nickname'] ?? '',
        'avatar_url': data['avatar_url'] ?? '',
        'phone': data['phone'],
        'email': data['email'],
        'status': data['status'] ?? 'active',
        'tags': List<String>.from(data['tags'] ?? []),
        'notes': data['notes'],
        'created_at': data['created_at'],
        'deleted_at': data['deleted_at'],
      });
    }
    return customers;
  }

  /// 從垃圾桶還原客戶
  Future<void> restoreCustomer(String id) async {
    if (isOfflineMode) {
      final int index = OfflineDataStore.customers.indexWhere((customer) => customer['id'] == id);
      if (index != -1) {
        OfflineDataStore.customers[index] = {...OfflineDataStore.customers[index], 'deleted_at': null};
      }
      return;
    }
    await _supabase.from('customers').update({'deleted_at': null}).eq('id', id);
  }

  /// 永久刪除客戶（救不回來）
  Future<void> deleteCustomerForever(String id) async {
    if (isOfflineMode) {
      OfflineDataStore.customers.removeWhere((customer) => customer['id'] == id);
      return;
    }
    await _supabase.from('customers').delete().eq('id', id);
  }
}
