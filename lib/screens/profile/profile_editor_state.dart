import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/user_role.dart';
import 'card_templates/card_template.dart';
import 'card_templates/card_template_registry.dart';

/// 名片上要印的內容（名片正面、背面、下載圖片都用這一份）
class BusinessCardData {
  final String name;
  final String jobTitle;
  final String honorTitle;
  final String company;
  final String licenseNo;
  final String phone;
  final String lineId;
  final String email;
  final String website;
  final String address;
  final String bio;
  final List<String> badges;
  final ImageProvider? avatar;
  final ImageProvider? qrCode;
  final CardTemplate template;
  final CardColorway colorway;

  const BusinessCardData({
    required this.name,
    required this.jobTitle,
    required this.honorTitle,
    required this.company,
    required this.licenseNo,
    required this.phone,
    required this.lineId,
    required this.email,
    required this.website,
    required this.address,
    required this.bio,
    required this.badges,
    required this.avatar,
    required this.qrCode,
    required this.template,
    required this.colorway,
  });

  /// 同樣的內容換一個模板和配色（模板抽屜裡的小卡片用）
  BusinessCardData withTemplate(CardTemplate newTemplate, CardColorway newColorway) {
    return BusinessCardData(
      name: name,
      jobTitle: jobTitle,
      honorTitle: honorTitle,
      company: company,
      licenseNo: licenseNo,
      phone: phone,
      lineId: lineId,
      email: email,
      website: website,
      address: address,
      bio: bio,
      badges: badges,
      avatar: avatar,
      qrCode: qrCode,
      template: newTemplate,
      colorway: newColorway,
    );
  }
}

/// 個人帳號頁正在編輯的所有東西（2026-10-31 從 profile_screen.dart 拆出）
///
/// 輸入框、選的頭銜、徽章、配色、新選的照片都放在這裡；任何一項改變就通知畫面，
/// 左邊名片會跟著更新。讀取和儲存在 `services/profile_editor_service.dart`。
class ProfileEditorState extends ChangeNotifier {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController lineIdController = TextEditingController();
  final TextEditingController companyController = TextEditingController();
  final TextEditingController jobTitleController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController licenseNoController = TextEditingController();

  String email = '';
  UserRole role = UserRole.agent;
  String accountStatus = 'active';
  bool isGoogleConnected = false;

  // 大頭貼：資料庫裡的網址、剛選的新照片、或按了移除
  String avatarUrl = '';
  Uint8List? newAvatarBytes;
  String? newAvatarName;
  bool isAvatarCleared = false;

  // LINE QR Code：資料庫裡的網址或剛選的新圖片
  String qrCodeUrl = '';
  Uint8List? newQrCodeBytes;

  String honorTitle = '';
  Set<String> selectedBadges = {};
  // 名片模板與配色（2026-10-31 沛沛：選模板，不自己配色）
  String templateKey = 'classic';
  int colorwayIndex = 0;

  CardTemplate get template => CardTemplateRegistry.byKey(templateKey);
  CardColorway get colorway => template.colorways[colorwayIndex.clamp(0, template.colorways.length - 1)];

  /// 新帳號預設不帶任何頭銜與徽章，由業務員自己選（2026-10-13，避免名片誤寫自己有 MDRT 等資格）
  final List<String> availableHonorTitles = ['家庭保障規劃顧問', '資深理財顧問', '退休規劃顧問', '企業團保顧問'];
  final List<String> availableBadges = [
    'MDRT 會員',
    'CFP 國際理財規劃師',
    'RFA 退休理財顧問',
    '人身保險業務員',
    '投資型保險證照',
    '外幣保單證照',
    '產物保險業務員',
    '壽險管理人員',
  ];

  ProfileEditorState() {
    for (final TextEditingController controller in _controllers) {
      controller.addListener(notifyListeners);
    }
  }

  List<TextEditingController> get _controllers => [
        nameController,
        phoneController,
        lineIdController,
        companyController,
        jobTitleController,
        websiteController,
        addressController,
        bioController,
        licenseNoController,
      ];

  /// 頭銜、徽章、配色、照片改完後呼叫，讓名片重畫
  void changed() => notifyListeners();

  void selectHonorTitle(String title) {
    honorTitle = title;
    notifyListeners();
  }

  void toggleBadge(String badge) {
    if (!selectedBadges.remove(badge)) selectedBadges.add(badge);
    notifyListeners();
  }

  /// 自訂的頭銜、徽章加進可選清單並選起來
  void addCustomHonorTitle(String title) {
    if (!availableHonorTitles.contains(title)) availableHonorTitles.add(title);
    selectHonorTitle(title);
  }

  void addCustomBadge(String badge) {
    if (!availableBadges.contains(badge)) availableBadges.add(badge);
    selectedBadges.add(badge);
    notifyListeners();
  }

  /// 換模板時配色回到這個模板的第一組
  void selectTemplate(String key) {
    if (key == templateKey) return;
    templateKey = key;
    colorwayIndex = 0;
    notifyListeners();
  }

  void selectColorway(int index) {
    colorwayIndex = index;
    notifyListeners();
  }

  ImageProvider? get avatarProvider {
    final Uint8List? bytes = newAvatarBytes;
    if (bytes != null) return MemoryImage(bytes);
    if (isAvatarCleared || avatarUrl.isEmpty) return null;
    // 離線模式把照片存成 data: 網址
    if (avatarUrl.startsWith('data:')) {
      try {
        return MemoryImage(base64Decode(avatarUrl.split(',').last));
      } catch (error) {
        return null;
      }
    }
    return NetworkImage(avatarUrl);
  }

  ImageProvider? get qrCodeProvider {
    final Uint8List? bytes = newQrCodeBytes;
    if (bytes != null) return MemoryImage(bytes);
    if (qrCodeUrl.isEmpty) return null;
    return NetworkImage(qrCodeUrl);
  }

  /// 目前要印在名片上的內容；沒填的欄位是空字串，名片上就不顯示
  BusinessCardData get cardData {
    final List<String> badges = selectedBadges.toList();
    return BusinessCardData(
      name: nameController.text.trim(),
      jobTitle: jobTitleController.text.trim(),
      honorTitle: honorTitle,
      company: companyController.text.trim(),
      licenseNo: licenseNoController.text.trim(),
      phone: phoneController.text.trim(),
      lineId: lineIdController.text.trim(),
      email: email,
      website: websiteController.text.trim(),
      address: addressController.text.trim(),
      bio: bioController.text.trim(),
      badges: badges,
      avatar: avatarProvider,
      qrCode: qrCodeProvider,
      template: template,
      colorway: colorway,
    );
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
