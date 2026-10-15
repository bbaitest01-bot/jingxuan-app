import 'dart:typed_data';
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
  final String? gender; // male 男／female 女／null 不填（4-3b）
  final String? clientStatus; // positive ✔／considering △／negative ✖／null 未設定（4-3c）
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
    this.gender,
    this.clientStatus,
    required this.imageBytes,
    required this.imageName,
    required this.isImageCleared,
  });
}

/// 客戶管理頁用到的資料庫存取（customers 等表；專案改由 VisitProjectService）。
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

    final List<Map<String, dynamic>> customers = [];
    for (final dynamic row in response) {
      customers.add(_toDisplayCustomer(row as Map<String, dynamic>));
    }

    // 存一份給下次回到客戶管理時先顯示
    _cachedCustomers = List<Map<String, dynamic>>.from(customers);
    _cachedForUserId = currentUserId;
    return customers;
  }

  /// 讀取單一位客戶（客戶細節整頁用）；找不到、已刪除或沒有權限回傳 null
  Future<Map<String, dynamic>?> fetchCustomer(String id) async {
    if (isOfflineMode) {
      for (final Map<String, dynamic> customer in OfflineDataStore.customers) {
        if (customer['id'].toString() == id && customer['deleted_at'] == null) return customer;
      }
      return null;
    }
    // 編號格式不對時資料庫會報錯，當作找不到
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) return null;
    final Map<String, dynamic>? row = await _supabase
        .from('customers')
        .select('*, profiles:profile_id(id, full_name, email, role, team_name)')
        .eq('id', id)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) return null;
    return _toDisplayCustomer(row);
  }

  // 資料庫的一筆客戶 → 畫面要用的格式（列表與細節頁共用）
  Map<String, dynamic> _toDisplayCustomer(Map<String, dynamic> data) {
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
      'gender': data['gender'],
      'client_status': data['client_status'],
      'status': data['status'] ?? 'active',
      // Convert postgres array text[] to List<String> safely
      'tags': List<String>.from(data['tags'] ?? []),
      'notes': data['notes'],
      'custom_attributes': customAttrs,
      'created_at': data['created_at'],
      'deleted_at': data['deleted_at'],
    };
  }

  // ---------------------------------------------------------------------------
  // 性別（4-3b）：資料庫存 male／female，空的代表不填
  // ---------------------------------------------------------------------------
  static const String genderMale = 'male';
  static const String genderFemale = 'female';

  /// 畫面上顯示的文字：男／女／不填
  static String genderLabel(String? gender) {
    if (gender == genderMale) return '男';
    if (gender == genderFemale) return '女';
    return '不填';
  }

  /// 匯入時把各種寫法轉成 male／female；認不得的當作不填（回傳 null）
  static String? parseGender(String? text) {
    final String value = (text ?? '').trim().toLowerCase();
    const List<String> maleWords = ['男', '男性', 'm', 'male', '先生'];
    const List<String> femaleWords = ['女', '女性', 'f', 'female', '小姐'];
    if (maleWords.contains(value)) return genderMale;
    if (femaleWords.contains(value)) return genderFemale;
    return null;
  }

  // ---------------------------------------------------------------------------
  // 客戶狀態 ✔／△／✖（4-3c，手動設定；之後專案拜訪結果 P3 用同一套）
  // ---------------------------------------------------------------------------
  static const String statusPositive = 'positive';
  static const String statusConsidering = 'considering';
  static const String statusNegative = 'negative';
  static const List<String?> clientStatusOptions = [statusPositive, statusConsidering, statusNegative, null];

  /// 符號：✔／△／✖；未設定是空字串
  static String clientStatusSymbol(String? status) {
    if (status == statusPositive) return '✔';
    if (status == statusConsidering) return '△';
    if (status == statusNegative) return '✖';
    return '';
  }

  /// 中文說明
  static String clientStatusLabel(String? status) {
    if (status == statusPositive) return '有意願／已成交';
    if (status == statusConsidering) return '考慮中／待跟進';
    if (status == statusNegative) return '無意願／暫不考慮';
    return '未設定';
  }

  /// 匯入時把各種寫法轉成代碼；認不得的當未設定（回傳 null）
  static String? parseClientStatus(String? text) {
    final String value = (text ?? '').trim().toLowerCase();
    if (value.isEmpty) return null;
    const List<String> positiveWords = ['✔', '✓', 'v', 'o', '有意願', '已成交', '成交', 'positive'];
    const List<String> consideringWords = ['△', '考慮中', '待跟進', '考慮', 'considering'];
    const List<String> negativeWords = ['✖', '✗', 'x', '無意願', '拒絕', '暫不考慮', 'negative'];
    if (positiveWords.contains(value) || value.startsWith('✔')) return statusPositive;
    if (consideringWords.contains(value) || value.startsWith('△')) return statusConsidering;
    if (negativeWords.contains(value) || value.startsWith('✖')) return statusNegative;
    return null;
  }

  /// 只留下電話裡的數字（拿掉 -、空白、括號等），讓 0912-345-678 和 0912345678 可以互相比對
  static String phoneDigits(String text) {
    return text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // 搜尋文字看起來像電話（只有數字、-、空白、括號、+）才用電話比對，
  // 避免像「王1」這種搜尋被拆成數字「1」而比對到一大堆電話
  static bool _looksLikePhoneQuery(String query) {
    return RegExp(r'^[0-9\s\-()+]+$').hasMatch(query) && phoneDigits(query).isNotEmpty;
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

    // 沒輸入、或只輸入符號（例如只打一個「-」，通常是電話打到一半）時，當作還沒搜尋，顯示全部
    final bool hasSearchableText = RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(query);
    if (!hasSearchableText) {
      return List.from(activeCustomers);
    }
    final bool isPhoneQuery = _looksLikePhoneQuery(query);
    final String queryDigits = phoneDigits(query);
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
      // 電話只比數字，所以搜「0912-345」「345」都找得到 0912-345-678（問題 C1）
      final String customerPhoneDigits = phoneDigits((customer['phone'] ?? '').toString());
      final bool matchesPhone = isPhoneQuery && customerPhoneDigits.contains(queryDigits);

      return matchesName || matchesNotes || matchesTags || matchesAgent || matchesPhone;
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
      'gender': form.gender,
      'client_status': form.clientStatus,
      'custom_attributes': const <String, dynamic>{},
    });
  }

  /// 修改一位客戶。表單沒有自訂欄位，所以不送 custom_attributes，
  /// 資料庫裡原本的自訂欄位（例如批次匯入帶進來的）會保留（問題 C14）
  Future<void> updateCustomer(String id, CustomerFormData form, String avatarUrl) async {
    await _supabase.from('customers').update({
      'name': form.name,
      'nickname': form.nickname,
      'avatar_url': avatarUrl,
      'phone': form.phone,
      'email': form.email,
      'tags': form.tags,
      'notes': form.notes,
      'gender': form.gender,
      'client_status': form.clientStatus,
    }).eq('id', id);
  }

  /// 客戶詳情抽屜的「儲存基本資料」。抽屜可以編輯自訂欄位，所以一起存。
  /// 客戶表沒有 status 欄位，不能送（以前送了會整筆存檔失敗，問題 C18）；失敗會丟出例外
  Future<void> updateCustomerBasicInfo({
    required String id,
    required String name,
    required String nickname,
    required String phone,
    required String email,
    required String? gender,
    required String? clientStatus,
    required String notes,
    required List<String> tags,
    required Map<String, dynamic> customAttributes,
  }) async {
    await _supabase.from('customers').update({
      'name': name,
      'nickname': nickname,
      'phone': phone,
      'email': email,
      'gender': gender,
      'client_status': clientStatus,
      'notes': notes,
      'tags': tags,
      'custom_attributes': customAttributes,
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
}
