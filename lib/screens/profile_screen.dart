import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_role.dart';
import '../services/profile_editor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toast.dart';
import 'profile/business_card_stage.dart';
import 'profile/profile_editor_state.dart';
import 'profile/profile_form_parts.dart';
import 'profile/profile_honor_tab.dart';
import 'profile/profile_info_tabs.dart';
import 'profile/profile_security_tab.dart';

/// 個人帳號（網址 `/profile`）：我的名片
///
/// 2026-10-31 改版（組長嫌名片醜、沛沛要有酷的感覺）：原本 2,623 行拆成
/// - 正在編輯的資料 `profile/profile_editor_state.dart`、讀寫 `services/profile_editor_service.dart`
/// - 名片正反面 `profile/business_card_faces.dart`、傾斜反光翻面 `profile/business_card_stage.dart`
/// - 下載（正反面同一張圖）`profile/business_card_export.dart`
/// - 四個分頁 `profile/profile_info_tabs.dart`、`profile_honor_tab.dart`、`profile_security_tab.dart`
class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  final ValueChanged<UserRole>? onRoleChanged;
  const ProfileScreen({super.key, this.onProfileUpdated, this.onRoleChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ProfileEditorState _editor = ProfileEditorState();
  bool _isSaving = false;
  int _tabIndex = 0;

  static const List<String> _tabLabels = ['基本資料', '商務資歷', '榮譽與徽章', '帳號安全'];

  @override
  void initState() {
    super.initState();
    ProfileEditorService.applyCached(_editor);
    _load();
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await ProfileEditorService.load(_editor);
    } catch (error) {
      if (mounted) CustomToast.show(context, '讀取個人資料失敗：$error', ToastType.error);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      // 姓名沒填時跳到基本資料分頁，看得到紅字
      setState(() => _tabIndex = 0);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ProfileEditorService.save(_editor);
      if (!mounted) return;
      CustomToast.show(context, '已儲存', ToastType.success);
      widget.onProfileUpdated?.call();
    } catch (error) {
      if (mounted) CustomToast.show(context, '儲存失敗：$error', ToastType.error);
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _pickAvatar() async {
    final XFile? image = await _pickImage();
    if (image == null) return;
    _editor.newAvatarBytes = await image.readAsBytes();
    _editor.newAvatarName = image.name;
    _editor.isAvatarCleared = false;
    _editor.changed();
  }

  void _clearAvatar() {
    _editor.newAvatarBytes = null;
    _editor.isAvatarCleared = true;
    _editor.changed();
  }

  Future<void> _pickQrCode() async {
    final XFile? image = await _pickImage();
    if (image == null) return;
    _editor.newQrCodeBytes = await image.readAsBytes();
    _editor.changed();
  }

  Future<XFile?> _pickImage() async {
    try {
      return await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    } catch (error) {
      if (mounted) CustomToast.show(context, '選擇圖片失敗：$error', ToastType.error);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: Form(
        key: _formKey,
        child: ListenableBuilder(
          listenable: _editor,
          builder: (BuildContext context, Widget? child) {
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isWide = constraints.maxWidth >= 900;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 16, vertical: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileHeader(editor: _editor, isSaving: _isSaving, onSave: _save),
                          const SizedBox(height: 24),
                          if (isWide) _buildWideBody() else _buildNarrowBody(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // 電腦：左右各一半——名片和填寫一樣重要，邊改邊看（2026-10-31 沛沛）
  Widget _buildWideBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: BusinessCardStage(editor: _editor, onAvatarTap: _pickAvatar),
            ),
          ),
        ),
        const SizedBox(width: 40),
        Expanded(child: _buildEditor()),
      ],
    );
  }

  // 手機：名片在上、分頁在下
  Widget _buildNarrowBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BusinessCardStage(editor: _editor, onAvatarTap: _pickAvatar),
        const SizedBox(height: 28),
        _buildEditor(),
      ],
    );
  }

  Widget _buildEditor() {
    final AppColors colors = context.appColors;
    // 四個分頁都留著（切換時不會遺失填到一半的內容），只顯示目前這一個
    final List<Widget> tabs = [
      ProfileBasicTab(editor: _editor, onPickAvatar: _pickAvatar, onClearAvatar: _clearAvatar),
      ProfileBusinessTab(editor: _editor),
      ProfileHonorTab(editor: _editor, onPickQrCode: _pickQrCode),
      ProfileSecurityTab(editor: _editor, onRoleChanged: widget.onRoleChanged),
    ];
    final List<Widget> stacked = [];
    for (int index = 0; index < tabs.length; index++) {
      stacked.add(Offstage(offstage: index != _tabIndex, child: tabs[index]));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileTabBar(labels: _tabLabels, selectedIndex: _tabIndex, onSelected: (int index) => setState(() => _tabIndex = index)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: stacked),
        ),
      ],
    );
  }
}

/// 最上面：「我的名片」＋白話的帳號狀態＋儲存按鈕
class _ProfileHeader extends StatelessWidget {
  final ProfileEditorState editor;
  final bool isSaving;
  final VoidCallback onSave;

  const _ProfileHeader({required this.editor, required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<String> parts = [];
    final String company = editor.companyController.text.trim();
    if (company.isNotEmpty) parts.add(company);
    parts.add(editor.role.shortLabel);
    String statusText = '帳號正常';
    if (editor.accountStatus != 'active') statusText = '待主管審核';
    parts.add(statusText);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('我的名片', style: AppTextStyles.serif(fontSize: 22, color: colors.ink)),
              const SizedBox(height: 4),
              Text(
                '${parts.join('・')}　${editor.email}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: isSaving ? null : onSave,
          icon: isSaving
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onAcc))
              : const Icon(Icons.check_rounded, size: 16),
          label: Text(isSaving ? '儲存中…' : '儲存變更'),
        ),
      ],
    );
  }
}
