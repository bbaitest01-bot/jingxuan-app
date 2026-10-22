import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 數據戰情最上方的指標卡（名下客戶、本月拜訪、推動中專案）
class DashboardFunnelCard extends StatelessWidget {
  final String title;
  final String mainValue;
  final String subtitle;
  final IconData icon;
  final Color color;

  const DashboardFunnelCard({
    super.key,
    required this.title,
    required this.mainValue,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(mainValue, style: AppTextStyles.mono(fontSize: 18, fontWeight: FontWeight.bold, color: colors.ink)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.5, color: colors.ink3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
