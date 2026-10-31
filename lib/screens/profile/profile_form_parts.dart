import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 個人帳號表單的共用小零件（2026-10-31 改版：灰框輸入框改成簡潔的底線樣式）

/// 一個輸入欄位：上面小字標籤、下面一條底線，點進去底線變主題色
class ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final int maxLines;
  final bool enabled;
  final String? initialValue;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const ProfileField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.maxLines = 1,
    this.enabled = true,
    this.initialValue,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color textColor = colors.ink;
    if (!enabled) textColor = colors.ink3;
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(fontSize: 15, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(fontSize: 13, color: colors.ink3),
        hintStyle: TextStyle(fontSize: 14, color: colors.ink3.withValues(alpha: 0.6)),
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.only(top: 6, bottom: 8),
        border: UnderlineInputBorder(borderSide: BorderSide(color: colors.line)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.line)),
        disabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.line.withValues(alpha: 0.5))),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.acc, width: 2)),
      ),
    );
  }
}

/// 兩個欄位並排；手機太窄時上下排
class ProfileFieldPair extends StatelessWidget {
  final Widget first;
  final Widget second;

  const ProfileFieldPair({super.key, required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 420) {
          return Column(children: [first, const SizedBox(height: 18), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: first), const SizedBox(width: 20), Expanded(child: second)],
        );
      },
    );
  }
}

/// 分頁裡的小標題＋一行說明
class ProfileSectionTitle extends StatelessWidget {
  final String title;
  final String? description;

  const ProfileSectionTitle({super.key, required this.title, this.description});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? text = description;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.ink)),
          if (text != null) ...[
            const SizedBox(height: 2),
            Text(text, style: TextStyle(fontSize: 13, color: colors.ink3)),
          ],
        ],
      ),
    );
  }
}

/// 四個分頁的切換列
class ProfileTabBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const ProfileTabBar({super.key, required this.labels, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> tabs = [];
    for (int index = 0; index < labels.length; index++) {
      final bool isSelected = index == selectedIndex;
      tabs.add(Expanded(
        child: InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Text(
              labels[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colors.acc : colors.ink3,
              ),
            ),
          ),
        ),
      ));
    }
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(AppRadius.control + 2)),
      child: Row(children: tabs),
    );
  }
}
