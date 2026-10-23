import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/insurance_product_service.dart';
import '../theme/app_theme.dart';

/// 數據戰情搜尋區的小元件（從 data_dashboard_tab.dart 拆出，保持檔案 500 行以內）

/// 「找到 N 款」與資料來源、更新日期
class CatalogCountLine extends StatelessWidget {
  final int filteredCount;
  final ProductCatalogSummary catalogSummary;

  const CatalogCountLine({super.key, required this.filteredCount, required this.catalogSummary});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final NumberFormat numberFormat = NumberFormat('#,###');
    String updatedText = '尚未抓取';
    if (catalogSummary.lastUpdatedAt != null) {
      updatedText = DateFormat('yyyy/MM/dd').format(catalogSummary.lastUpdatedAt!);
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '找到 ${numberFormat.format(filteredCount)} 款（全部 ${numberFormat.format(catalogSummary.totalCount)} 款）',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.acc),
        ),
        Text(
          '資料來源：國泰、富邦、南山官網資訊公開｜更新 $updatedText',
          style: TextStyle(fontSize: 11, color: colors.ink3),
        ),
      ],
    );
  }
}

/// 險種篩選（全部＋各險種）與「含批註條款」開關
class InsuranceTypeFilter extends StatelessWidget {
  final String? activeInsuranceType;
  final bool includeEndorsements;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<bool> onEndorsementsChanged;

  const InsuranceTypeFilter({
    super.key,
    required this.activeInsuranceType,
    required this.includeEndorsements,
    required this.onTypeSelected,
    required this.onEndorsementsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> chips = [_buildTypeChip(colors, null, '全部')];
    InsuranceProductService.insuranceTypeLabels.forEach((String insuranceType, String label) {
      chips.add(_buildTypeChip(colors, insuranceType, label));
    });

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...chips,
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('含批註條款', style: TextStyle(fontSize: 11)),
          tooltip: '批註條款是附加在商品上的修改說明，不能單獨購買',
          selected: includeEndorsements,
          onSelected: onEndorsementsChanged,
        ),
      ],
    );
  }

  Widget _buildTypeChip(AppColors colors, String? insuranceType, String label) {
    final bool isSelected = activeInsuranceType == insuranceType;
    Color labelColor = colors.ink;
    if (isSelected) {
      labelColor = colors.onAcc;
    }
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: colors.acc,
      labelStyle: TextStyle(color: labelColor),
      onSelected: (_) => onTypeSelected(insuranceType),
    );
  }
}
