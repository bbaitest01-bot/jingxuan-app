import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'profile_editor_state.dart';
import 'profile_form_parts.dart';

/// 分頁「基本資料」：大頭貼、姓名、電話、LINE ID、Email（登入帳號，不能改）
class ProfileBasicTab extends StatelessWidget {
  final ProfileEditorState editor;
  final VoidCallback onPickAvatar;
  final VoidCallback onClearAvatar;

  const ProfileBasicTab({super.key, required this.editor, required this.onPickAvatar, required this.onClearAvatar});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionTitle(title: '基本資料', description: '改了左邊名片馬上跟著變，按「儲存變更」才會存起來'),
        _AvatarRow(editor: editor, onPick: onPickAvatar, onClear: onClearAvatar),
        const SizedBox(height: 20),
        ProfileField(
          label: '姓名',
          controller: editor.nameController,
          validator: (String? value) => (value ?? '').trim().isEmpty ? '請輸入姓名' : null,
        ),
        const SizedBox(height: 18),
        ProfileFieldPair(
          first: ProfileField(label: '電話', controller: editor.phoneController, keyboardType: TextInputType.phone),
          second: ProfileField(label: 'LINE ID（選填）', controller: editor.lineIdController, hintText: '例：lin_insurance'),
        ),
        const SizedBox(height: 18),
        // 信箱讀到後才知道，換 key 讓欄位重新顯示
        ProfileField(key: ValueKey<String>(editor.email), label: 'Email（登入帳號，不能改）', initialValue: editor.email, enabled: false),
      ],
    );
  }
}

class _AvatarRow extends StatelessWidget {
  final ProfileEditorState editor;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _AvatarRow({required this.editor, required this.onPick, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final ImageProvider? avatar = editor.avatarProvider;
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: colors.accSoft,
          backgroundImage: avatar,
          child: avatar == null ? Icon(Icons.person_outline_rounded, color: colors.acc) : null,
        ),
        const SizedBox(width: 14),
        OutlinedButton(onPressed: onPick, child: Text(avatar == null ? '上傳大頭貼' : '更換大頭貼')),
        if (avatar != null) ...[
          const SizedBox(width: 8),
          TextButton(onPressed: onClear, child: Text('移除', style: TextStyle(color: colors.ink3))),
        ],
      ],
    );
  }
}

/// 分頁「商務資歷」：公司、職稱、登錄字號、個人網站、辦公地址
class ProfileBusinessTab extends StatelessWidget {
  final ProfileEditorState editor;

  const ProfileBusinessTab({super.key, required this.editor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionTitle(title: '商務資歷', description: '公司與登錄字號印在名片最上面，網站與地址印在最下面'),
        ProfileFieldPair(
          first: ProfileField(label: '公司', controller: editor.companyController),
          second: ProfileField(label: '職稱', controller: editor.jobTitleController),
        ),
        const SizedBox(height: 18),
        ProfileField(label: '保險業務員登錄字號', controller: editor.licenseNoController, hintText: '例：110登字第389201號'),
        const SizedBox(height: 18),
        ProfileField(label: '個人網站（選填）', controller: editor.websiteController, hintText: 'https://'),
        const SizedBox(height: 18),
        ProfileField(label: '辦公地址（選填）', controller: editor.addressController, maxLines: 2),
      ],
    );
  }
}
