import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'benefit_plan_service.dart';
import 'customer_policy_service.dart';

/// 保障類別代號與畫面名稱（保單健檢；全景地圖 4-L）
class CoverageCategory {
  static const String life = 'life';
  static const String accident = 'accident';
  static const String reimbursement = 'reimbursement';
  static const String dailyHospital = 'daily_hospital';
  static const String surgery = 'surgery';
  static const String cancer = 'cancer';
  static const String criticalIllness = 'critical_illness';
  static const String longTermCare = 'long_term_care';
  static const String none = 'none';

  /// 保單可以選的類別（順序就是選單順序）
  static const Map<String, String> labels = {
    life: '壽險',
    accident: '意外',
    reimbursement: '實支實付',
    dailyHospital: '住院日額',
    surgery: '手術',
    cancer: '癌症',
    criticalIllness: '重大傷病',
    longTermCare: '長照',
    none: '不列入健檢',
  };

  static String label(String? category) => labels[category] ?? '未分類';
}

/// 健檢的一列（實支實付拆成病房、住院醫療兩列）
class CoverageCheckItem {
  final String key;
  final String label;
  final String unit;
  // 設定目標時的提示：要考慮什麼（2026-10-27 沛沛：業務員不知道目標怎麼定）
  final String hint;

  const CoverageCheckItem(this.key, this.label, this.unit, this.hint);
}

const List<CoverageCheckItem> coverageCheckItems = [
  CoverageCheckItem('life', '壽險（身故）', '元', '家人沒有他的收入後，要多少才過得下去（房貸、小孩教育、生活費）'),
  CoverageCheckItem('accident', '意外（身故失能）', '元', '跟壽險類似，再加上失能後的照護費用'),
  CoverageCheckItem('reimbursement_room', '實支：每日病房', '元／日', '客戶希望住哪種病房、一天要自付多少差額'),
  CoverageCheckItem('reimbursement_hospital', '實支：住院醫療費用', '元', '擔心用到哪些自費醫療（自費藥、醫材、手術）'),
  CoverageCheckItem('daily_hospital', '住院日額', '元／日', '住院時每天少賺的收入，或請看護的費用'),
  CoverageCheckItem('surgery', '手術', '元', '開刀時想要拿到多少補貼'),
  CoverageCheckItem('cancer', '癌症（一次金）', '元', '治療期間不能工作的收入，加上自費治療費用'),
  CoverageCheckItem('critical_illness', '重大傷病（一次金）', '元', '同癌症：治療與休養期間的收入損失與自費費用'),
  CoverageCheckItem('long_term_care', '長照（每月）', '元／月', '需要人照顧時，每月的看護或機構費用'),
];

/// 健檢結果：每列目前有多少；另外數出沒算進去的保單
class CoverageCheckResult {
  final Map<String, int> currentByItem;
  // 有效、會列入健檢，但還沒填保額／沒選計畫的保單
  final int missingAmountCount;
  // 判斷不出保障類別、要業務員自己選的保單
  final int unknownCategoryCount;

  const CoverageCheckResult({
    required this.currentByItem,
    required this.missingAmountCount,
    required this.unknownCategoryCount,
  });

  int currentOf(String key) => currentByItem[key] ?? 0;
}

/// 保單健檢：加總客戶有效保單的保障、讀寫業務員設定的目標
class CoverageCheckService {
  static final CoverageCheckService _instance = CoverageCheckService._internal();
  factory CoverageCheckService() => _instance;
  CoverageCheckService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// 這張保單算哪一類：業務員改過的優先，否則跟商品分類
  static String? categoryOf(CustomerEnrolledPolicy policy, Map<String, String?> productCategories) {
    return policy.coverageCategory ?? productCategories[policy.policyClauseId];
  }

  /// 加總（只算有效保單；實支實付用選的計畫，其他用保額；總額型實支不分項目不加）
  static CoverageCheckResult calculate({
    required List<CustomerEnrolledPolicy> policies,
    required Map<String, String?> productCategories,
    required Map<String, InsuranceBenefitPlan> plansById,
  }) {
    final Map<String, int> totals = {};
    int missingAmountCount = 0;
    int unknownCategoryCount = 0;

    for (final CustomerEnrolledPolicy policy in policies) {
      if (!policy.isActive) continue;
      final String? category = categoryOf(policy, productCategories);
      if (category == null) {
        unknownCategoryCount++;
        continue;
      }
      if (category == CoverageCategory.none) continue;

      if (category == CoverageCategory.reimbursement) {
        final InsuranceBenefitPlan? plan = plansById[policy.benefitPlanId];
        if (plan == null) {
          missingAmountCount++;
          continue;
        }
        totals['reimbursement_room'] = (totals['reimbursement_room'] ?? 0) + (plan.roomDailyLimit ?? 0);
        totals['reimbursement_hospital'] = (totals['reimbursement_hospital'] ?? 0) + (plan.hospitalExpenseLimit ?? 0);
        continue;
      }

      final int? amount = policy.coverageAmount;
      if (amount == null) {
        missingAmountCount++;
        continue;
      }
      totals[category] = (totals[category] ?? 0) + amount;
    }
    return CoverageCheckResult(
      currentByItem: totals,
      missingAmountCount: missingAmountCount,
      unknownCategoryCount: unknownCategoryCount,
    );
  }

