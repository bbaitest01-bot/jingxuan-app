import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 信箱欄位上方的「常用信箱網域 ▾」選單：選了就把 @gmail.com 等網域接到信箱後面
class EmailDomainPicker extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const EmailDomainPicker({super.key, required this.onSelected});

  // 選單內容：顯示名稱 → 網域
  static const List<MapEntry<String, String>> _domains = [
    MapEntry('Google', '@gmail.com'),
    MapEntry('Yahoo 台灣', '@yahoo.com.tw'),
    MapEntry('Outlook', '@outlook.com'),
    MapEntry('Apple iCloud', '@icloud.com'),
  ];

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return PopupMenuButton<String>(
      onSelected: onSelected,
      tooltip: '快速套用常用電子信箱網域',
      offset: const Offset(0, 28),
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          '常用信箱網域 ▾',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.acc),
        ),
      ),
      itemBuilder: (BuildContext context) => _domains
          .map((MapEntry<String, String> domain) => PopupMenuItem<String>(
                value: domain.value,
                child: _DomainMenuRow(name: domain.key, domain: domain.value),
              ))
          .toList(),
    );
  }
}

/// 選單裡的一列：左邊名稱、右邊網域（等寬字）
class _DomainMenuRow extends StatelessWidget {
  final String name;
  final String domain;

  const _DomainMenuRow({required this.name, required this.domain});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      children: [
        Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.ink)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            domain,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w400, color: colors.ink3),
          ),
        ),
      ],
    );
  }
}
