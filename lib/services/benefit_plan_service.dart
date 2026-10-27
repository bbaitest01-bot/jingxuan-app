import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 實支實付的一個計畫（資料表 insurance_product_benefit_plans；D14，全景地圖 4-K）
///
/// 金額都是「理賠上限」（最多賠多少），單位新臺幣元；條款沒有的項目是 null。
class InsuranceBenefitPlan {
  static const String typeItemized = 'itemized';
  static const String typeDeductible = 'deductible';
  static const String typeTotal = 'total';

  final String productId;
  final String planCode;
  final int planOrder;
  final String benefitType;
  final int? roomDailyLimit;
  final int? hospitalExpenseLimit;
  final bool hospitalExpenseIncludesSurgery;
  final int? surgeryLimit;
  final int? outpatientSurgeryLimit;
  final int? perAdmissionTotalLimit;
  final int? annualTotalLimit;
  final int? lifetimeTotalLimit;
  final int? roomDeductible;
  final int? hospitalExpenseDeductible;
  final int? outpatientSurgeryDeductible;
  final int? dailyHospitalBenefit;
  final String? note;

  const InsuranceBenefitPlan({
    required this.productId,
    required this.planCode,
    required this.planOrder,
    required this.benefitType,
    this.roomDailyLimit,
    this.hospitalExpenseLimit,
    this.hospitalExpenseIncludesSurgery = false,
    this.surgeryLimit,
    this.outpatientSurgeryLimit,
    this.perAdmissionTotalLimit,
    this.annualTotalLimit,
    this.lifetimeTotalLimit,
    this.roomDeductible,
    this.hospitalExpenseDeductible,
    this.outpatientSurgeryDeductible,
    this.dailyHospitalBenefit,
    this.note,
  });

  factory InsuranceBenefitPlan.fromJson(Map<String, dynamic> json) {
    return InsuranceBenefitPlan(
      productId: json['product_id']?.toString() ?? '',
      planCode: json['plan_code']?.toString() ?? '',
      planOrder: (json['plan_order'] as num?)?.toInt() ?? 1,
      benefitType: json['benefit_type']?.toString() ?? typeItemized,
      roomDailyLimit: (json['room_daily_limit'] as num?)?.toInt(),
      hospitalExpenseLimit: (json['hospital_expense_limit'] as num?)?.toInt(),
      hospitalExpenseIncludesSurgery: json['hospital_expense_includes_surgery'] == true,
      surgeryLimit: (json['surgery_limit'] as num?)?.toInt(),
      outpatientSurgeryLimit: (json['outpatient_surgery_limit'] as num?)?.toInt(),
      perAdmissionTotalLimit: (json['per_admission_total_limit'] as num?)?.toInt(),
      annualTotalLimit: (json['annual_total_limit'] as num?)?.toInt(),
      lifetimeTotalLimit: (json['lifetime_total_limit'] as num?)?.toInt(),
      roomDeductible: (json['room_deductible'] as num?)?.toInt(),
      hospitalExpenseDeductible: (json['hospital_expense_deductible'] as num?)?.toInt(),
      outpatientSurgeryDeductible: (json['outpatient_surgery_deductible'] as num?)?.toInt(),
      dailyHospitalBenefit: (json['daily_hospital_benefit'] as num?)?.toInt(),
      note: json['note'] as String?,
    );
  }

  bool get isTotalType => benefitType == typeTotal;

  String get typeLabel {
    if (benefitType == typeDeductible) {
      return '自負額型';
    }
    if (benefitType == typeTotal) {
      return '總額型';
    }
    return '分項限額型';
  }

  /// 計畫選單的文字：計畫名稱＋重點限額，例：「計劃2（病房 2,000｜住院醫療 20 萬）」
  /// （2026-10-27 沛沛：光看「M10」不知道計畫差在哪）
  String get optionLabel {
    if (isTotalType) {
      return '$planCode（總額型）';
    }
    final List<String> highlights = [];
    final int? room = roomDailyLimit;
    if (room != null) {
      highlights.add('病房 ${formatAmount(room)}');
    }
    final int? hospitalExpense = hospitalExpenseLimit;
    if (hospitalExpense != null) {
      highlights.add('住院醫療 ${formatTenThousands(hospitalExpense)}');
    }
    if (highlights.isEmpty) {
      return planCode;
    }
    return '$planCode（${highlights.join('｜')}）';
  }

  /// 12350 → 「12,350」
  static String formatAmount(int amount) {
    return NumberFormat('#,###').format(amount);
  }

  /// 200000 → 「20 萬」、15000 → 「1.5 萬」；不到一萬照原樣加千分位
  static String formatTenThousands(int amount) {
    if (amount < 10000) {
      return formatAmount(amount);
    }
    final double tenThousands = amount / 10000;
    String text = tenThousands.toStringAsFixed(1);
    if (text.endsWith('.0')) {
      text = text.substring(0, text.length - 2);
    }
    return '$text 萬';
  }
}

/// 讀取實支實付限額（登入者唯讀；資料由 SQL 匯入，app 不會修改）
class BenefitPlanService {
  static final BenefitPlanService _instance = BenefitPlanService._internal();
  factory BenefitPlanService() => _instance;
  BenefitPlanService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 一次讀好幾款商品的計畫：{商品 id: [計畫（依順序）]}；沒有限額表的商品不會出現在結果裡
  Future<Map<String, List<InsuranceBenefitPlan>>> fetchPlansForProducts(List<String> productIds) async {
    final Map<String, List<InsuranceBenefitPlan>> plansByProduct = {};
    if (productIds.isEmpty) {
      return plansByProduct;
    }
    try {
      final List<dynamic> rows = await _supabase
          .from('insurance_product_benefit_plans')
          .select()
          .inFilter('product_id', productIds)
          .order('plan_order');
      for (final dynamic row in rows) {
        final InsuranceBenefitPlan plan = InsuranceBenefitPlan.fromJson(row as Map<String, dynamic>);
        plansByProduct.putIfAbsent(plan.productId, () => []).add(plan);
      }
    } catch (error) {
      // 讀不到時當作沒有限額表，比較頁照樣可以看基本資料
      if (kDebugMode) debugPrint('讀取實支實付限額失敗: $error');
    }
    return plansByProduct;
  }
}
