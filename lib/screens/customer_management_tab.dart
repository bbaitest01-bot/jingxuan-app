import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';
import '../router/app_routes.dart';
import '../services/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/customer_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/customer_detail_side_sheet.dart';
import '../widgets/customer_share_export_dialog.dart';
import 'customers/create_project_dialog.dart';
import 'customers/customer_batch_selection_bar.dart';
import 'customers/customer_confirm_dialogs.dart';
import 'customers/customer_form_dialog.dart';
import 'customers/customer_collection_view.dart';
import 'customers/customer_grid_view.dart';
import 'customers/customer_import_dialog.dart';
import 'customers/customer_relationships_dialog.dart';
import 'customers/customer_toolbar.dart';
import 'customers/customer_top_panels.dart';

/// 客戶管理頁的外框：保管客戶資料、搜尋與多選狀態，並處理新增、編輯、刪除等動作。
/// 畫面的各個區塊拆在 `customers/` 資料夾；讀寫資料庫在 `CustomerService`。
class CustomerManagementTab extends StatefulWidget {
  const CustomerManagementTab({super.key});

  @override
  State<CustomerManagementTab> createState() => _CustomerManagementTabState();
}

class _CustomerManagementTabState extends State<CustomerManagementTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  late String _viewMode;

  // 多選（批量管理）狀態
  bool _isSelectionMode = false;
  Set<String> _selectedCustomerIds = {};

  // 開發者「僅我建立的／全系統客戶」切換
  bool _isDevUser = false;
  bool _devFilterOnlyMine = true;
  String? _currentUserId;

  @override
  bool get wantKeepAlive => true;

  // 提示上的「前往垃圾桶」：前往垃圾桶網址
  void _goToTrashBin() {
    if (!mounted) return;
    context.go(AppRoutes.trash);
  }

  @override
  void initState() {
    super.initState();
    _viewMode = AppSettings.instance.defaultCustomerViewMode;
    _searchController.addListener(_filterCustomers);
    _checkDevRole();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 確認登入者是不是開發者；是的話顯示「僅我建立的／全系統客戶」切換
  Future<void> _checkDevRole() async {
    if (isOfflineMode) return;
    try {
      _currentUserId = CustomerService.instance.currentUserId;
      final bool isDev = await CustomerService.instance.isCurrentUserDev();
      if (isDev && mounted) {
        setState(() {
          _isDevUser = true;
        });
        _filterCustomers();
      }
    } catch (_) {}
  }

  // 讀取客戶（離線預覽模式沒有資料）
  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          CustomToast.show(context, '目前為離線預覽模式，無法讀取真實客戶資料。', ToastType.warning);
        }
      });
      setState(() {
        _allCustomers = [];
        _isLoading = false;
      });
      _filterCustomers();
      return;
    }

    try {
      final String? userId = CustomerService.instance.currentUserId;
      if (userId != null) _currentUserId = userId;

      final List<Map<String, dynamic>> customers = await CustomerService.instance.fetchActiveCustomers();
      setState(() {
        _allCustomers = customers;
      });
      _filterCustomers();
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '讀取資料庫失敗: $e', ToastType.error);
      }
      setState(() {
        _allCustomers = [];
      });
      _filterCustomers();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 依搜尋文字與開發者範圍，重新篩選畫面上的客戶
  void _filterCustomers() {
    final String query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredCustomers = CustomerService.instance.filterCustomers(
        allCustomers: _allCustomers,
        query: query,
        onlyMine: _isDevUser && _devFilterOnlyMine,
        currentUserId: _currentUserId,
      );
    });
  }

  // 表單送出：有大頭貼先上傳，再新增或修改客戶；[customerId] 是 null 代表新增
  Future<void> _saveCustomer(CustomerFormData form, {String? customerId, String existingAvatarUrl = ''}) async {
    final bool isEdit = customerId != null;
    final String action = isEdit ? '修改' : '新增';
    if (isOfflineMode) {
      if (mounted) {
        CustomToast.show(context, '目前為離線預覽模式，無法$action客戶資料。', ToastType.warning);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String finalAvatarUrl = existingAvatarUrl;
    final Uint8List? imageBytes = form.imageBytes;
    final String? imageName = form.imageName;
    if (form.isImageCleared) {
      finalAvatarUrl = '';
    } else if (imageBytes != null && imageName != null) {
      try {
        finalAvatarUrl = await CustomerService.instance.uploadAvatar(imageBytes, imageName);
      } catch (e) {
        if (mounted) {
          CustomToast.show(context, '頭像上傳失敗: $e', ToastType.error);
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    try {
      if (isEdit) {
        await CustomerService.instance.updateCustomer(customerId, form, finalAvatarUrl);
      } else {
        await CustomerService.instance.createCustomer(form, finalAvatarUrl);
      }

      await _fetchCustomers();
      if (mounted) {
        CustomToast.show(context, '成功$action客戶 ${form.name} 檔案', ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '$action失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 單一客戶移到垃圾桶
  Future<void> _deleteCustomer(String id) async {
    if (isOfflineMode) {
      if (mounted) {
        CustomToast.show(context, '目前為離線預覽模式，無法刪除客戶資料。', ToastType.warning);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await CustomerService.instance.moveCustomerToTrash(id);
      await _fetchCustomers();
      if (mounted) {
        CustomToast.show(
          context,
          context.l10n('trash_bin_soft_delete_success'),
          ToastType.success,
          actionLabel: context.l10n('trash_bin_goto'),
          onActionPressed: _goToTrashBin,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '刪除失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 多選客戶批量移到垃圾桶（離線預覽模式只改畫面上的資料）
  Future<void> _executeBatchDelete() async {
    final List<String> idsToDelete = _selectedCustomerIds.toList();
    final int count = idsToDelete.length;

    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      setState(() {
        _allCustomers = CustomerService.instance.markCustomersDeletedLocally(_allCustomers, idsToDelete);
        _isSelectionMode = false;
        _selectedCustomerIds.clear();
        _isLoading = false;
      });
      _filterCustomers();
      _showBatchDeletedToast('🟢 成功將 $count 筆客戶移至垃圾桶 (離線暫存)');
      return;
    }

    try {
      await CustomerService.instance.moveCustomersToTrash(idsToDelete);

      setState(() {
        _isSelectionMode = false;
        _selectedCustomerIds.clear();
      });

      await _fetchCustomers();
      _showBatchDeletedToast('🟢 成功將 $count 筆客戶移至垃圾桶');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomToast.show(context, '🔴 批量刪除失敗: $e', ToastType.error);
      }
    }
  }

  void _showBatchDeletedToast(String message) {
    if (!mounted) return;
    CustomToast.show(
      context,
      message,
      ToastType.success,
      actionLabel: context.l10n('trash_bin_goto'),
      onActionPressed: _goToTrashBin,
    );
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedCustomerIds.clear();
    });
  }

  // 開啟新增／編輯客戶表單；[customer] 是 null 代表新增
  void _openCustomerForm({Map<String, dynamic>? customer}) {
    showCustomerFormDialog(
      context,
      customer: customer,
      onSubmit: (CustomerFormData form) {
        if (customer == null) {
          _saveCustomer(form);
        } else {
          _saveCustomer(form, customerId: customer['id'], existingAvatarUrl: customer['avatar_url'] ?? '');
        }
      },
    );
  }

  // 為勾選的客戶（沒勾選就用目前篩選結果）建立拜訪專案
  void _openCreateProjectDialog() {
    final List<Map<String, dynamic>> targetCustomers = _selectedCustomerIds.isNotEmpty
        ? _allCustomers.where((c) => _selectedCustomerIds.contains(c['id'].toString())).toList()
        : _filteredCustomers;

    if (targetCustomers.isEmpty) {
      CustomToast.show(context, '目前未選取目標客戶，請先勾選或篩選客戶', ToastType.warning);
      return;
    }

    showCreateProjectDialog(
      context,
      targetCustomers: targetCustomers,
      filteredCount: _filteredCustomers.length,
      onCreated: _exitSelectionMode,
    );
  }

  // 批次匯入 CSV／Excel：匯入完成後重新讀取客戶
  void _openBatchImportDialog() {
    showCustomerImportDialog(
      context,
      existingCustomers: _allCustomers,
      onImported: _fetchCustomers,
    );
  }

  // 匯出與分享：[selectedOnly] 為 true 時只匯出勾選的客戶，否則匯出目前搜尋結果
  void _openExportDialog({required bool selectedOnly}) {
    List<Map<String, dynamic>> customers = _filteredCustomers;
    final String query = _searchController.text.trim();
    String scopeDescription = query.isEmpty ? '全部客戶檔案' : '搜尋「$query」篩選結果';
    if (selectedOnly) {
      customers = _filteredCustomers.where((c) => _selectedCustomerIds.contains(c['id'].toString())).toList();
      scopeDescription = '已勾選之 ${_selectedCustomerIds.length} 位客戶';
    }
    CustomerShareExportDialog.show(context, customers: customers, scopeDescription: scopeDescription);
  }

  // 讀寫合一全景側邊抽屜 (Side Sheet)；抽屜裡改了資料就同步回列表
  void _openCustomerDetails(Map<String, dynamic> customer) {
    CustomerDetailSideSheet.show(
      context,
      customer: customer,
      onCustomerUpdated: (updated) {
        final int index = _allCustomers.indexWhere((c) => c['id'] == updated['id']);
        if (index != -1) {
          setState(() {
            _allCustomers[index] = updated;
          });
          _filterCustomers();
        }
      },
    );
  }

  void _openRelationshipsDialog(Map<String, dynamic> customer) {
    showCustomerRelationshipsDialog(
      context,
      customer: customer,
      allCustomers: _allCustomers,
      onReferralSourceChanged: (String? referralSourceId) {
        setState(() {
          customer['referral_source_id'] = referralSourceId;
        });
      },
    );
  }

  // 勾選或取消一位客戶
  void _setCustomerSelected(String customerId, bool selected) {
    setState(() {
      if (selected) {
        _selectedCustomerIds.add(customerId);
      } else {
        _selectedCustomerIds.remove(customerId);
      }
    });
  }

  // 全選框：勾選＝選取目前篩選出的全部客戶；取消＝全部取消
  void _setAllSelected(bool? selectAll) {
    setState(() {
      if (selectAll == true) {
        _selectedCustomerIds = _filteredCustomers.map((c) => c['id'].toString()).toSet();
      } else {
        _selectedCustomerIds.clear();
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedCustomerIds.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 768;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Map<String, dynamic>> draftCustomers = _allCustomers.where((c) => c['status'] == 'draft').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerToolbar(
            searchController: _searchController,
            viewMode: _viewMode,
            isSelectionMode: _isSelectionMode,
            isDevUser: _isDevUser,
            devOnlyMine: _devFilterOnlyMine,
            onDevScopeChanged: (bool onlyMine) {
              setState(() => _devFilterOnlyMine = onlyMine);
              _filterCustomers();
            },
            onToggleViewMode: () {
              setState(() {
                _viewMode = _viewMode == 'list' ? 'card' : 'list';
              });
            },
            onShareExport: () => _openExportDialog(selectedOnly: false),
            onBatchImport: _openBatchImportDialog,
            onToggleSelectionMode: _toggleSelectionMode,
            onAddCustomer: () => _openCustomerForm(),
          ),
          const SizedBox(height: 16),
          // 🟡 待補齊名片 / 語音草稿收件匣
          CustomerDraftInbox(
            isDark: isDark,
            draftCustomers: draftCustomers,
            onOpenDraft: _openCustomerDetails,
          ),
          if (_isSelectionMode)
            CustomerBatchSelectionBar(
              selectedCount: _selectedCustomerIds.length,
              totalCount: _filteredCustomers.length,
              onSelectAllChanged: _setAllSelected,
              onExport: () => _openExportDialog(selectedOnly: true),
              onCreateProject: _openCreateProjectDialog,
              onBatchDelete: () {
                if (_selectedCustomerIds.isEmpty) return;
                showBatchDeleteConfirm(
                  context,
                  count: _selectedCustomerIds.length,
                  onConfirm: _executeBatchDelete,
                );
              },
              onExitSelection: _exitSelectionMode,
            ),
          Expanded(
            child: CustomerCollectionView(
              customers: _filteredCustomers,
              isLoading: _isLoading,
              isListMode: _viewMode == 'list',
              isWideScreen: isWideScreen,
              screenWidth: screenWidth,
              isSelectionMode: _isSelectionMode,
              selectedCustomerIds: _selectedCustomerIds,
              actions: CustomerCardActions(
                onEdit: (customer) => _openCustomerForm(customer: customer),
                onDelete: (customer) => showDeleteCustomerConfirm(
                  context,
                  name: customer['name'] ?? '',
                  onConfirm: () => _deleteCustomer(customer['id']),
                ),
                onZoom: _openCustomerDetails,
                onManageRelationships: _openRelationshipsDialog,
                onSelectionChanged: _setCustomerSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
