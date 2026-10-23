import 'package:flutter/material.dart';
import '../../services/customer_stage_service.dart';
import '../../theme/app_theme.dart';

/// 客戶管理上方的「篩選：保戶（12 位）✕」：從數據戰情摘要點進來時出現，按 ✕ 看全部客戶
class CustomerStageFilterBanner extends StatelessWidget {
  final String stage;
  final int count;
  final VoidCallback onClear;

  const CustomerStageFilterBanner({super.key, required this.stage, required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          avatar: Icon(Icons.filter_alt_rounded, size: 16, color: colors.acc),
          label: Text('篩選：${CustomerStage.label(stage)}（$count 位）'),
          backgroundColor: colors.accSoft,
          side: BorderSide.none,
          deleteIconColor: colors.acc,
          deleteButtonTooltipMessage: '取消篩選，看全部客戶',
          onDeleted: onClear,
        ),
      ),
    );
  }
}
