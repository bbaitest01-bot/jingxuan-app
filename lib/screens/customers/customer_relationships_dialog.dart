import 'package:flutter/material.dart';

import '../../services/customer_relationship_service.dart';
import '../../services/relationship_manager_service.dart';
import '../../services/relationship_rows.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_toast.dart';
import 'relationship_add_form.dart';

/// 管理一位客戶的人脈（2026-11-08 重做，模型圖沛沛確認）：
/// - 目前的關係：一位對方一列（一般關係＋轉介紹合在一起，例「朋友・他介紹的」），可刪除
/// - ＋ 新增關係：搜尋現有客戶或打新名字（只要名字就建客戶）、選配偶／子女…、勾「是他介紹給我的」
/// - 這個人是誰介紹的
/// 視窗關閉時回傳最後新增的那位客戶 id（人脈圖移到他身上）；沒有新增回傳 null。
/// 轉介紹來源改變時呼叫 [onReferralSourceChanged]，讓外框同步畫面上的客戶資料。
Future<String?> showCustomerRelationshipsDialog(
  BuildContext outerContext, {
  required Map<String, dynamic> customer,
  required List<Map<String, dynamic>> allCustomers,
  required void Function(String? referralSourceId) onReferralSourceChanged,
}) {
  return showDialog<String>(
    context: outerContext,
    builder: (BuildContext dialogContext) => _RelationshipManagerDialog(
      customer: customer,
      allCustomers: allCustomers,
      onReferralSourceChanged: onReferralSourceChanged,
    ),
  );
}

class _RelationshipManagerDialog extends StatefulWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> allCustomers;
  final void Function(String? referralSourceId) onReferralSourceChanged;

  const _RelationshipManagerDialog({
    required this.customer,
    required this.allCustomers,
    required this.onReferralSourceChanged,
  });

  @override
  State<_RelationshipManagerDialog> createState() => _RelationshipManagerDialogState();
}

class _RelationshipManagerDialogState extends State<_RelationshipManagerDialog> {
  // 視窗裡自己的一份客戶清單（新增的客戶、改了的介紹人先放這裡，關掉後外框會重讀）
  late final List<Map<String, dynamic>> _customers;
  List<Map<String, dynamic>> _relationships = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _lastAddedId;

