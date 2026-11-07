import 'package:flutter/material.dart';

import '../../services/relationship_kinds.dart';
import '../../services/relationship_manager_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/customer_policy_widgets.dart';

/// 「管理關係」視窗下半部的「＋ 新增關係」：這個人（搜尋現有或打新名字）、他是誰的什麼人、是不是他介紹的
class RelationshipAddForm extends StatefulWidget {
  final String viewerId;
  final String viewerName;
  // 可以選的客戶（不含這個人自己）
  final List<Map<String, dynamic>> customers;
  final bool isSaving;
  final ValueChanged<AddRelationshipRequest> onSubmit;

  const RelationshipAddForm({
    super.key,
    required this.viewerId,
    required this.viewerName,
    required this.customers,
    required this.isSaving,
    required this.onSubmit,
  });

  @override
  State<RelationshipAddForm> createState() => _RelationshipAddFormState();
}

class _RelationshipAddFormState extends State<RelationshipAddForm> {
  final TextEditingController _nameController = TextEditingController();
  // 選了現有客戶時記住是誰；名字被改掉就清掉
  Map<String, dynamic>? _pickedCustomer;
  RelationshipKind? _kind;
  bool _isReferredByViewer = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 名字有包含輸入字的客戶，最多 5 位
  List<Map<String, dynamic>> _suggestions() {
    final String keyword = _nameController.text.trim();
    if (keyword.isEmpty || _pickedCustomer != null) return const [];
    final List<Map<String, dynamic>> matched = [];
    for (final Map<String, dynamic> customer in widget.customers) {
      final String name = customer['name']?.toString() ?? '';
      if (name.contains(keyword)) matched.add(customer);
      if (matched.length >= 5) break;
    }
    return matched;
  }

  bool get _canSubmit {
    if (widget.isSaving) return false;
    if (_nameController.text.trim().isEmpty) return false;
    return _kind != null || _isReferredByViewer;
  }

  /// 打的名字剛好和現有客戶一模一樣（沒點建議清單）時，當作選了他，避免重複建同一個人
  Map<String, dynamic>? _exactMatch() {
    final String typedName = _nameController.text.trim();
    for (final Map<String, dynamic> customer in widget.customers) {
      if ((customer['name']?.toString() ?? '') == typedName) return customer;
    }
    return null;
  }

  void _submit() {
    final Map<String, dynamic>? picked = _pickedCustomer ?? _exactMatch();
    widget.onSubmit(AddRelationshipRequest(
      existingCustomerId: picked?['id']?.toString(),
      newCustomerName: _nameController.text.trim(),
      kind: _kind,
      isReferredByViewer: _isReferredByViewer,
    ));
    setState(() {
      _nameController.clear();
      _pickedCustomer = null;
      _kind = null;
      _isReferredByViewer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String typedName = _nameController.text.trim();
    final List<Map<String, dynamic>> suggestions = _suggestions();
    final List<Widget> kindChips = [];
    for (final RelationshipKind kind in RelationshipKinds.all) {
      kindChips.add(SelectableChoiceChip(
        label: kind.label,
        isSelected: _kind == kind,
        onSelected: () => setState(() => _kind = _kind == kind ? null : kind),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('＋ 新增關係', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink)),
        const SizedBox(height: 8),
        Text('這個人（搜尋現有客戶，或直接打新名字）', style: TextStyle(fontSize: 11, color: colors.ink3)),
        const SizedBox(height: 4),
        TextField(
          controller: _nameController,
          onChanged: (String value) => setState(() => _pickedCustomer = null),
          decoration: InputDecoration(
            isDense: true,
            hintText: '例：陳小寶',
            suffixIcon: _NewCustomerHint(isNew: typedName.isNotEmpty && _pickedCustomer == null),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
        ),
        for (final Map<String, dynamic> customer in suggestions)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(customer['name']?.toString() ?? '', style: TextStyle(fontSize: 13, color: colors.ink)),
            trailing: Text('現有客戶', style: TextStyle(fontSize: 11, color: colors.ink3)),
            onTap: () => setState(() {
              _pickedCustomer = customer;
              _nameController.text = customer['name']?.toString() ?? '';
            }),
          ),
        const SizedBox(height: 10),
        Text('他是${widget.viewerName}的', style: TextStyle(fontSize: 11, color: colors.ink3)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: kindChips),
        CheckboxListTile(
          value: _isReferredByViewer,
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('是${widget.viewerName}介紹給我的（轉介紹）', style: TextStyle(fontSize: 13, color: colors.ink)),
          onChanged: (bool? checked) => setState(() => _isReferredByViewer = checked ?? false),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.acc,
              foregroundColor: colors.onAcc,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
            child: const Text('新增'),
          ),
        ),
      ],
    );
  }
}

/// 輸入框右邊：打的是名單上沒有的名字時，提醒「會新增客戶」
class _NewCustomerHint extends StatelessWidget {
  final bool isNew;

  const _NewCustomerHint({required this.isNew});

  @override
  Widget build(BuildContext context) {
    if (!isNew) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 10, top: 12),
      child: Text('＋ 新客戶', style: TextStyle(fontSize: 12, color: context.appColors.acc)),
    );
  }
}
