import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../router/app_routes.dart';
import '../services/customer_policy_service.dart';
import '../services/customer_service.dart';
import '../services/insurance_product_service.dart';
import '../widgets/custom_toast.dart';
import 'customer_policy_widgets.dart';
import 'policy_group_card.dart';
import 'coverage_check/customer_coverage_check_section.dart';
import 'coverage_check/policy_coverage_dialog.dart';
import 'scan_policy/scan_policy_flow.dart';
import '../widgets/categorized_tag_accordion_selector.dart';
import '../widgets/voice_recorder_widget.dart';
import 'customer_share_export_dialog.dart';
import 'customer_detail_sheet_route.dart';
import 'customer_sheet_header.dart';
import '../screens/customers/customer_form_dialog.dart';
import '../screens/customers/customer_status_widgets.dart';
import '../theme/app_theme.dart';

class CustomerDetailSideSheet extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Function(Map<String, dynamic> updated) onCustomerUpdated;
  final VoidCallback onClose;
  // 原本卡片翻面才有的按鈕（2026-10-30 移到側邊欄上方）；沒傳就不顯示
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onManageRelationships;

  const CustomerDetailSideSheet({
    super.key,
    required this.customer,
    required this.onCustomerUpdated,
    required this.onClose,
    this.onEdit,
    this.onDelete,
    this.onManageRelationships,
  });

  static const double desktopSheetWidth = 520;

  /// 打開客戶側邊欄（電腦版右邊滑出、可帶卡片飛入；手機從下方打開）。實作在 customer_detail_sheet_route.dart
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> customer,
    required Function(Map<String, dynamic>) onCustomerUpdated,
    Rect? originRect,
    Widget? flyingCard,
    Rect? Function()? currentOriginRect,
    EdgeInsets contentPadding = EdgeInsets.zero,
    ValueChanged<bool>? onFitChanged,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onManageRelationships,
  }) {
    return showCustomerDetailSheet(
      context,
      customer: customer,
      onCustomerUpdated: onCustomerUpdated,
      originRect: originRect,
      flyingCard: flyingCard,
      currentOriginRect: currentOriginRect,
      contentPadding: contentPadding,
      onFitChanged: onFitChanged,
      onEdit: onEdit,
      onDelete: onDelete,
      onManageRelationships: onManageRelationships,
    );
  }

  @override
  State<CustomerDetailSideSheet> createState() => _CustomerDetailSideSheetState();
}

