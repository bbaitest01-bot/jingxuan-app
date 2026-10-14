import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/app_localizations.dart';
import '../../services/app_settings.dart';
import '../../services/customer_service.dart';
import '../../services/tag_manager_service.dart';
import '../../widgets/categorized_tag_accordion_selector.dart';
import '../../widgets/color_palette_picker.dart';
import '../../widgets/custom_toast.dart';
import 'customer_status_widgets.dart';
import '../../widgets/voice_recorder_widget.dart';
import '../tag_manager_screen.dart';
import 'flipping_customer_card.dart';

/// 新增／編輯客戶的表單視窗。[customer] 是 null 代表新增。
/// 按下儲存時把填好的資料交給 [onSubmit]（外框負責寫入資料庫），再關閉視窗。
void showCustomerFormDialog(
  BuildContext outerContext, {
  Map<String, dynamic>? customer,
  required void Function(CustomerFormData form) onSubmit,
}) {
  final isEdit = customer != null;
  final isDark = Theme.of(outerContext).brightness == Brightness.dark;
  final primaryColor = AppSettings.instance.primaryColor;
  final Color dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
  final Color textColor = isDark ? Colors.white : Colors.black87;
  final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

  final nameController = TextEditingController(text: isEdit ? customer['name'] : '');
  final nicknameController = TextEditingController(text: isEdit ? customer['nickname'] : '');
  final phoneController = TextEditingController(text: isEdit ? customer['phone'] : '');
  final emailController = TextEditingController(text: isEdit ? customer['email'] : '');
  final tagsController = TextEditingController(
      text: isEdit ? (customer['tags'] as List).join(', ') : '');
  final notesController = TextEditingController(text: isEdit ? customer['notes'] : '');
  // 性別：male／female／null（不填）
  String? selectedGender = isEdit ? customer['gender'] as String? : null;
  // 客戶狀態：positive／considering／negative／null（未設定）
  String? selectedStatus = isEdit ? customer['client_status'] as String? : null;

  InputDecoration buildInputDecoration(String labelText, IconData iconData, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: subTextColor, fontSize: 13),
      hintText: hintText,
      hintStyle: TextStyle(color: subTextColor, fontSize: 13),
      prefixIcon: Icon(iconData, color: primaryColor, size: 18),
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
    );
  }
  showDialog(
    context: outerContext,
    builder: (context) {
      XFile? selectedImageFile;
      Uint8List? selectedImageBytes;
      bool isImageCleared = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          void submitForm() {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              CustomToast.show(context, '客戶姓名為必填項目', ToastType.warning);
              return;
            }

            final tagsList = tagsController.text
                .split(RegExp(r'[,，]'))
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();

            onSubmit(CustomerFormData(
              name: name,
              nickname: nicknameController.text.trim(),
              phone: phoneController.text.trim(),
              email: emailController.text.trim(),
              tags: tagsList,
              notes: notesController.text.trim(),
              gender: selectedGender,
              clientStatus: selectedStatus,
              imageBytes: selectedImageBytes,
              imageName: selectedImageFile?.name,
              isImageCleared: isImageCleared,
            ));
            Navigator.pop(context);
          }

          return AlertDialog(
            backgroundColor: dialogBg,
            title: Text(
              isEdit ? context.l10n('customer_edit_title') : context.l10n('customer_add_title'),
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(40),
                        onTap: () async {
                          try {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setDialogState(() {
                                selectedImageFile = image;
                                selectedImageBytes = bytes;
                                isImageCleared = false;
                              });
                            }
                          } catch (e) {
                            CustomToast.show(context, '選擇照片失敗: $e', ToastType.error);
                          }
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: primaryColor.withValues(alpha: 0.12),
                              backgroundImage: selectedImageBytes != null
                                  ? MemoryImage(selectedImageBytes!)
                                  : (!isImageCleared && isEdit && customer['avatar_url'] != null && customer['avatar_url'].isNotEmpty)
                                      ? customerAvatarProvider(customer['avatar_url'])
                                      : null,
                              child: (selectedImageBytes == null && (isImageCleared || !isEdit || customer['avatar_url'] == null || customer['avatar_url'].isEmpty))
                                  ? Icon(Icons.person, size: 40, color: primaryColor)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: primaryColor,
                                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selectedImageBytes != null || (!isImageCleared && isEdit && customer['avatar_url'] != null && customer['avatar_url'].isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                          label: Text(context.l10n('customer_clear_photo'), style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                          onPressed: () {
                            setDialogState(() {
                              selectedImageFile = null;
                              selectedImageBytes = null;
                              isImageCleared = true;
                            });
                          },
                        ),
                      ),
                    ],
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: textColor),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => submitForm(),
                      decoration: buildInputDecoration(context.l10n('customer_name_label'), Icons.person_outline),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nicknameController,
                      style: TextStyle(color: textColor),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => submitForm(),
                      decoration: buildInputDecoration(context.l10n('customer_nickname_label'), Icons.person_pin_outlined),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      style: TextStyle(color: textColor),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => submitForm(),
                      decoration: buildInputDecoration(context.l10n('customer_phone_label'), Icons.phone_outlined),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      style: TextStyle(color: textColor),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => submitForm(),
                      decoration: buildInputDecoration(context.l10n('customer_email_label'), Icons.email_outlined),
                    ),
                    const SizedBox(height: 16),
                    CustomerGenderSelector(
                      gender: selectedGender,
                      onChanged: (String? value) => setDialogState(() => selectedGender = value),
                    ),
                    const SizedBox(height: 12),
                    CustomerStatusSelector(
                      status: selectedStatus,
                      onChanged: (String? value) => setDialogState(() => selectedStatus = value),
                    ),
                    const SizedBox(height: 16),
                    // Sleek Collapsible Accordion Tag Selector (1-Tap Expand by Category)
                    CategorizedTagAccordionSelector(
                      tagsController: tagsController,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      onOpenQuickAdd: () async => openQuickAddTagDialog(context, tagsController, toastContext: outerContext),
                      onOpenTagManager: () async => TagManagerScreen.showAsDialog(context),
                    ),
                    const SizedBox(height: 16),
                    // 語音備註輸入列
                    VoiceRecorderWidget(
                      primaryColor: primaryColor,
                      isDark: isDark,
                      onTranscribed: (text) {
                        if (text.trim().isEmpty) return;
                        final now = DateTime.now();
                        final dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                        final current = notesController.text.trim();
                        notesController.text = current.isEmpty
                            ? '--- 🎙️ $dateStr 語音速記 ---\n$text'
                            : '$current\n\n--- 🎙️ $dateStr 語音速記 ---\n$text';
                        CustomToast.show(context, '✅ 語音速記已成功追加至備註！', ToastType.success);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      style: TextStyle(color: textColor),
                      maxLines: 4,
                      decoration: buildInputDecoration(context.l10n('customer_notes_label'), Icons.note_alt_outlined),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n('cancel'), style: TextStyle(color: subTextColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: submitForm,
                child: Text(context.l10n('save')),
              ),
            ],
          );
        },
      );
    },
  );
}

