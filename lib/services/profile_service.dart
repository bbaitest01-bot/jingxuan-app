import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/user_role.dart';

/// 首頁頂欄與側邊欄要顯示的登入者資料
class UserProfileSummary {
  final String name;
  final String email;
  final String avatarUrl;

  /// null 代表這次沒有讀到角色，畫面應保留原本的角色
  final UserRole? role;

  const UserProfileSummary({
    required this.name,
    required this.email,
    required this.avatarUrl,
    this.role,
  });
}

/// 讀取登入者個人資料（profiles 表）的服務
class ProfileService {
  static final ProfileService instance = ProfileService._internal();
  ProfileService._internal();

  /// 讀取目前登入者的名稱、信箱、大頭貼與角色。
  /// 回傳 null 代表目前沒有登入者，畫面應保留原本的資料。
  Future<UserProfileSummary?> loadCurrentUserSummary() async {
    if (isOfflineMode) {
      return _loadOfflineSummary();
    }

    try {
      final SupabaseClient supabase = Supabase.instance.client;
      final User? user = supabase.auth.currentUser;
      if (user == null) return null;

      final Map<String, dynamic>? data = await supabase
          .from('profiles')
          .select('full_name, email, avatar_url, role')
          .eq('id', user.id)
          .maybeSingle();
      return _buildSummary(user, data);
    } catch (e) {
      return _buildFallbackSummary();
    }
  }

  // 離線預覽模式：從本機偏好設定讀取，角色固定為業務員
  Future<UserProfileSummary> _loadOfflineSummary() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return UserProfileSummary(
      name: prefs.getString('profile_name') ?? '王大同 業務代表',
      email: 'offline@insurance.helper',
      avatarUrl: prefs.getString('profile_avatar_url') ?? '',
      role: UserRole.agent,
    );
  }

  // 把 profiles 表的資料整理成畫面要用的格式；表裡沒有的欄位改用登入資訊補上
  UserProfileSummary _buildSummary(User user, Map<String, dynamic>? data) {
    String name;
    if (data != null && data['full_name'] != null) {
      name = data['full_name'] as String;
    } else {
      name = user.userMetadata?['full_name'] ?? '新業務代表';
    }

    UserRole? role;
    if (data != null && data['role'] != null) {
      role = UserRole.fromString(data['role'] as String);
    }

    // 信箱優先用 profiles 表的，沒有再用登入帳號的
    String email = user.email ?? '';
    if (data != null && data['email'] != null) {
      email = data['email'] as String;
    }

    return UserProfileSummary(
      name: name,
      email: email,
      avatarUrl: data?['avatar_url'] ?? '',
      role: role,
    );
  }

  // 讀取 profiles 失敗時，只用登入資訊顯示名稱與信箱，角色維持不變
  UserProfileSummary _buildFallbackSummary() {
    final User? user = Supabase.instance.client.auth.currentUser;
    final String email = user?.email ?? '';

    // 名稱依序嘗試：註冊時填的姓名 → 信箱 → 預設文字
    final String? metadataName = user?.userMetadata?['full_name'];
    String fallbackName;
    if (metadataName != null) {
      fallbackName = metadataName;
    } else {
      fallbackName = user?.email ?? '業務代表';
    }

    return UserProfileSummary(
      name: fallbackName,
      email: email,
      avatarUrl: '',
    );
  }
}