  String get _viewerId => widget.customer['id'].toString();
  String get _viewerName => widget.customer['name']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _customers = [];
    for (final Map<String, dynamic> customer in widget.allCustomers) {
      _customers.add(Map<String, dynamic>.from(customer));
    }
    _loadRelationships();
  }

  Future<void> _loadRelationships() async {
    final List<Map<String, dynamic>> relationships = await CustomerRelationshipService.fetchAllRelationships();
    if (!mounted) return;
    setState(() {
      _relationships = relationships;
      _isLoading = false;
    });
  }

  Map<String, dynamic>? _customerById(String id) {
    for (final Map<String, dynamic> customer in _customers) {
      if (customer['id'].toString() == id) return customer;
    }
    return null;
  }

  Future<void> _add(AddRelationshipRequest request) async {
    setState(() => _isSaving = true);
    try {
      final String otherId = await RelationshipManagerService.addRelation(_viewerId, request);
      // 新客戶放進清單；轉介紹寫到對方的資料上
      Map<String, dynamic>? other = _customerById(otherId);
      if (other == null) {
        other = {'id': otherId, 'name': request.newCustomerName};
        _customers.add(other);
      }
      if (request.isReferredByViewer) other['referral_source_id'] = _viewerId;
      _lastAddedId = otherId;
      await _loadRelationships();
      if (!mounted) return;
      CustomToast.show(context, '已新增「${other['name']}」的關係', ToastType.success);
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(context, '新增失敗，請檢查網路後再試', ToastType.error);
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _remove(RelationshipRow row) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext confirmContext) => AlertDialog(
        title: const Text('刪除這個關係？'),
        content: Text('會拿掉$_viewerName和${row.otherName}之間的關係（${row.describe(_viewerName)}），客戶本身不會被刪除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(confirmContext, false), child: const Text('取消')),
          FilledButton(
            style: AppButtonStyles.danger(confirmContext),
            onPressed: () => Navigator.pop(confirmContext, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await RelationshipManagerService.removeRow(_viewerId, row);
    if (row.isIntroducedByViewer) _customerById(row.otherId)?['referral_source_id'] = null;
    if (row.introducedViewer) {
      _customerById(_viewerId)?['referral_source_id'] = null;
      widget.onReferralSourceChanged(null);
    }
    await _loadRelationships();
    if (mounted) CustomToast.show(context, '已刪除關係', ToastType.success);
  }

  Future<void> _setReferrer(String? referrerId) async {
    await CustomerRelationshipService.updateReferralSource(customerId: _viewerId, referralSourceId: referrerId);
    _customerById(_viewerId)?['referral_source_id'] = referrerId;
    widget.onReferralSourceChanged(referrerId);
    if (!mounted) return;
    setState(() {});
    CustomToast.show(context, '已更新介紹人', ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Map<String, dynamic>> otherCustomers = [];
    for (final Map<String, dynamic> customer in _customers) {
      if (customer['id'].toString() != _viewerId) otherCustomers.add(customer);
    }
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text('管理$_viewerName的關係', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
      content: SizedBox(
        width: 460,
        child: _isLoading
            ? const LinearProgressIndicator()
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCurrentRows(colors),
                    Divider(height: 24, color: colors.line),
                    RelationshipAddForm(
                      viewerId: _viewerId,
                      viewerName: _viewerName,
                      customers: otherCustomers,
                      isSaving: _isSaving,
                      onSubmit: _add,
                    ),
                    Divider(height: 24, color: colors.line),
                    _buildReferrerPicker(colors, otherCustomers),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, _lastAddedId), child: const Text('關閉')),
      ],
    );
  }

  Widget _buildCurrentRows(AppColors colors) {
    final List<RelationshipRow> rows = RelationshipRows.build(
      viewerId: _viewerId,
      customers: _customers,
      relationships: _relationships,
    );
    final List<Widget> children = [
      Text('目前的關係', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink)),
    ];
    if (rows.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('還沒有關係，可以在下面新增', style: TextStyle(fontSize: 12, color: colors.ink3)),
      ));
    }
    for (final RelationshipRow row in rows) {
      children.add(Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 0.5))),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${row.otherName}　', style: TextStyle(fontSize: 13, color: colors.ink)),
                TextSpan(text: row.describe(_viewerName), style: TextStyle(fontSize: 12, color: colors.ink2)),
              ])),
            ),
            TextButton(
              onPressed: () => _remove(row),
              style: TextButton.styleFrom(foregroundColor: colors.warn, visualDensity: VisualDensity.compact),
              child: const Text('刪除', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  /// 這個人是誰介紹的（客戶資料的轉介紹來源）
  Widget _buildReferrerPicker(AppColors colors, List<Map<String, dynamic>> otherCustomers) {
    final List<DropdownMenuItem<String?>> items = [
      const DropdownMenuItem<String?>(value: null, child: Text('沒有（自己開發的客戶）')),
    ];
    for (final Map<String, dynamic> customer in otherCustomers) {
      items.add(DropdownMenuItem<String?>(value: customer['id'].toString(), child: Text(customer['name']?.toString() ?? '')));
    }
    String? currentReferrerId = _customerById(_viewerId)?['referral_source_id']?.toString();
    if (currentReferrerId != null && _customerById(currentReferrerId) == null) currentReferrerId = null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$_viewerName是誰介紹的', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          // 介紹人在別處被清掉時（刪除那一列），選單要跟著變
          key: ValueKey<String?>(currentReferrerId),
          initialValue: currentReferrerId,
          isExpanded: true,
          items: items,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          onChanged: _setReferrer,
        ),
      ],
    );
  }
}
