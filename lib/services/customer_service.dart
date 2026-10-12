import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// 客戶表單送出的資料（新增與編輯共用）
class CustomerFormData {
  final String name;
  final String nickname;
  final String phone;
  final String email;
  final List<String> tags;
  final String notes;
  final Uint8List? imageBytes;
  final String? imageName;
  final bool isImageCleared;

  const CustomerFormData({
    required this.name,
    required this.nickname,
    required this.phone,
    required this.email,
    required this.tags,
    required this.notes,
    required this.imageBytes,
    required this.imageName,
    required this.isImageCleared,
  });
}

/// 批次匯入的結果
class CustomerImportResult {
  final int processedCount;
  final int failedCount;

  const CustomerImportResult({required this.processedCount, required this.failedCount});
}

/// 客戶管理頁用到的資料庫存取（customers、visit_projects 等表）。
/// 只負責讀寫資料；離線模式的提示與畫面更新留在畫面。
class CustomerService {
  static final CustomerService instance = CustomerService._internal();
  CustomerService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  // 上次讀到的客戶名單與它屬於哪個登入者：回到客戶管理時先顯示，不用等重新讀取
  List<Map<String, dynamic>>? _cachedCustomers;
  String? _cachedForUserId;

  /// 目前登入者上次讀到的客戶名單；沒有讀過、或換了人時回傳 null
  List<Map<String, dynamic>>? cachedCustomersForCurrentUser() {
    final List<Map<String, dynamic>>? cachedCustomers = _cachedCustomers;
    if (cachedCustomers == null) return null;
    if (_cachedForUserId == null || _cachedForUserId != currentUserId) return null;
    return List<Map<String, dynamic>>.from(cachedCustomers);
  }

  /// 清掉暫存的客戶名單（登出或換人時呼叫）
  void clearCache() {
    _cachedCustomers = null;
    _cachedForUserId = null;
  }

