import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 開發者專用：切換「僅我建立的」與「全系統客戶」。只有開發者帳號會看到。
class CustomerDevScopeSwitcher extends StatelessWidget {
  final bool isDark;
  final bool onlyMine;
  final ValueChanged<bool> onScopeChanged;

  const CustomerDevScopeSwitcher({
    super.key,
    required this.isDark,
    required this.onlyMine,
    required this.onScopeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeBg = context.appColors.acc;
    final Color inactiveText = context.appColors.ink3;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appColors.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.acc.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              if (!onlyMine) {
                onScopeChanged(true);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: onlyMine ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_rounded, size: 14, color: onlyMine ? context.appColors.onAcc : inactiveText),
                  const SizedBox(width: 4),
                  Text(
                    '👤 僅我建立的',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: onlyMine ? context.appColors.onAcc : inactiveText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () {
              if (onlyMine) {
                onScopeChanged(false);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: !onlyMine ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public_rounded, size: 14, color: !onlyMine ? context.appColors.onAcc : inactiveText),
                  const SizedBox(width: 4),
                  Text(
                    '🌐 全系統客戶 (Dev)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: !onlyMine ? context.appColors.onAcc : inactiveText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 待補齊名片／語音草稿收件匣：只列出 status 為 draft 的客戶；沒有草稿時不顯示。
class CustomerDraftInbox extends StatelessWidget {
  final bool isDark;
  final List<Map<String, dynamic>> draftCustomers;
  final ValueChanged<Map<String, dynamic>> onOpenDraft;

  const CustomerDraftInbox({
    super.key,
    required this.isDark,
    required this.draftCustomers,
    required this.onOpenDraft,
  });

  @override
  Widget build(BuildContext context) {
    if (draftCustomers.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.warn.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.warn.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.appColors.warn.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.contact_mail_rounded, color: context.appColors.warn, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('待補齊名片 / 語音草稿收件匣', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.appColors.warn)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: context.appColors.warnSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text('${draftCustomers.length} 位待確認', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.appColors.warn)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('語音助理在外速記產生之草稿檔案，點擊 1 秒補齊電話與標籤轉為正式客戶。', style: TextStyle(fontSize: 11, color: context.appColors.ink3)),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appColors.warn,
              foregroundColor: context.appColors.onAcc,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () {
              if (draftCustomers.isNotEmpty) {
                onOpenDraft(draftCustomers.first);
              }
            },
            icon: const Icon(Icons.edit_note_rounded, size: 16),
            label: const Text('立即補齊轉正', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