  /// 保單上的文字轉成保額：「50 萬元」→ 500000、「日額 2,000 元」→ 2000；
  /// 外幣、「計畫三」這種沒有金額的回傳 null（請業務員自己填）
  static int? parseAmount(String? text) {
    final String cleaned = (text ?? '').replaceAll(RegExp(r'[\s,，]'), '');
    if (cleaned.isEmpty || RegExp(r'USD|美元|AUD|澳幣|CNY|人民幣').hasMatch(cleaned)) {
      return null;
    }
    final RegExpMatch? tenThousands = RegExp(r'(\d+(?:\.\d+)?)萬').firstMatch(cleaned);
    if (tenThousands != null) {
      return (double.parse(tenThousands.group(1)!) * 10000).round();
    }
    final RegExpMatch? plain = RegExp(r'(\d{3,})').firstMatch(cleaned);
    if (plain != null) {
      return int.parse(plain.group(1)!);
    }
    return null;
  }

  /// 「計畫三」「計劃 2」「M20」「B型」「20萬」對到限額表的計畫；對不到或不只一個像的回傳 null
  static InsuranceBenefitPlan? matchPlan(String? planText, List<InsuranceBenefitPlan> plans) {
    final String target = _normalizePlan(planText ?? '');
    if (target.isEmpty) return null;
    final List<InsuranceBenefitPlan> matches = [];
    for (final InsuranceBenefitPlan plan in plans) {
      if (_normalizePlan(plan.planCode) == target) {
        matches.add(plan);
      }
    }
    if (matches.length == 1) {
      return matches.first;
    }
    return null;
  }

  /// 去掉「計畫／計劃／計劃別／型」和空白，國字數字轉阿拉伯數字：「計畫三」「計劃別3」都變成「3」
  static String _normalizePlan(String text) {
    const Map<String, String> chineseDigits = {
      '一': '1', '二': '2', '三': '3', '四': '4', '五': '5', '六': '6', '七': '7', '八': '8', '九': '9', '十': '10',
    };
    String result = text.replaceAll(RegExp(r'\s'), '').toUpperCase();
    result = result.replaceAll(RegExp(r'計畫別|計劃別|計畫|計劃|投保'), '');
    chineseDigits.forEach((String chinese, String digit) {
      result = result.replaceAll(chinese, digit);
    });
    return result.replaceAll('型', '');
  }

  // ---------------------------------------------------------------------------
  // 資料庫
  // ---------------------------------------------------------------------------

  /// 商品的保障類別（view insurance_product_coverage）；{商品 id: 類別或 null}
  Future<Map<String, String?>> fetchProductCategories(List<String> productIds) async {
    final Map<String, String?> categories = {};
    final List<String> ids = productIds.where((String id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return categories;
    try {
      final List<dynamic> rows = await _supabase
          .from('insurance_product_coverage')
          .select('product_id, coverage_category')
          .inFilter('product_id', ids);
      for (final dynamic row in rows) {
        final Map<String, dynamic> data = row as Map<String, dynamic>;
        categories[data['product_id'].toString()] = data['coverage_category'] as String?;
      }
    } catch (error) {
      if (kDebugMode) debugPrint('讀取商品保障類別失敗: $error');
    }
    return categories;
  }

  /// 這位客戶的目標：{健檢列代號: 金額}
  Future<Map<String, int>> fetchTargets(String customerId) async {
    final Map<String, int> targets = {};
    try {
      final List<dynamic> rows = await _supabase
          .from('customer_coverage_targets')
          .select('category, target_amount')
          .eq('customer_id', customerId);
      for (final dynamic row in rows) {
        final Map<String, dynamic> data = row as Map<String, dynamic>;
        targets[data['category'].toString()] = (data['target_amount'] as num).toInt();
      }
    } catch (error) {
      if (kDebugMode) debugPrint('讀取保障目標失敗: $error');
    }
    return targets;
  }

  /// 存目標：有金額的寫入（重複就更新），清空的刪掉；失敗丟出例外讓畫面提示
  Future<void> saveTargets(String customerId, Map<String, int?> targets) async {
    final List<Map<String, dynamic>> upserts = [];
    final List<String> deletes = [];
    targets.forEach((String category, int? amount) {
      if (amount == null) {
        deletes.add(category);
      } else {
        upserts.add({
          'customer_id': customerId,
          'category': category,
          'target_amount': amount,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });
    if (upserts.isNotEmpty) {
      await _supabase.from('customer_coverage_targets').upsert(upserts, onConflict: 'customer_id,category');
    }
    if (deletes.isNotEmpty) {
      await _supabase
          .from('customer_coverage_targets')
          .delete()
          .eq('customer_id', customerId)
          .inFilter('category', deletes);
    }
  }

  /// 改一張保單的保障類別、保額、實支計畫；失敗丟出例外
  Future<void> updatePolicyCoverage({
    required String customerId,
    required String policyId,
    required String? coverageCategory,
    required int? coverageAmount,
    required String? benefitPlanId,
  }) async {
    await _supabase.from('customer_policies').update({
      'coverage_category': coverageCategory,
      'coverage_amount': coverageAmount,
      'benefit_plan_id': benefitPlanId,
    }).eq('id', policyId);
    CustomerPolicyService().clearCachedPolicies(customerId);
  }
}
