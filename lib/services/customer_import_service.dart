import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// 批次匯入的結果
class CustomerImportResult {
  final int processedCount;
  final int failedCount;

  const CustomerImportResult({required this.processedCount, required this.failedCount});
}

/// 客戶批次匯入（CSV／Excel）寫入資料庫。從 CustomerService 拆出，邏輯不變
class CustomerImportService {
  static final CustomerImportService instance = CustomerImportService._internal();
  CustomerImportService._internal();

  /// 批次匯入客戶：同名或同電話視為重複，依 duplicateStrategy（skip／overwrite）處理
  Future<CustomerImportResult> importCustomers({
    required List<Map<String, dynamic>> importedList,
    required String duplicateStrategy,
    required List<Map<String, dynamic>> existingCustomers,
  }) async {
    int processedCount = 0;
    int failedCount = 0;

    // 維護本機工作清單，防止同批次重複客戶覆蓋競態
    List<Map<String, dynamic>> localWorkingCustomers = existingCustomers.map((c) => Map<String, dynamic>.from(c)).toList();

    for (var item in importedList) {
      final name = item['name']?.toString().trim() ?? '';
      final phone = item['phone']?.toString().trim() ?? '';
      final nickname = item['nickname']?.toString().trim() ?? '';
      final email = item['email']?.toString().trim() ?? '';
      final tags = List<String>.from(item['tags'] ?? []);
      final notes = item['notes']?.toString().trim() ?? '';
      final String? gender = item['gender'] as String?; // male／female／null（4-3b）
      final customAttrs = (item['custom_attributes'] is Map)
          ? Map<String, dynamic>.from(item['custom_attributes'])
          : <String, dynamic>{};

      final existingIdx = localWorkingCustomers.indexWhere((c) =>
          (phone.isNotEmpty && c['phone'] == phone) ||
          (name.isNotEmpty && c['name'] == name));

      if (existingIdx != -1) {
        if (duplicateStrategy == 'skip') {
          continue;
        } else if (duplicateStrategy == 'overwrite') {
          final existingId = localWorkingCustomers[existingIdx]['id'];
          final existingAttrs = (localWorkingCustomers[existingIdx]['custom_attributes'] is Map)
              ? Map<String, dynamic>.from(localWorkingCustomers[existingIdx]['custom_attributes'])
              : <String, dynamic>{};
          final mergedAttrs = {...existingAttrs, ...customAttrs};

          final updatedCustomerMap = {
            ...localWorkingCustomers[existingIdx],
            'name': name,
            'nickname': nickname.isNotEmpty ? nickname : localWorkingCustomers[existingIdx]['nickname'],
            'phone': phone.isNotEmpty ? phone : localWorkingCustomers[existingIdx]['phone'],
            'email': email.isNotEmpty ? email : localWorkingCustomers[existingIdx]['email'],
            'tags': tags.isNotEmpty ? tags : localWorkingCustomers[existingIdx]['tags'],
            'notes': notes.isNotEmpty ? notes : localWorkingCustomers[existingIdx]['notes'],
            'gender': gender ?? localWorkingCustomers[existingIdx]['gender'],
            'custom_attributes': mergedAttrs,
          };

          if (isOfflineMode) {
            localWorkingCustomers[existingIdx] = updatedCustomerMap;
            processedCount++;
          } else {
            try {
              await Supabase.instance.client.from('customers').update({
                'name': updatedCustomerMap['name'],
                'nickname': updatedCustomerMap['nickname'],
                'phone': updatedCustomerMap['phone'],
                'email': updatedCustomerMap['email'],
                'tags': updatedCustomerMap['tags'],
                'notes': updatedCustomerMap['notes'],
                'gender': updatedCustomerMap['gender'],
                'custom_attributes': mergedAttrs,
              }).eq('id', existingId);

              localWorkingCustomers[existingIdx] = updatedCustomerMap;
              processedCount++;
            } catch (e) {
              failedCount++;
            }
          }
          continue;
        }
      }

      // 新增客戶
      if (isOfflineMode) {
        final newCust = {
          'id': 'offline_${DateTime.now().millisecondsSinceEpoch}_$processedCount',
          'name': name,
          'nickname': nickname,
          'phone': phone,
          'email': email,
          'tags': tags,
          'notes': notes,
          'gender': gender,
          'custom_attributes': customAttrs,
          'created_at': DateTime.now().toIso8601String(),
        };
        localWorkingCustomers.add(newCust);
        processedCount++;
      } else {
        try {
          final user = Supabase.instance.client.auth.currentUser;
          if (user == null) throw Exception('使用者未登入');

          final insertResp = await Supabase.instance.client.from('customers').insert({
            'profile_id': user.id,
            'name': name,
            'nickname': nickname,
            'avatar_url': '',
            'phone': phone,
            'email': email,
            'tags': tags,
            'notes': notes,
            'gender': gender,
            'custom_attributes': customAttrs,
          }).select('id').single();

          localWorkingCustomers.add({
            'id': insertResp['id'],
            'name': name,
            'nickname': nickname,
            'phone': phone,
            'email': email,
            'tags': tags,
            'notes': notes,
            'gender': gender,
            'custom_attributes': customAttrs,
          });
          processedCount++;
        } catch (e) {
          failedCount++;
        }
      }
    }

    return CustomerImportResult(processedCount: processedCount, failedCount: failedCount);
  }
}
