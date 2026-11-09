import 'package:flutter/material.dart';

import '../../models/saved_comparison.dart';
import '../../services/saved_comparison_service.dart';
import '../../services/scenario/claim_scenario.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';

/// 真正把比較存起來的動作；測試時可以換成假的，不用連資料庫
typedef SaveComparisonAction = Future<void> Function(
  String customerId,
  String name,
  ClaimScenarioInput scenario,
  List<SavedComparisonItem> items,
);

/// 比較頁的「把這次比較存到客戶」（D36，全景地圖 4-R）：選客戶、命名、存檔
class SavedComparisonSavePanel extends StatefulWidget {
  final ClaimScenarioInput Function() currentScenario;
  final List<SavedComparisonItem> Function() currentItems;
  final Future<List<Map<String, dynamic>>> Function()? loadCustomers;
  final SaveComparisonAction? saveComparison;

  const SavedComparisonSavePanel({
    super.key,
    required this.currentScenario,
    required this.currentItems,
    this.loadCustomers,
    this.saveComparison,
  });

  /// 選單上顯示的客戶：有電話就帶電話，同名的客戶才分得出來
  static String customerLabel(Map<String, dynamic> customer) {
    final String name = customer['name']?.toString() ?? '';
    final String phone = customer['phone']?.toString() ?? '';
    if (phone.isEmpty) {
      return name;
    }
    return '$name・$phone';
  }

  /// 依打的字找客戶（姓名、暱稱、電話）；沒打字時列出全部
  static List<Map<String, dynamic>> filterCustomers(List<Map<String, dynamic>> customers, String query) {
    final String keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return customers;
    }
    final List<Map<String, dynamic>> matchedCustomers = [];
    for (final Map<String, dynamic> customer in customers) {
      final String nickname = customer['nickname']?.toString() ?? '';
      final String searchText = '${customerLabel(customer)} $nickname'.toLowerCase();
      if (searchText.contains(keyword)) {
        matchedCustomers.add(customer);
      }
    }
    return matchedCustomers;
  }

  @override
  State<SavedComparisonSavePanel> createState() => _SavedComparisonSavePanelState();
}

class _SavedComparisonSavePanelState extends State<SavedComparisonSavePanel> {
  final TextEditingController _nameController = TextEditingController();
  List<Map<String, dynamic>> _customers = const [];
  Map<String, dynamic>? _selectedCustomer;
  bool _isSaving = false;
  bool _didCustomerLoadFail = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final Future<List<Map<String, dynamic>>> Function() loadCustomers =
        widget.loadCustomers ?? SavedComparisonService.instance.fetchSelectableCustomers;
    try {
      final List<Map<String, dynamic>> customers = await loadCustomers();
      if (!mounted) return;
      setState(() => _customers = customers);
    } catch (error) {
      // 寫在欄位下方，不跳提示：業務員可能只是來看比較，不一定要存
      if (!mounted) return;
      setState(() => _didCustomerLoadFail = true);
    }
  }

  Future<void> _saveToService(
    String customerId,
    String name,
    ClaimScenarioInput scenario,
    List<SavedComparisonItem> items,
  ) async {
    await SavedComparisonService.instance.create(
      customerId: customerId,
      name: name,
      scenario: scenario,
      items: items,
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final Map<String, dynamic>? customer = _selectedCustomer;
    if (customer == null) {
      CustomToast.show(context, '請從清單選一位客戶', ToastType.warning);
      return;
    }
    final SaveComparisonAction saveComparison = widget.saveComparison ?? _saveToService;
    setState(() => _isSaving = true);
    try {
      final String name = SavedComparisonService.normalizeName(_nameController.text);
      await saveComparison(customer['id'].toString(), name, widget.currentScenario(), widget.currentItems());
      if (!mounted) return;
      // 名稱清空，避免連按兩次變成同名；客戶留著，方便同一位客戶再存一組
      _nameController.clear();
      CustomToast.show(context, '已存到 ${customer['name']} 的比較清單', ToastType.success);
    } on SavedComparisonException catch (error) {
      if (!mounted) return;
      CustomToast.show(context, error.message, ToastType.warning);
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(context, '存檔失敗，請再試一次', ToastType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _fieldDecoration(String label, {String? hint, String? errorText}) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      hintText: hint,
      errorText: errorText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
    );
  }

  Widget _buildCustomerField() {
    String? errorText;
    if (_didCustomerLoadFail) {
      errorText = '讀不到客戶清單，請重新整理';
    }
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: SavedComparisonSavePanel.customerLabel,
      optionsBuilder: (TextEditingValue value) {
        return SavedComparisonSavePanel.filterCustomers(_customers, value.text);
      },
      onSelected: (Map<String, dynamic> customer) => setState(() => _selectedCustomer = customer),
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController controller,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 13),
          // 選好之後又改字，就不算選好了，避免存到不是畫面上寫的那位
          onChanged: (String value) => setState(() => _selectedCustomer = null),
          onSubmitted: (String value) => onFieldSubmitted(),
          decoration: _fieldDecoration('客戶', hint: '打姓名或電話搜尋', errorText: errorText),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String saveButtonText = '存到客戶';
    if (_isSaving) {
      saveButtonText = '存檔中...';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('把這次比較存到客戶', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink)),
          const SizedBox(height: 10),
          _buildCustomerField(),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 13),
            onSubmitted: (String value) => _save(),
            decoration: _fieldDecoration('比較名稱', hint: '例如 醫療1'),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: _isSaving ? null : _save, child: Text(saveButtonText)),
          const SizedBox(height: 6),
          Text('商品、計畫、試算數字會一起存', style: TextStyle(fontSize: 11, color: colors.ink3)),
        ],
      ),
    );
  }
}

/// 情境試算和存檔框的排法：寬螢幕並排、窄螢幕存檔框排在下面
class ScenarioWithSavePanelLayout extends StatelessWidget {
  /// 畫面比這個窄就改成上下排
  static const double sideBySideMinimumWidth = 800;
  static const double savePanelWidth = 300;

  final Widget scenarioPanel;
  final Widget savePanel;

  const ScenarioWithSavePanelLayout({super.key, required this.scenarioPanel, required this.savePanel});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= sideBySideMinimumWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: scenarioPanel),
              const SizedBox(width: 14),
              SizedBox(width: savePanelWidth, child: savePanel),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            scenarioPanel,
            const SizedBox(height: 14),
            savePanel,
          ],
        );
      },
    );
  }
}
