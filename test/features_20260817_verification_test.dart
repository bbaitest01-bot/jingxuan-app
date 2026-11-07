import 'package:flutter_test/flutter_test.dart';
import 'package:insurance_helper/services/policy_crawler_service.dart';
import 'package:insurance_helper/services/tag_categorizer.dart';

void main() {
  group('1. TagCategorizer Custom Color Priority Test', () {
    test('Custom HEX color overrides default fallback and preset colors', () {
      // Register custom tag color
      TagCategorizer.registerCustomColor('新光主力客戶', '#E11D48');
      TagCategorizer.registerCustomColor('重要VIP', '#10B981');

      expect(TagCategorizer.customTagColors['新光主力客戶'], '#E11D48');
      expect(TagCategorizer.customTagColors['重要vip'], '#10B981');

      final styleDark = TagCategorizer.getStyle('新光主力客戶', true);
      final styleLight = TagCategorizer.getStyle('新光主力客戶', false);

      expect(styleDark.categoryName, '自訂標籤');
      expect(styleLight.categoryName, '自訂標籤');
    });
  });

  group('3. PolicyCrawlerService Static Company Directory Test', () {
    test('Contains exactly 20 life insurance companies and 26 PC/channel companies (Total 46)', () {
      expect(PolicyCrawlerService.lifeCompanies.length, 20);
      expect(PolicyCrawlerService.pcCompanies.length, 26);
      expect(PolicyCrawlerService.lifeCompanies.length + PolicyCrawlerService.pcCompanies.length, 46);

      // Verify specific sample companies exist
      expect(PolicyCrawlerService.lifeCompanies, contains('富邦人壽'));
      expect(PolicyCrawlerService.lifeCompanies, contains('國泰人壽'));
      expect(PolicyCrawlerService.lifeCompanies, contains('南山人壽'));

      expect(PolicyCrawlerService.pcCompanies, contains('富邦產物'));
      expect(PolicyCrawlerService.pcCompanies, contains('新光產物'));
      expect(PolicyCrawlerService.pcCompanies, contains('公勝保經專屬通路'));
    });
  });
}
