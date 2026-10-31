import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../models/user_role.dart';
import '../screens/profile/profile_editor_state.dart';
import '../screens/profile/card_templates/card_template_registry.dart';
import 'profile_service.dart';
import 'storage_file_cleanup.dart';

/// 個人帳號頁的讀取與儲存（2026-10-31 從 profile_screen.dart 搬出，邏輯不變）
///
/// - 讀：`profiles` 表的個人資料與名片欄位，填進 [ProfileEditorState]
/// - 存：有新照片先上傳 Storage，再更新 `profiles`；存成功才刪舊照片
/// - 離線預覽模式改存在本機
class ProfileEditorService {
  // 上次讀到的個人資料：切頁回來時先顯示這份，不會先空白再跳出來（2026-10-19）
  // 存帳號 id，換人登入時不會看到上一位的資料
  static Map<String, dynamic>? _cachedRow;
  static String? _cachedUserId;

  static SupabaseClient get _supabase => Supabase.instance.client;

  /// 有上次讀到的資料就先填上（同一個帳號才用）；有填回傳 true
  static bool applyCached(ProfileEditorState state) {
    if (isOfflineMode) return false;
    final Map<String, dynamic>? row = _cachedRow;
    final User? user = _supabase.auth.currentUser;
    if (row == null || user == null || _cachedUserId != user.id) return false;
    _applyRow(state, row, user);
    return true;
  }

  /// 從資料庫（或離線模式的本機）讀個人資料
  static Future<void> load(ProfileEditorState state) async {
    if (isOfflineMode) {
      await _loadOffline(state);
      return;
    }
    final User? user = _supabase.auth.currentUser;
    if (user == null) return;
    final Map<String, dynamic>? row = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    if (row == null) return;
    _cachedRow = row;
    _cachedUserId = user.id;
    _applyRow(state, row, user);
  }

  static void _applyRow(ProfileEditorState state, Map<String, dynamic> row, User user) {
    state.email = user.email ?? '';
    state.nameController.text = row['full_name'] ?? '';
    state.phoneController.text = row['phone'] ?? '';
    state.lineIdController.text = row['line_id'] ?? '';
    state.companyController.text = row['company'] ?? '';
    state.jobTitleController.text = row['job_title'] ?? '';
    state.websiteController.text = row['website'] ?? '';
    state.addressController.text = row['address'] ?? '';
    state.bioController.text = row['bio'] ?? '';
    state.licenseNoController.text = row['license_no'] ?? '';
    state.avatarUrl = row['avatar_url'] ?? '';
    state.qrCodeUrl = row['qr_code_url'] ?? '';
    state.role = UserRole.fromString(row['role']);
    state.accountStatus = row['status'] ?? (user.userMetadata?['status'] ?? 'active');
    final bool? savedGoogle = row['is_google_connected'] as bool?;
    state.isGoogleConnected = savedGoogle ?? (user.identities?.any((identity) => identity.provider == 'google') ?? false);
    _applyTemplate(state, row['card_theme'] as String?);
    _applyHonorAndBadges(state, row['honor_title'] ?? '', List<String>.from(row['badges'] ?? []));
    state.changed();
  }

  static void _applyTemplate(ProfileEditorState state, String? saved) {
    final (String templateKey, int colorwayIndex) = CardTemplateRegistry.parse(saved);
    state.templateKey = templateKey;
    state.colorwayIndex = colorwayIndex;
  }

  // 自訂的頭銜、徽章不在預設清單裡，要補進可選清單，不然畫面上看不到
  static void _applyHonorAndBadges(ProfileEditorState state, String honorTitle, List<String> badges) {
    state.honorTitle = honorTitle;
    if (honorTitle.isNotEmpty && !state.availableHonorTitles.contains(honorTitle)) {
      state.availableHonorTitles.add(honorTitle);
    }
    state.selectedBadges = badges.toSet();
    for (final String badge in badges) {
      if (!state.availableBadges.contains(badge)) state.availableBadges.add(badge);
    }
  }

