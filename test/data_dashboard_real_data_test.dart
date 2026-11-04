import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/policy_crawler_service.dart';

void main() {
  group('PolicyClauseItem Model Tests', () {
    test('fromJson parses live database clause data correctly', () {
      final json = {
        'id': 'pc-1234-uuid',
        'product_name': '安心住院醫療終身保險',
        'company_name': '富邦人壽',
        'category': '實支實付醫療險',
        'waiting_days': '疾病等待期 30 日',
        'tags': ['概括式條款', '健保 2-2-7 手術給付'],
        'room_limit': '2,500 元/日',
        'surgery_limit': '180,000 元',
        'misc_limit': '150,000 元',
        'raw_pdf_url': 'https://example.com/policy.pdf',
        'benefits_json': {'room_daily': 2500, 'surgery_max': 180000},
        'crawled_at': '2026-08-31T12:00:00Z',
      };

      final item = PolicyClauseItem.fromJson(json);
      expect(item.id, 'pc-1234-uuid');
      expect(item.productName, '安心住院醫療終身保險');
      expect(item.companyName, '富邦人壽');
      expect(item.category, '實支實付醫療險');
      expect(item.roomLimit, '2,500 元/日');
      expect(item.surgeryLimit, '180,000 元');
      expect(item.miscLimit, '150,000 元');
      expect(item.rawPdfUrl, 'https://example.com/policy.pdf');
    });
  });

  group('Policy Category Filter Expansion Tests', () {
    test('expands UI short category labels to real database category strings', () {
      expect(PolicyCrawlerService.expandCategoryFilter('手術險'), contains('手術醫療終身險'));
      expect(PolicyCrawlerService.expandCategoryFilter('日額型醫療險'), contains('日額型住院醫療險'));
      expect(PolicyCrawlerService.expandCategoryFilter('癌症險'), containsAll(['癌症險', '癌症一次給付金險', '癌症住院療程險']));
      expect(PolicyCrawlerService.expandCategoryFilter('重大傷病險'), containsAll(['重大傷病險', '特定傷病險']));
      expect(PolicyCrawlerService.expandCategoryFilter('長照險 / 失能險'), containsAll(['長照險 / 失能險', '巴氏量表長照險', '失能扶助險']));
      expect(PolicyCrawlerService.expandCategoryFilter('定期壽險'), containsAll(['定期壽險', '房貸壽險', '微型照顧保單']));
      expect(PolicyCrawlerService.expandCategoryFilter('汽機車責任與超額險'), containsAll(['汽機車強制險與責任險', '超額責任與防禦險']));
    });
  });
}