/// 表單裡的「新增標籤與自訂顏色」小視窗；建立後自動把標籤加進 [tagsController]。
/// [toastContext] 是外框的 context，用來顯示結果提示。
Future<void> openQuickAddTagDialog(
  BuildContext dialogContext,
  TextEditingController tagsController, {
  required BuildContext toastContext,
}) async {
  final nameController = TextEditingController();
  final categories = await TagManagerService.getCategories();
  String selectedCatId = categories.isNotEmpty ? categories.first.id : 'cat_identity';
  String? selectedColorHex;

  if (!dialogContext.mounted) return;

  return showDialog(
    context: dialogContext,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.local_offer, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('➕ 新增標籤與自訂顏色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '標籤名稱 (例: 企業戶, 高意願)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCatId,
                    decoration: InputDecoration(
                      labelText: '歸屬大分類資料夾',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text('📁 ${c.name}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCatId = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  ColorPalettePicker(
                    initialColorHex: selectedColorHex,
                    onColorSelected: (hex) => selectedColorHex = hex,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final res = await TagManagerService.addTag(
                    categoryId: selectedCatId,
                    name: name,
                    colorHex: selectedColorHex,
                  );

                  Navigator.pop(ctx);

                  if (!toastContext.mounted) return;

                  if (res == null) {
                    CustomToast.show(toastContext, '標籤「$name」已存在，已自動幫您選擇此標籤！', ToastType.warning);
                  } else {
                    CustomToast.show(toastContext, '成功建立標籤「$name」並設定專屬色彩！', ToastType.success);
                  }

                  // Auto append tag
                  final current = tagsController.text.trim();
                  if (!current.contains(name)) {
                    tagsController.text = current.isEmpty ? name : '$current, $name';
                  }
                },
                child: const Text('確定建立並套用'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// 性別選擇：男／女／不填（4-3b）
class CustomerGenderSelector extends StatelessWidget {
  final String? gender;
  final ValueChanged<String?> onChanged;

  const CustomerGenderSelector({super.key, required this.gender, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final List<String?> options = [CustomerService.genderMale, CustomerService.genderFemale, null];

    return Row(
      children: [
        Icon(Icons.wc_outlined, color: primaryColor, size: 18),
        const SizedBox(width: 8),
        const Text('性別', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.map((String? option) {
            return ChoiceChip(
              label: Text(CustomerService.genderLabel(option)),
              selected: gender == option,
              onSelected: (_) => onChanged(option),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            );
          }).toList(),
          ),
        ),
      ],
    );
  }
}