  static Future<void> _loadOffline(ProfileEditorState state) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state.email = 'offline@insurance.helper';
    state.nameController.text = prefs.getString('profile_name') ?? '';
    state.phoneController.text = prefs.getString('profile_phone') ?? '';
    state.lineIdController.text = prefs.getString('profile_line_id') ?? '';
    state.companyController.text = prefs.getString('profile_company') ?? '';
    state.jobTitleController.text = prefs.getString('profile_job_title') ?? '';
    state.licenseNoController.text = prefs.getString('profile_license_no') ?? '';
    state.websiteController.text = prefs.getString('profile_website') ?? '';
    state.addressController.text = prefs.getString('profile_address') ?? '';
    state.bioController.text = prefs.getString('profile_bio') ?? '';
    state.avatarUrl = prefs.getString('profile_avatar_url') ?? '';
    _applyTemplate(state, prefs.getString('profile_theme'));
    state.role = UserRole.fromString(prefs.getString('profile_role'));
    state.isGoogleConnected = prefs.getBool('profile_is_google_connected') ?? false;
    _applyHonorAndBadges(state, prefs.getString('profile_honor_title') ?? '', prefs.getStringList('profile_badges') ?? []);
    state.changed();
  }

  /// 儲存；失敗會丟出例外，由畫面顯示錯誤
  static Future<void> save(ProfileEditorState state) async {
    if (isOfflineMode) {
      await _saveOffline(state);
      return;
    }
    final User? user = _supabase.auth.currentUser;
    if (user == null) throw Exception('使用者未登入');

    final String oldAvatarUrl = state.avatarUrl;
    final String finalAvatarUrl = await _resolveAvatarUrl(state, user);
    String finalQrCodeUrl = state.qrCodeUrl;
    final Uint8List? newQrCode = state.newQrCodeBytes;
    if (newQrCode != null) finalQrCodeUrl = await ProfileService.instance.uploadQrCodeImage(newQrCode);

    await _supabase.from('profiles').update({
      'full_name': state.nameController.text.trim(),
      'phone': state.phoneController.text.trim(),
      'company': state.companyController.text.trim(),
      'job_title': state.jobTitleController.text.trim(),
      'website': state.websiteController.text.trim(),
      'address': state.addressController.text.trim(),
      'bio': state.bioController.text.trim(),
      'avatar_url': finalAvatarUrl,
      'is_google_connected': state.isGoogleConnected,
      'line_id': state.lineIdController.text.trim(),
      'license_no': state.licenseNoController.text.trim(),
      'honor_title': state.honorTitle,
      'badges': state.selectedBadges.toList(),
      'card_theme': CardTemplateRegistry.format(state.templateKey, state.colorwayIndex),
      'qr_code_url': finalQrCodeUrl.isEmpty ? null : finalQrCodeUrl,
    }).eq('id', user.id);

    // 資料存成功後才刪舊大頭照（Supabase 不准用 SQL 刪照片，全景地圖 4-O）
    await StorageFileCleanup.removeReplacedFile(
      oldPublicUrl: oldAvatarUrl,
      newPublicUrl: finalAvatarUrl,
      bucket: StorageFileCleanup.avatarBucket,
    );
    _markSaved(state, finalAvatarUrl, finalQrCodeUrl);
    await load(state);
  }

  // 新選的大頭貼先上傳，回傳要存的網址；按了移除就存空字串
  static Future<String> _resolveAvatarUrl(ProfileEditorState state, User user) async {
    if (state.isAvatarCleared) return '';
    final Uint8List? bytes = state.newAvatarBytes;
    if (bytes == null) return state.avatarUrl;
    final String originalName = state.newAvatarName ?? 'avatar.jpg';
    String extension = 'jpg';
    if (originalName.contains('.')) extension = originalName.split('.').last;
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(extension)) extension = 'jpg';
    final String fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _supabase.storage.from('avatars').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _supabase.storage.from('avatars').getPublicUrl(fileName);
  }

  static void _markSaved(ProfileEditorState state, String avatarUrl, String qrCodeUrl) {
    state.avatarUrl = avatarUrl;
    state.qrCodeUrl = qrCodeUrl;
    state.newAvatarBytes = null;
    state.newAvatarName = null;
    state.isAvatarCleared = false;
    state.newQrCodeBytes = null;
    state.changed();
  }

  static Future<void> _saveOffline(ProfileEditorState state) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String avatarUrl = state.avatarUrl;
    final Uint8List? bytes = state.newAvatarBytes;
    if (state.isAvatarCleared) avatarUrl = '';
    if (bytes != null) avatarUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    await prefs.setString('profile_name', state.nameController.text.trim());
    await prefs.setString('profile_phone', state.phoneController.text.trim());
    await prefs.setString('profile_line_id', state.lineIdController.text.trim());
    await prefs.setString('profile_company', state.companyController.text.trim());
    await prefs.setString('profile_job_title', state.jobTitleController.text.trim());
    await prefs.setString('profile_license_no', state.licenseNoController.text.trim());
    await prefs.setString('profile_website', state.websiteController.text.trim());
    await prefs.setString('profile_address', state.addressController.text.trim());
    await prefs.setString('profile_bio', state.bioController.text.trim());
    await prefs.setString('profile_avatar_url', avatarUrl);
    await prefs.setString('profile_theme', CardTemplateRegistry.format(state.templateKey, state.colorwayIndex));
    await prefs.setString('profile_honor_title', state.honorTitle);
    await prefs.setString('profile_role', state.role.value);
    await prefs.setBool('profile_is_google_connected', state.isGoogleConnected);
    await prefs.setStringList('profile_badges', state.selectedBadges.toList());
    _markSaved(state, avatarUrl, state.qrCodeUrl);
  }

  /// 開發者、管理者測試用：切換自己的帳號狀態（開通／待審核）
  static Future<String> toggleAccountStatus(ProfileEditorState state) async {
    String newStatus = 'active';
    if (state.accountStatus == 'active') newStatus = 'pending';
    final User? user = _supabase.auth.currentUser;
    if (user == null) throw Exception('使用者未登入');
    await _supabase.from('profiles').update({'status': newStatus}).eq('id', user.id);
    state.accountStatus = newStatus;
    state.changed();
    return newStatus;
  }
}
