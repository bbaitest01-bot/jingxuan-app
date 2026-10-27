import 'package:flutter/material.dart';

import '../../services/benefit_plan_service.dart';
import '../../services/coverage_check_service.dart';
import '../../services/customer_policy_service.dart';
import '../../theme/app_theme.dart';
import '../custom_toast.dart';
import 'coverage_target_dialog.dart';

/// 保單健檢卡片（全景地圖 4-L；模型圖 2026-10-27 沛沛確認）
///
/// 自己讀商品保障類別、實支計畫與目標；客戶保單（policies）換了就重新算。
/// 客戶完整頁與側邊抽屜共用。
class CustomerCoverageCheckSection extends StatefulWidget {
  final String customerId;
  final String customerName;
  final List<CustomerEnrolledPolicy> policies;

  const CustomerCoverageCheckSection({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.policies,
  });

  @override
  State<CustomerCoverageCheckSection> createState() => _CustomerCoverageCheckSectionState();
}

class _CustomerCoverageCheckSectionState extends State<CustomerCoverageCheckSection> {
  final CoverageCheckService _coverageService = CoverageCheckService();
  Map<String, String?> _productCategories = {};
  Map<String, InsuranceBenefitPlan> _plansById = {};
  Map<String, int> _targets = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didUpdateWidget(CustomerCoverageCheckSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policies != widget.policies || oldWidget.customerId != widget.customerId) {
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    final List<String> productIds = [];
    final List<String> planIds = [];
    for (final CustomerEnrolledPolicy policy in widget.policies) {
      productIds.add(policy.policyClauseId);
      final String? planId = policy.benefitPlanId;
      if (planId != null) {
        planIds.add(planId);
      }
    }
    final Map<String, String?> categories = await _coverageService.fetchProductCategories(productIds);
    final Map<String, InsuranceBenefitPlan> plansById = await BenefitPlanService().fetchPlansByIds(planIds);
    final Map<String, int> targets = await _coverageService.fetchTargets(widget.customerId);
    if (!mounted) return;
    setState(() {
      _productCategories = categories;
      _plansById = plansById;
      _targets = targets;
      _isLoading = false;
    });
  }

  Future<void> _editTargets() async {
    final Map<String, int?>? newTargets = await showCoverageTargetDialog(context, _targets);
    if (newTargets == null || !mounted) return;
    try {
      await _coverageService.saveTargets(widget.customerId, newTargets);
      if (!mounted) return;
      CustomToast.show(context, '已更新保障目標', ToastType.success);
      _loadAll();
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(context, '目標儲存失敗，請稍後再試', ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final CoverageCheckResult result = CoverageCheckService.calculate(
      policies: widget.policies,
      productCategories: _productCategories,
      plansById: _plansById,
    );

    int activeCount = 0;
    for (final CustomerEnrolledPolicy policy in widget.policies) {
      if (policy.isActive) activeCount++;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('保單健檢', style: AppTextStyles.serif(fontSize: 16, color: colors.ink))),
              OutlinedButton(
                onPressed: _isLoading ? null : _editTargets,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.acc,
                  side: BorderSide(color: colors.acc),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                ),
                child: const Text('設定目標', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Text('${widget.customerName}・$activeCount 張有效保單｜目標由業務員依客戶需求設定',
              style: TextStyle(fontSize: 11, color: colors.ink3)),
          const SizedBox(height: 8),
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator())
          else
            CoverageCheckTable(result: result, targets: _targets),
          const SizedBox(height: 8),
          _CoverageFootnote(result: result),
        ],
      ),
    );
  }
}

/// 健檢表格：保障｜目前有｜目標｜缺口
class CoverageCheckTable extends StatelessWidget {
  final CoverageCheckResult result;
  final Map<String, int> targets;

  const CoverageCheckTable({super.key, required this.result, required this.targets});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextStyle headStyle = TextStyle(fontSize: 11, color: colors.ink3);
    final List<TableRow> rows = [
      TableRow(children: [
        Text('保障', style: headStyle),
        Text('目前有', style: headStyle, textAlign: TextAlign.right),
        Text('目標', style: headStyle, textAlign: TextAlign.right),
        Text('缺口', style: headStyle, textAlign: TextAlign.right),
      ]),
    ];
    for (final CoverageCheckItem item in coverageCheckItems) {
      rows.add(_buildRow(colors, item));
    }
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.6), 1: FlexColumnWidth(1.1), 2: FlexColumnWidth(1.1), 3: FlexColumnWidth(1.3)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  TableRow _buildRow(AppColors colors, CoverageCheckItem item) {
    final int current = result.currentOf(item.key);
    final int? target = targets[item.key];
    final TextStyle numberStyle = AppTextStyles.mono(fontSize: 12, color: colors.ink);
    Widget targetCell = Text('未設定', style: TextStyle(fontSize: 11, color: colors.ink3), textAlign: TextAlign.right);
    Widget gapCell = Text('—', style: TextStyle(fontSize: 11, color: colors.ink3), textAlign: TextAlign.right);
    if (target != null) {
      targetCell = Text(InsuranceBenefitPlan.formatAmount(target), style: numberStyle, textAlign: TextAlign.right);
      if (current >= target) {
        gapCell = Text('✓ 足夠', style: TextStyle(fontSize: 12, color: colors.ok), textAlign: TextAlign.right);
      } else {
        gapCell = Text('還差 ${InsuranceBenefitPlan.formatAmount(target - current)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.warn), textAlign: TextAlign.right);
      }
    }
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text('${item.label}\n${item.unit}', style: TextStyle(fontSize: 12, height: 1.3, color: colors.ink)),
      ),
      Text(InsuranceBenefitPlan.formatAmount(current), style: numberStyle, textAlign: TextAlign.right),
      targetCell,
      gapCell,
    ]);
  }
}

class _CoverageFootnote extends StatelessWidget {
  final CoverageCheckResult result;

  const _CoverageFootnote({required this.result});

  @override
  Widget build(BuildContext context) {
    final List<String> notes = ['只加總有效保單'];
    if (result.missingAmountCount > 0) {
      notes.add('${result.missingAmountCount} 張保單還沒填保額或選計畫，未計入（在保單上按「保額」補上）');
    }
    if (result.unknownCategoryCount > 0) {
      notes.add('${result.unknownCategoryCount} 張保單看不出保障類別，請在保單上選擇');
    }
    notes.add('壽險目標參考：年收入 × 10（雙十原則）');
    return Text(notes.join('｜'), style: TextStyle(fontSize: 11, height: 1.5, color: context.appColors.ink3));
  }
}
