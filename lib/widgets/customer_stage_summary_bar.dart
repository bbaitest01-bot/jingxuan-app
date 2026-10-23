import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/app_routes.dart';
import '../services/customer_stage_service.dart';
import '../theme/app_theme.dart';

/// 數據戰情最上方的「客戶概況」（D12）：保戶／跟進中／未開發三張卡片＋第四張「掃描保單」動作卡。
/// 點階段卡片跳到客戶管理並篩出那一群客戶（測試 D-02）。
/// 2026-10-23 沛沛看過模型圖第 3 版後確認：拿掉比例；「查看名單」改右上角箭頭；
/// 掃描保單放第四張（掃描完客戶就會變保戶，是把客戶往前推的工具），點了進入掃描流程。
class CustomerStageSummaryBar extends StatelessWidget {
  final CustomerStageSummary summary;
  final VoidCallback onScanPressed;

  const CustomerStageSummaryBar({super.key, required this.summary, required this.onScanPressed});

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryHeader(totalCustomers: summary.totalCustomers),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return _buildCardGrid(constraints.maxWidth);
            },
          ),
        ],
      ),
    );
  }

  /// 夠寬一排四張；不夠寬（< 720）改 2 × 2；手機（< 420）再縮小、藏說明
  Widget _buildCardGrid(double width) {
    final bool isCompact = width < 420;
    final List<Widget> cards = [];
    for (final String stage in CustomerStage.all) {
      cards.add(_StageCard(stage: stage, count: summary.countOf(stage), isCompact: isCompact));
    }
    cards.add(_ScanCard(isCompact: isCompact, onPressed: onScanPressed));

    final double gap = isCompact ? 8 : 10;
    if (width >= 720) {
      return _CardRow(cards: cards, gap: gap);
    }
    return Column(
      children: [
        _CardRow(cards: cards.sublist(0, 2), gap: gap),
        SizedBox(height: gap),
        _CardRow(cards: cards.sublist(2, 4), gap: gap),
      ],
    );
  }
}

/// 一排等寬、等高的卡片
class _CardRow extends StatelessWidget {
  final List<Widget> cards;
  final double gap;

  const _CardRow({required this.cards, required this.gap});

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];
    for (final Widget card in cards) {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: gap));
      }
      children.add(Expanded(child: card));
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// 標題列：左「客戶概況」（宋體，和「商品查詢」一致），右「名下客戶 N 位」
class _SummaryHeader extends StatelessWidget {
  final int totalCustomers;

  const _SummaryHeader({required this.totalCustomers});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('客戶概況', style: AppTextStyles.serif(fontSize: 16, color: colors.ink)),
        const Spacer(),
        Text('名下客戶 ', style: TextStyle(fontSize: 13, color: colors.ink2)),
        Text(
          '$totalCustomers',
          style: AppTextStyles.mono(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink),
        ),
        Text(' 位', style: TextStyle(fontSize: 13, color: colors.ink2)),
      ],
    );
  }
}

/// 卡片外框與點擊（階段卡、掃描卡共用）
class _CardFrame extends StatelessWidget {
  final bool isCompact;
  final Color borderColor;
  final double borderWidth;
  final Color backgroundColor;
  final VoidCallback onTap;
  final List<Widget> children;

  const _CardFrame({
    required this.isCompact,
    required this.borderColor,
    required this.borderWidth,
    required this.backgroundColor,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(isCompact ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ),
    );
  }
}

/// 卡片上方：圖示方塊＋名稱＋（階段卡才有的）右上角箭頭
class _CardTopRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final Color labelColor;
  final bool isCompact;
  final bool showChevron;

  const _CardTopRow({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.labelColor,
    required this.isCompact,
    required this.showChevron,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 4 : 6),
          decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(AppRadius.control)),
          child: Icon(icon, size: isCompact ? 16 : 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: isCompact ? 12 : 13, fontWeight: FontWeight.bold, color: labelColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showChevron) Icon(Icons.chevron_right_rounded, size: 18, color: colors.ink3),
      ],
    );
  }
}

/// 一個階段一張卡片：圖示、名稱、箭頭；人數（數字大、「位」小）；一行說明
class _StageCard extends StatelessWidget {
  final String stage;
  final int count;
  final bool isCompact;

  const _StageCard({required this.stage, required this.count, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final _StageStyle style = _StageStyle.of(stage, colors);

    final List<Widget> children = [
      _CardTopRow(
        icon: style.icon,
        iconColor: style.color,
        iconBackground: style.color.withValues(alpha: 0.12),
        label: CustomerStage.label(stage),
        labelColor: colors.ink2,
        isCompact: isCompact,
        showChevron: true,
      ),
      SizedBox(height: isCompact ? 8 : 12),
      Text.rich(TextSpan(children: [
        TextSpan(
          text: '$count',
          style: AppTextStyles.mono(fontSize: isCompact ? 20 : 26, fontWeight: FontWeight.bold, color: colors.ink),
        ),
        TextSpan(text: ' 位', style: TextStyle(fontSize: isCompact ? 12 : 13, color: colors.ink3)),
      ])),
    ];
    if (!isCompact) {
      children.add(const SizedBox(height: 6));
      children.add(Text(
        style.description,
        style: TextStyle(fontSize: 12, color: colors.ink3),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ));
    }

    return _CardFrame(
      isCompact: isCompact,
      borderColor: colors.line,
      borderWidth: 1,
      backgroundColor: colors.surface,
      onTap: () => context.go(AppRoutes.customersStagePath(stage)),
      children: children,
    );
  }
}

/// 第四張：掃描保單（動作卡，主題色外框與淡主題色底，和數字卡區分）
class _ScanCard extends StatelessWidget {
  final bool isCompact;
  final VoidCallback onPressed;

  const _ScanCard({required this.isCompact, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<Widget> children = [
      _CardTopRow(
        icon: Icons.document_scanner_outlined,
        iconColor: colors.onAcc,
        iconBackground: colors.acc,
        label: '掃描保單',
        labelColor: colors.acc,
        isCompact: isCompact,
        showChevron: false,
      ),
      SizedBox(height: isCompact ? 8 : 12),
      // 第 5 階段 E 完成後，從灰字「即將推出」改成主題色「開始掃描」（整張卡都可以點）
      Text('開始掃描 ›', style: TextStyle(fontSize: isCompact ? 13 : 15, fontWeight: FontWeight.w600, color: colors.acc)),
    ];
    if (!isCompact) {
      children.add(const SizedBox(height: 6));
      children.add(Text(
        '拍照辨識，加到客戶',
        style: TextStyle(fontSize: 12, color: colors.acc),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ));
    }

    return _CardFrame(
      isCompact: isCompact,
      borderColor: colors.acc,
      borderWidth: 1.5,
      backgroundColor: colors.accSoft,
      onTap: onPressed,
      children: children,
    );
  }
}

/// 三個階段的圖示、顏色與一行說明（保戶成功綠、跟進中提醒色、未開發灰）
class _StageStyle {
  final IconData icon;
  final Color color;
  final String description;

  const _StageStyle(this.icon, this.color, this.description);

  static _StageStyle of(String stage, AppColors colors) {
    if (stage == CustomerStage.client) {
      return _StageStyle(Icons.verified_user_outlined, colors.ok, '有效保單');
    }
    if (stage == CustomerStage.prospect) {
      return _StageStyle(Icons.forum_outlined, colors.warn, '有拜訪、未成交');
    }
    return _StageStyle(Icons.flag_outlined, colors.ink3, '尚未拜訪');
  }
}