  /// 目前登入者的 id；沒有登入時是 null
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// 目前登入者是否為開發者（profiles.role == 'dev'）
  Future<bool> isCurrentUserDev() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return false;
    final Map<String, dynamic>? profile = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return profile != null && profile['role'] == 'dev';
  }

  /// 讀取所有未刪除的客戶（RLS 決定看得到哪些），並整理成畫面要用的格式
  Future<List<Map<String, dynamic>>> fetchActiveCustomers() async {
    final response = await _supabase
        .from('customers')
        .select('*, profiles:profile_id(id, full_name, email, role, team_name)')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> customers = List<Map<String, dynamic>>.from(response.map((data) {
      final profile = data['profiles'] as Map<String, dynamic>?;
      final String agentFullName = profile?['full_name'] as String? ?? '';
      final String agentEmail = profile?['email'] as String? ?? '';
      final String agentTeam = profile?['team_name'] as String? ?? 'TAIPEI-01';
      final String displayAgent = agentFullName.isNotEmpty ? agentFullName : (agentEmail.isNotEmpty ? agentEmail : '未知業務員');

      Map<String, dynamic> customAttrs = {};
      if (data['custom_attributes'] is Map) {
        customAttrs = Map<String, dynamic>.from(data['custom_attributes']);
      }

      return {
        'id': data['id'],
        'profile_id': data['profile_id']?.toString() ?? '',
        'agent_name': displayAgent,
        'agent_email': agentEmail,
        'agent_team': agentTeam,
        'name': data['name'],
        'nickname': data['nickname'] ?? '',
        'avatar_url': data['avatar_url'] ?? '',
        'phone': data['phone'],
        'email': data['email'],
        'status': data['status'] ?? 'active',
        // Convert postgres array text[] to List<String> safely
        'tags': List<String>.from(data['tags'] ?? []),
        'notes': data['notes'],
        'custom_attributes': customAttrs,
        'created_at': data['created_at'],
        'deleted_at': data['deleted_at'],
      };
    }));

    // 存一份給下次回到客戶管理時先顯示
    _cachedCustomers = List<Map<String, dynamic>>.from(customers);
    _cachedForUserId = currentUserId;
    return customers;
  }

  /// 依搜尋文字與開發者範圍，篩出畫面要顯示的客戶
  List<Map<String, dynamic>> filterCustomers({
    required List<Map<String, dynamic>> allCustomers,
    required String query,
    required bool onlyMine,
    required String? currentUserId,
  }) {
    var activeCustomers = allCustomers.where((c) => c['deleted_at'] == null).toList();

    // 開發者選「僅我建立的」時，只留自己的客戶
    if (onlyMine && currentUserId != null) {
      activeCustomers = activeCustomers.where((c) => c['profile_id'] == currentUserId).toList();
    }

    if (query.isEmpty) {
      return List.from(activeCustomers);
    }
    return activeCustomers.where((customer) {
      final name = (customer['name'] ?? '').toString().toLowerCase();
      final nickname = (customer['nickname'] ?? '').toString().toLowerCase();
      final notes = (customer['notes'] ?? '').toString().toLowerCase();
      final agentName = (customer['agent_name'] ?? '').toString().toLowerCase();
      final List tags = customer['tags'] ?? [];

      final matchesName = name.contains(query) || nickname.contains(query);
      final matchesNotes = notes.contains(query);
      final matchesAgent = agentName.contains(query);
      final matchesTags = tags.any((tag) => tag.toString().toLowerCase().contains(query));

      return matchesName || matchesNotes || matchesTags || matchesAgent;
    }).toList();
  }

  /// 上傳大頭貼到 customer-photos，回傳公開網址；失敗會丟出例外
  Future<String> uploadAvatar(Uint8List imageBytes, String imageName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('使用者未登入');

    final extension = imageName.contains('.')
        ? imageName.split('.').last
        : 'jpg';
    final cleanExtension = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(extension) ? extension : 'jpg';
    final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$cleanExtension';

    await _supabase.storage.from('customer-photos').uploadBinary(
      fileName,
      imageBytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    return _supabase.storage.from('customer-photos').getPublicUrl(fileName);
  }

  /// 決定存檔時的大頭貼網址：清除照片就是空字串；選了新照片就先上傳；都沒有就沿用原本的網址。
  /// 上傳失敗會丟出例外
  Future<String> resolveAvatarUrl(CustomerFormData form, String existingAvatarUrl) async {
    if (form.isImageCleared) return '';
    final Uint8List? imageBytes = form.imageBytes;
    final String? imageName = form.imageName;
    if (imageBytes != null && imageName != null) {
      return uploadAvatar(imageBytes, imageName);
    }
    return existingAvatarUrl;
  }

  /// 新增一位客戶（歸屬目前登入者）
  Future<void> createCustomer(CustomerFormData form, String avatarUrl) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('使用者未登入');

    await _supabase.from('customers').insert({
      'profile_id': user.id,
      'name': form.name,
      'nickname': form.nickname,
      'avatar_url': avatarUrl,
      'phone': form.phone,
      'email': form.email,
      'tags': form.tags,
      'notes': form.notes,
      'custom_attributes': const <String, dynamic>{},
    });
  }

  /// 修改一位客戶
  Future<void> updateCustomer(String id, CustomerFormData form, String avatarUrl) async {
    await _supabase.from('customers').update({
      'name': form.name,
      'nickname': form.nickname,
      'avatar_url': avatarUrl,
      'phone': form.phone,
      'email': form.email,
      'tags': form.tags,
      'notes': form.notes,
      'custom_attributes': const <String, dynamic>{},
    }).eq('id', id);
  }

  /// 把客戶移到垃圾桶（寫入 deleted_at，可還原）
  Future<void> moveCustomersToTrash(List<String> ids) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _supabase
        .from('customers')
        .update({'deleted_at': now})
        .filter('id', 'in', ids);
  }

  /// 離線預覽模式：只在畫面資料上標記刪除時間（不寫資料庫），回傳新的客戶清單
  List<Map<String, dynamic>> markCustomersDeletedLocally(List<Map<String, dynamic>> customers, List<String> ids) {
    final String now = DateTime.now().toUtc().toIso8601String();
    final List<Map<String, dynamic>> updatedCustomers = List<Map<String, dynamic>>.from(customers);
    for (final String id in ids) {
      final int index = updatedCustomers.indexWhere((c) => c['id'] == id);
      if (index != -1) {
        updatedCustomers[index] = {
          ...updatedCustomers[index],
          'deleted_at': now,
        };
      }
    }
    return updatedCustomers;
  }

  /// 把單一客戶移到垃圾桶
  Future<void> moveCustomerToTrash(String id) async {
    await _supabase.from('customers').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// 建立拜訪專案，並把客戶加入專案的拜訪清單
  Future<void> createVisitProject({
    required String title,
    required String purpose,
    required List<Map<String, dynamic>> customers,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('使用者未登入');

    // 1. Insert into visit_projects
    final projectResult = await _supabase.from('visit_projects').insert({
      'profile_id': user.id,
      'title': title,
      'purpose': purpose,
    }).select().single();

    final String projectId = projectResult['id'];

    // 2. Insert into visit_project_customers
    final List<Map<String, dynamic>> projectCustomers = customers.map((customer) {
      return {
        'visit_project_id': projectId,
        'customer_id': customer['id'],
        'is_visited': false,
      };
    }).toList();

    await _supabase.from('visit_project_customers').insert(projectCustomers);
  }

  /// 離線預覽模式：把拜訪專案存到瀏覽器本機
  Future<void> createOfflineVisitProject({
    required String title,
    required String purpose,
    required List<Map<String, dynamic>> customers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String projectId = 'mock-proj-${DateTime.now().millisecondsSinceEpoch}';

    // 1. Save new project metadata
    final projectJson = {
      'id': projectId,
      'title': title,
      'purpose': purpose,
      'is_completed': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    List<dynamic> localProjects = [];
    final storedProjects = prefs.getString('offline_visit_projects');
    if (storedProjects != null) {
      localProjects = jsonDecode(storedProjects);
    }
    localProjects.insert(0, projectJson);
    await prefs.setString('offline_visit_projects', jsonEncode(localProjects));

    // 2. Save project checklist customers
    final List<Map<String, dynamic>> projectCustomers = [];
    for (var i = 0; i < customers.length; i++) {
      final customer = customers[i];
      projectCustomers.add({
        'id': 'mock-vpc-$projectId-$i',
        'visit_project_id': projectId,
        'customer_id': customer['id'],
        'is_visited': false,
        'created_at': DateTime.now().toIso8601String(),
        'customer': {
          'id': customer['id'],
          'name': customer['name'],
          'nickname': customer['nickname'],
          'phone': customer['phone'],
          'email': customer['email'],
          'tags': customer['tags'],
          'avatar_url': customer['avatar_url'],
          'notes': customer['notes'],
        }
      });
    }

    List<dynamic> localProjCustomers = [];
    final storedProjCustomers = prefs.getString('offline_visit_project_customers');
    if (storedProjCustomers != null) {
      localProjCustomers = jsonDecode(storedProjCustomers);
    }
    localProjCustomers.addAll(projectCustomers);
    await prefs.setString('offline_visit_project_customers', jsonEncode(localProjCustomers));
  }

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
            'custom_attributes': mergedAttrs,
          };

          if (isOfflineMode) {
            localWorkingCustomers[existingIdx] = updatedCustomerMap;
            processedCount++;
          } else {
            try {
              await _supabase.from('customers').update({
                'name': updatedCustomerMap['name'],
                'nickname': updatedCustomerMap['nickname'],
                'phone': updatedCustomerMap['phone'],
                'email': updatedCustomerMap['email'],
                'tags': updatedCustomerMap['tags'],
                'notes': updatedCustomerMap['notes'],
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
          'custom_attributes': customAttrs,
          'created_at': DateTime.now().toIso8601String(),
        };
        localWorkingCustomers.add(newCust);
        processedCount++;
      } else {
        try {
          final user = _supabase.auth.currentUser;
          if (user == null) throw Exception('使用者未登入');

          final insertResp = await _supabase.from('customers').insert({
            'profile_id': user.id,
            'name': name,
            'nickname': nickname,
            'avatar_url': '',
            'phone': phone,
            'email': email,
            'tags': tags,
            'notes': notes,
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