class _CustomerDetailSideSheetState extends State<CustomerDetailSideSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CustomerPolicyService _policyService = CustomerPolicyService();
  final InsuranceProductService _productService = InsuranceProductService();

  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;
  String? _gender; // 性別 male／female／null（4-3b）

  // Dynamic custom attributes controllers: Key -> TextEditingController
  final Map<String, TextEditingController> _customAttrControllers = {};
  final List<String> _customAttrKeys = [];

  List<CustomerEnrolledPolicy> _enrolledPolicies = [];
  bool _isLoadingPolicies = true;

  // Search catalog to enroll new policy
  final TextEditingController _searchCatalogController = TextEditingController();
  List<InsuranceProduct> _catalogSearchResults = [];
  bool _isSearchingCatalog = false;
  bool _showEnrollSearchBox = false;
  int _catalogCurrentPage = 1;
  int _catalogTotalPages = 1;
  int _catalogTotalCount = 0;
  // 資料庫裡的真實商品總數（按鈕與提示文字用，數量變了會自動跟著變）
  int _catalogProductCount = 0;
  // 這次「＋加入」要存成有效還是已失效（4-I，預設有效）
  String _enrollStatus = PolicyStatus.active;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _nameController = TextEditingController(text: widget.customer['name'] ?? '');
    _nicknameController = TextEditingController(text: widget.customer['nickname'] ?? '');
    _phoneController = TextEditingController(text: widget.customer['phone'] ?? '');
    _emailController = TextEditingController(text: widget.customer['email'] ?? '');
    _gender = widget.customer['gender'] as String?;
    _notesController = TextEditingController(text: widget.customer['notes'] ?? '');
    final tags = (widget.customer['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
    _tagsController = TextEditingController(text: tags.join(', '));

    final attrs = (widget.customer['custom_attributes'] is Map)
        ? widget.customer['custom_attributes'] as Map
        : {};
    attrs.forEach((k, v) {
      final keyStr = k.toString();
      _customAttrKeys.add(keyStr);
      _customAttrControllers[keyStr] = TextEditingController(text: v?.toString() ?? '');
    });

    _loadCustomerPolicies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    _searchCatalogController.dispose();
    for (final c in _customAttrControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _getCurrentCustomerData() {
    final Map<String, dynamic> customAttributes = {};
    for (final key in _customAttrKeys) {
      final c = _customAttrControllers[key];
      if (c != null && key.trim().isNotEmpty) {
        customAttributes[key.trim()] = c.text.trim();
      }
    }
    return {
      ...widget.customer,
      'name': _nameController.text.trim(),
      'nickname': _nicknameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'gender': _gender,
      'notes': _notesController.text.trim(),
      'tags': _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'custom_attributes': customAttributes,
    };
  }

  /// 商品總數文字：還沒讀到（0）時不顯示數字，例如「從 784 款真實商品中」
  String _catalogCountText(String prefix, String suffix) {
    if (_catalogProductCount <= 0) {
      return '';
    }
    return '$prefix${NumberFormat('#,###').format(_catalogProductCount)}$suffix';
  }

  String _enrollButtonLabel() {
    if (_catalogProductCount <= 0) {
      return '+ 搜尋商品加入';
    }
    return '+ 搜尋 ${NumberFormat('#,###').format(_catalogProductCount)} 款商品加入';
  }

  Future<void> _loadCustomerPolicies() async {
    final custId = widget.customer['id']?.toString() ?? '';
    if (custId.isEmpty) return;

    final list = await _policyService.getCustomerPolicies(custId);
    final ProductCatalogSummary catalogSummary = await _productService.fetchCatalogSummary();

    if (mounted) {
      setState(() {
        _enrolledPolicies = list;
        _catalogProductCount = catalogSummary.totalCount;
        _isLoadingPolicies = false;
      });
    }
  }

  Future<void> _searchCatalog(String query, {int page = 1}) async {
    setState(() {
      _isSearchingCatalog = true;
      _catalogCurrentPage = page;
    });

    final InsuranceProductSearchResult result = await _productService.searchProducts(
      query: query,
      page: page,
      pageSize: 8,
    );

    if (mounted) {
      setState(() {
        _catalogSearchResults = result.products;
        _catalogTotalCount = result.totalCount;
        _catalogTotalPages = result.totalPages;
        _isSearchingCatalog = false;
      });
    }
  }

  Future<void> _enrollPolicy(InsuranceProduct product) async {
    final String customerId = widget.customer['id']?.toString() ?? '';
    final bool success = await _policyService.enrollProductForCustomer(
      customerId: customerId,
      product: product,
      status: _enrollStatus,
    );
    if (!mounted) return;
    if (!success) {
      CustomToast.show(context, '加入失敗，請檢查網路後再試', ToastType.error);
      return;
    }

    CustomToast.show(context, '已加入${PolicyStatus.label(_enrollStatus)}保單：${product.productName}', ToastType.success);
    setState(() {
      _showEnrollSearchBox = false;
      _searchCatalogController.clear();
      _catalogSearchResults.clear();
    });
    _loadCustomerPolicies();
  }

  /// 打開／收合「搜尋商品加入」；第一次打開時順便搜尋
  void _toggleEnrollSearch() {
    setState(() {
      _showEnrollSearchBox = !_showEnrollSearchBox;
      if (_showEnrollSearchBox && _catalogSearchResults.isEmpty) {
        _searchCatalog(_searchCatalogController.text);
      }
    });
  }

  /// 掃描保單（第 5 階段 E）：這位客戶已確定，直接進入拍照／上傳；存入後重新讀保單
  Future<void> _scanPolicy() async {
    final bool saved = await startPolicyScan(
      context,
      customerId: widget.customer['id']?.toString(),
      customerName: widget.customer['name']?.toString(),
    );
    if (saved && mounted) {
      _loadCustomerPolicies();
    }
  }

  /// 先關掉抽屜，再跳到數據戰情並帶出這款商品（和「開啟完整頁面」同樣的做法）
  /// 目錄找不到的商品（掃描時照樣存的）沒有對應商品，不跳轉
  void _openProductInInsights(CustomerEnrolledPolicy policy) {
    if (!policy.isInCatalog) {
      CustomToast.show(context, '這個商品不在商品目錄中，沒有詳細資料可以看', ToastType.warning);
      return;
    }
    final GoRouter router = GoRouter.of(context);
    widget.onClose();
    router.go(AppRoutes.insightsProductPath(policy.policyClauseId));
  }

  Future<void> _saveBasicInfo() async {
    final updated = Map<String, dynamic>.from(widget.customer);
    updated['name'] = _nameController.text.trim();
    updated['nickname'] = _nicknameController.text.trim();
    updated['phone'] = _phoneController.text.trim();
    updated['email'] = _emailController.text.trim();
    updated['gender'] = _gender;
    updated['notes'] = _notesController.text.trim();
    updated['tags'] = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final Map<String, dynamic> customAttributes = {};
    for (final key in _customAttrKeys) {
      final c = _customAttrControllers[key];
      if (c != null && key.trim().isNotEmpty) {
        customAttributes[key.trim()] = c.text.trim();
      }
    }
    updated['custom_attributes'] = customAttributes;

    if (isOfflineMode) {
      CustomToast.show(context, '目前為離線預覽模式，無法儲存客戶資料。', ToastType.warning);
      return;
    }
    final String? customerId = widget.customer['id']?.toString();
    if (customerId == null) return;

    // 先存進資料庫，成功後才更新列表；失敗要提示，不能藏起來（問題 C18）
    try {
      await CustomerService.instance.updateCustomerBasicInfo(
        id: customerId,
        name: updated['name'],
        nickname: updated['nickname'],
        phone: updated['phone'],
        email: updated['email'],
        gender: _gender,
        notes: updated['notes'],
        tags: List<String>.from(updated['tags']),
        customAttributes: customAttributes,
      );
      widget.onCustomerUpdated(updated);
      if (mounted) {
        CustomToast.show(context, '✅ 客戶檔案已儲存', ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '儲存失敗：$e', ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = context.appColors.surface;
    final bgColor = context.appColors.bg;
    final borderColor = context.appColors.line;
    final Color textColor = context.appColors.ink;
    final subTextColor = context.appColors.ink3;

    final String name = _nameController.text.isEmpty ? '客戶檔案' : _nameController.text;
    final String nickname = _nicknameController.text;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(-4, 0)),
        ],
      ),
      child: Column(
        children: [
          CustomerSheetHeader(
            name: name,
            nickname: nickname,
            avatarUrl: widget.customer['avatar_url']?.toString() ?? '',
            onManageRelationships: widget.onManageRelationships,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
            onClose: widget.onClose,
            // 客戶細節整頁（C3）：先關掉側邊欄，再前往 /customers/:id
            onFullScreen: () {
              final GoRouter router = GoRouter.of(context);
              final String customerId = widget.customer['id'].toString();
              widget.onClose();
              router.go(AppRoutes.customerPath(customerId));
            },
            onShare: () {
              CustomerShareExportDialog.show(
                context,
                customers: [_getCurrentCustomerData()],
                scopeDescription: '客戶 ${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : '此客戶'} 個人檔案',
              );
            },
          ),

          // Tab Bar
          Container(
            decoration: BoxDecoration(color: bgColor, border: Border(bottom: BorderSide(color: borderColor))),
            child: TabBar(
              controller: _tabController,
              labelColor: context.appColors.acc,
              unselectedLabelColor: subTextColor,
              indicatorColor: context.appColors.acc,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.badge_rounded, size: 16), text: '基本資料'),
                Tab(icon: Icon(Icons.health_and_safety_rounded, size: 16), text: '保單健檢與缺口'),
                Tab(icon: Icon(Icons.history_edu_rounded, size: 16), text: '拜訪歷程'),
              ],
            ),
          ),

          // Tab Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Basic Info & Tags (In-place editing)
                _buildBasicInfoTab(isDark, cardBg, borderColor, textColor, subTextColor),

                // Tab 2: Enrolled Policies & 0-Cost Actuarial Summary
                _buildPoliciesAndGapTab(isDark, cardBg, borderColor, textColor, subTextColor),

                // Tab 3: Visit Notes & History
                _buildVisitHistoryTab(isDark, cardBg, borderColor, textColor, subTextColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '客戶姓名', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(labelText: '綽號 / 稱謂', isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: '聯絡電話', prefixIcon: Icon(Icons.phone_rounded, size: 18), isDense: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: '電子信箱', prefixIcon: Icon(Icons.email_rounded, size: 18), isDense: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          CustomerGenderSelector(gender: _gender, onChanged: (String? value) => setState(() => _gender = value)),
          const SizedBox(height: 8),
          // 客戶狀態由專案拜訪結果自動帶入，這裡只顯示來源（4-2b）
          CustomerStatusSourceText(customerId: widget.customer['id']?.toString() ?? '', status: widget.customer['client_status'] as String?),
          const SizedBox(height: 18),

          // 🌟 自訂擴充屬性專區 (Custom Attributes)
          _buildCustomAttributesSection(isDark, borderColor, textColor, subTextColor),
          const SizedBox(height: 18),

          Text('客戶標籤管理：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          CategorizedTagAccordionSelector(
            tagsController: _tagsController,
            isDark: isDark,
            primaryColor: context.appColors.acc,
          ),

          const SizedBox(height: 18),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '客戶隨手筆記 / 家庭背景備註',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          if (widget.customer['status'] == 'draft') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appColors.warn,
                  foregroundColor: context.appColors.onAcc,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                ),
                onPressed: () {
                  final updated = Map<String, dynamic>.from(widget.customer);
                  updated['name'] = _nameController.text.trim();
                  updated['nickname'] = _nicknameController.text.trim();
                  updated['phone'] = _phoneController.text.trim();
                  updated['email'] = _emailController.text.trim();
                  updated['notes'] = _notesController.text.trim();
                  updated['tags'] = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  updated['status'] = 'active'; // 轉正為正式客戶
                  _saveBasicInfo();
                  CustomToast.show(context, '🎉 已成功補齊資料並轉正為正式客戶！', ToastType.success);
                  widget.onClose();
                },
                icon: const Icon(Icons.verified_user_rounded, size: 20),
                label: const Text('✓ 確認補齊資料，正式入庫轉正', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: context.appColors.acc, foregroundColor: context.appColors.onAcc, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _saveBasicInfo,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('儲存基本資料', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAttributesSection(bool isDark, Color borderColor, Color textColor, Color subTextColor) {
    final boxBg = context.appColors.bg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.extension_outlined, size: 16, color: context.appColors.acc),
                  const SizedBox(width: 6),
                  Text(
                    '自訂擴充屬性 (${_customAttrKeys.length})',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _showAddCustomAttributeDialog,
                icon: Icon(Icons.add, size: 14, color: context.appColors.acc),
                label: Text('新增欄位', style: TextStyle(fontSize: 12, color: context.appColors.acc, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ],
          ),
          if (_customAttrKeys.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '尚無額外擴充屬性。匯入包含自訂欄位的 Excel 時將自動在此建立，亦可點擊右上方手動新增。',
              style: TextStyle(fontSize: 11, color: subTextColor),
            ),
          ] else ...[
            const SizedBox(height: 10),
            ..._customAttrKeys.map((key) {
              final controller = _customAttrControllers[key];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.appColors.acc.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        key,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.appColors.acc),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: TextStyle(fontSize: 12, color: textColor),
                        decoration: InputDecoration(
                          hintText: '請輸入 $key',
                          hintStyle: TextStyle(fontSize: 11, color: subTextColor),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 16, color: Theme.of(context).colorScheme.error),
                      tooltip: '刪除此欄位',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _customAttrKeys.remove(key);
                          _customAttrControllers[key]?.dispose();
                          _customAttrControllers.remove(key);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showAddCustomAttributeDialog() {
    final keyCtrl = TextEditingController();
    final valCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增自訂擴充屬性', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(labelText: '屬性/欄位名稱 (如：生日、配偶、年收入)', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valCtrl,
              decoration: const InputDecoration(labelText: '屬性值內容', isDense: true, border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final k = keyCtrl.text.trim();
              final v = valCtrl.text.trim();
              if (k.isNotEmpty) {
                setState(() {
                  if (!_customAttrKeys.contains(k)) {
                    _customAttrKeys.add(k);
                  }
                  _customAttrControllers[k] = TextEditingController(text: v);
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('新增'),
          ),
        ],
      ),
    );
  }

  Widget _buildPoliciesAndGapTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    if (_isLoadingPolicies) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 保單健檢（4-L）：取代舊的理賠總額卡與「重大缺口」紅色警告（舊警告用的是沒有出處的基準）
          CustomerCoverageCheckSection(
            customerId: widget.customer['id']?.toString() ?? '',
            customerName: widget.customer['name']?.toString() ?? '',
            policies: _enrolledPolicies,
          ),

          const SizedBox(height: 16),

          EnrolledPoliciesHeader(
            policyCount: _enrolledPolicies.length,
            isSearchOpen: _showEnrollSearchBox,
            enrollButtonLabel: _enrollButtonLabel(),
            onScanPressed: _scanPolicy,
            onToggleSearch: _toggleEnrollSearch,
          ),

          const SizedBox(height: 10),

          // Search catalog box & Paginated Results
          if (_showEnrollSearchBox) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.appColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('加入為：', style: TextStyle(fontSize: 12, color: subTextColor)),
                      PolicyStatusSelector(
                        status: _enrollStatus,
                        onChanged: (String status) => setState(() => _enrollStatus = status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchCatalogController,
                    onChanged: (val) => _searchCatalog(val, page: 1),
                    decoration: InputDecoration(
                      hintText: '輸入關鍵字多詞搜尋 (如: 國泰 醫療、富邦 癌症一次金)...',
                      hintStyle: TextStyle(fontSize: 12, color: subTextColor),
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchCatalogController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCatalogController.clear();
                                _searchCatalog('', page: 1);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_isSearchingCatalog)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
                    )
                  else
                    const SizedBox(height: 6),

                  if (_catalogSearchResults.isEmpty && !_isSearchingCatalog)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('查無符合「${_searchCatalogController.text}」的商品，請換個關鍵字。', style: TextStyle(fontSize: 11, color: subTextColor)),
                      ),
                    )
                  else ...[
                    // Compact Policy Items List with Opacity during page flip
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _isSearchingCatalog ? 0.4 : 1.0,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _catalogSearchResults.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final InsuranceProduct product = _catalogSearchResults[i];
                          return CatalogProductResultTile(product: product, onEnroll: () => _enrollPolicy(product));
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Dynamic Pagination Toolbar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.appColors.line,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.chevron_left_rounded, size: 18),
                            label: const Text('上一頁', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _catalogCurrentPage > 1
                                ? () => _searchCatalog(_searchCatalogController.text, page: _catalogCurrentPage - 1)
                                : null,
                          ),
                          Text(
                            '第 $_catalogCurrentPage 頁 / 共 $_catalogTotalPages 頁\n(符合共 $_catalogTotalCount 筆)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.chevron_right_rounded, size: 18),
                            label: const Text('下一頁', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _catalogCurrentPage < _catalogTotalPages
                                ? () => _searchCatalog(_searchCatalogController.text, page: _catalogCurrentPage + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          PolicyGroupList(
            policies: _enrolledPolicies,
            emptyText: '目前尚未加入任何已購保單，可以按「掃描保單」，或點擊上方按鈕${_catalogCountText('從 ', ' 款真實商品中')}搜尋加入。',
            onOpenProduct: _openProductInInsights,
            onEditCoverage: (CustomerEnrolledPolicy policy) async {
              if (await showPolicyCoverageDialog(context, policy)) _loadCustomerPolicies();
            },
            onSetStatus: (List<CustomerEnrolledPolicy> items, String status) async {
              if (await savePolicyStatus(context, widget.customer['id'].toString(), items, status)) _loadCustomerPolicies();
            },
            onDelete: (List<CustomerEnrolledPolicy> items) async {
              if (await deletePolicyItems(context, widget.customer['id'].toString(), items)) _loadCustomerPolicies();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVisitHistoryTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_none_rounded, color: context.appColors.acc, size: 18),
              const SizedBox(width: 6),
              Text('語音速記與拜訪紀錄：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          // 🎙️ 內嵌隨手語音錄音與轉錄
          VoiceRecorderWidget(
            primaryColor: context.appColors.acc,
            isDark: isDark,
            onTranscribed: (text) {
              if (text.trim().isNotEmpty) {
                final old = _notesController.text.trim();
                final now = DateTime.now();
                final dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                final updated = old.isEmpty ? '--- 🎙️ $dateStr 語音速記 ---\n$text' : '$old\n\n--- 🎙️ $dateStr 語音速記 ---\n$text';
                setState(() {
                  _notesController.text = updated;
                });
                _saveBasicInfo();
                CustomToast.show(context, '✅ 語音速記已轉錄並自動追加儲存！', ToastType.success);
              }
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              _notesController.text.isEmpty ? '尚無語音拜訪速記紀錄。可點擊上方麥克風隨手錄音自動轉錄儲存。' : _notesController.text,
              style: TextStyle(fontSize: 12, color: textColor, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
