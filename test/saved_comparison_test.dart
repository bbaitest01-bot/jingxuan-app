import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/models/saved_comparison.dart';
import 'package:insurance_helper/services/saved_comparison_service.dart';
import 'package:insurance_helper/services/scenario/claim_scenario.dart';

List<SavedComparisonItem> buildItems(int count) {
  final List<SavedComparisonItem> items = [];
  for (int index = 0; index < count; index++) {
    items.add(SavedComparisonItem(productId: 'product-$index'));
  }
  return items;
}

void main() {
  group('情境數字存進去再讀出來要一樣', () {
    test('改過的數字都保留', () {
      const ClaimScenarioInput input = ClaimScenarioInput(
        type: ClaimScenarioType.accident,
        hospitalDays: 9,
        roomDifferencePerDay: 2500,
        medicalExpense: 80000,
        surgeryExpense: 0,
        isAccidentalDeath: true,
        isSevereCancer: false,
        isSevereCriticalIllness: false,
        careMonths: 24,
        disabilityLevel: 3,
      );
      final ClaimScenarioInput restored = SavedComparisonScenario.fromJson(SavedComparisonScenario.toJson(input));
      expect(restored.type, ClaimScenarioType.accident);
      expect(restored.hospitalDays, 9);
      expect(restored.roomDifferencePerDay, 2500);
      expect(restored.medicalExpense, 80000);
      expect(restored.surgeryExpense, 0);
      expect(restored.isAccidentalDeath, isTrue);
      expect(restored.isSevereCancer, isFalse);
      expect(restored.isSevereCriticalIllness, isFalse);
      expect(restored.careMonths, 24);
      expect(restored.disabilityLevel, 3);
    });

    test('舊資料缺欄位時用預設值', () {
      final ClaimScenarioInput restored = SavedComparisonScenario.fromJson({'type': ClaimScenarioType.death});
      expect(restored.type, ClaimScenarioType.death);
      expect(restored.hospitalDays, 5);
      expect(restored.isSevereCancer, isTrue);
    });
  });

  group('商品資料', () {
    test('計畫、張數、試算數字都保留，保額是元', () {
      const SavedComparisonItem item = SavedComparisonItem(
        productId: 'product-1',
        planCode: '計劃2',
        copies: 3,
        coverageAmount: 1000000,
        annualPremium: 12000,
      );
      final SavedComparisonItem restored = SavedComparisonItem.fromJson(item.toJson());
      expect(restored.productId, 'product-1');
      expect(restored.planCode, '計劃2');
      expect(restored.copies, 3);
      expect(restored.coverageAmount, 1000000);
      expect(restored.dailyAmount, isNull);
      expect(restored.annualPremium, 12000);
      expect(restored.toTrialInput('美元').currencyUnit, '美元');
    });

    test('資料庫的一筆比較可以完整讀出，商品順序不變', () {
      final SavedComparison comparison = SavedComparison.fromJson({
        'id': 'comparison-1',
        'customer_id': 'customer-1',
        'name': '醫療1',
        'scenario': {'type': ClaimScenarioType.cancer},
        'items': [
          {'product_id': 'product-b', 'copies': 2},
          {'product_id': 'product-a'},
        ],
        'updated_at': '2026-11-10T03:00:00Z',
      });
      expect(comparison.name, '醫療1');
      expect(comparison.scenario.type, ClaimScenarioType.cancer);
      expect(comparison.items.first.productId, 'product-b');
      expect(comparison.items.first.copies, 2);
      expect(comparison.items.last.copies, 1);
      expect(comparison.updatedAt.toUtc(), DateTime.utc(2026, 11, 10, 3));
    });
  });

  group('存檔前的檢查', () {
    test('名稱去掉頭尾空白', () {
      expect(SavedComparisonService.normalizeName('  醫療1 '), '醫療1');
    });

    test('空白名稱不能存', () {
      expect(() => SavedComparisonService.normalizeName('   '), throwsA(isA<SavedComparisonException>()));
    });

    test('名稱上限 30 字，罕見字算一個字', () {
      final String rareCharacter = String.fromCharCode(0x20BB7);
      expect(SavedComparisonService.normalizeName(rareCharacter * 30).runes.length, 30);
      expect(() => SavedComparisonService.normalizeName('字' * 31), throwsA(isA<SavedComparisonException>()));
    });

    test('商品要 2 到 8 款', () {
      expect(() => SavedComparisonService.validateItems(buildItems(1)), throwsA(isA<SavedComparisonException>()));
      expect(() => SavedComparisonService.validateItems(buildItems(9)), throwsA(isA<SavedComparisonException>()));
      SavedComparisonService.validateItems(buildItems(2));
      SavedComparisonService.validateItems(buildItems(8));
    });
  });

  test('算出每位客戶有幾筆比較', () {
    final Map<String, int> counts = SavedComparisonService.countRowsByCustomer([
      {'customer_id': 'customer-1'},
      {'customer_id': 'customer-2'},
      {'customer_id': 'customer-1'},
    ]);
    expect(counts, {'customer-1': 2, 'customer-2': 1});
  });
}
