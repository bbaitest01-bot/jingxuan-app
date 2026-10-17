import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/app_settings.dart';
import '../../../services/app_localizations.dart';
import '../../../theme/app_theme.dart';
import 'schedule_page_state.dart';

/// 今日行程最上方的工具列：前後切換日期、回到今天、切換日／月／議程視圖、路線規劃與重新整理。
/// 寬度小於 820 時改成上下兩排（[_CompactHeader]），否則一排（[_WideHeader]）。
class ScheduleHeader extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const ScheduleHeader({super.key, required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 820;
        Widget content = _WideHeader(data: data, actions: actions);
        if (isCompact) {
          content = _CompactHeader(data: data, actions: actions);
        }
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 20,
            vertical: isCompact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          child: content,
        );
      },
    );
  }
}

/// 電腦版：左邊日期與前後切換，右邊路線規劃、視圖切換、重新整理
class _WideHeader extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const _WideHeader({required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _SelectedDateLabel(data: data, fontSize: 16),
            const SizedBox(width: 8),
            _DateStepButtons(data: data, actions: actions, isCompact: false),
            const SizedBox(width: 4),
            _BackToTodayButton(actions: actions, fontSize: 13),
          ],
        ),
        Row(
          children: [
            _RoutePlannerButton(data: data, actions: actions, isCompact: false),
            const SizedBox(width: 12),
            _ViewModeSwitcher(data: data, actions: actions, isCompact: false),
            const SizedBox(width: 12),
            if (data.isLoading) const _LoadingDot(size: 16),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.refresh, size: 20, color: context.appColors.ink2),
              onPressed: actions.reload,
              tooltip: '重新整理行程',
            ),
          ],
        ),
      ],
    );
  }
}

/// 手機與窄視窗：第一排日期與前後切換，第二排路線規劃與視圖切換
class _CompactHeader extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;

  const _CompactHeader({required this.data, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SelectedDateLabel(data: data, fontSize: 14),
            Row(
              children: [
                _DateStepButtons(data: data, actions: actions, isCompact: true),
                _BackToTodayButton(actions: actions, fontSize: 12),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _RoutePlannerButton(data: data, actions: actions, isCompact: true),
                const SizedBox(width: 8),
                _ViewModeSwitcher(data: data, actions: actions, isCompact: true),
              ],
            ),
            if (data.isLoading) const _LoadingDot(size: 14),
          ],
        ),
      ],
    );
  }
}

/// 日曆小圖示＋目前日期（月網格只顯示年月）；數字用等寬字
class _SelectedDateLabel extends StatelessWidget {
  final ScheduleViewData data;
  final double fontSize;

  const _SelectedDateLabel({required this.data, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String datePattern = 'yyyy/MM/dd (EEE)';
    if (data.viewMode == 'month_grid') {
      datePattern = 'yyyy/MM';
    }
    final String dateText = DateFormat(datePattern, AppSettings.instance.language).format(data.selectedDate);

    return Row(
      children: [
        Icon(Icons.today, color: colors.acc, size: fontSize + 4),
        const SizedBox(width: 6),
        Text(dateText, style: AppTextStyles.mono(fontSize: fontSize, color: colors.ink)),
      ],
    );
  }
}

/// 往前、往後一天（月網格時是前後一個月）
class _DateStepButtons extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;
  final bool isCompact;

  const _DateStepButtons({required this.data, required this.actions, required this.isCompact});

  // step 是 -1（往前）或 1（往後）
  void _moveBy(int step) {
    if (data.viewMode == 'month_grid') {
      actions.selectDateAndReload(DateTime(data.selectedDate.year, data.selectedDate.month + step, 1));
      return;
    }
    actions.selectDateAndReload(data.selectedDate.add(Duration(days: step)));
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor = context.appColors.ink2;
    double iconSize = 30;
    double buttonSize = 40;
    EdgeInsets buttonPadding = const EdgeInsets.all(4);
    if (isCompact) {
      iconSize = 24;
      buttonSize = 32;
      buttonPadding = EdgeInsets.zero;
    }
    final BoxConstraints buttonConstraints = BoxConstraints(minWidth: buttonSize, minHeight: buttonSize);

    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, size: iconSize, color: iconColor),
          onPressed: () => _moveBy(-1),
          padding: buttonPadding,
          constraints: buttonConstraints,
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, size: iconSize, color: iconColor),
          onPressed: () => _moveBy(1),
          padding: buttonPadding,
          constraints: buttonConstraints,
        ),
      ],
    );
  }
}

/// 「回到今天」：次要按鈕（細框、主題色字）
class _BackToTodayButton extends StatelessWidget {
  final ScheduleActions actions;
  final double fontSize;

  const _BackToTodayButton({required this.actions, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    return OutlinedButton(
      onPressed: () => actions.selectDateAndReload(DateTime.now()),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.acc,
        side: BorderSide(color: colors.line),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      child: Text(
        context.l10n('calendar_back_to_today'),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
      ),
    );
  }
}

/// 「路線規劃」：主要按鈕（主題色底、onAcc 字）
class _RoutePlannerButton extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;
  final bool isCompact;

  const _RoutePlannerButton({required this.data, required this.actions, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    double iconSize = 16;
    double fontSize = 13;
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    if (isCompact) {
      iconSize = 14;
      fontSize = 12;
      padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    }

    // 電腦版維持原本的大小（主題預設最小高度 40）；手機版縮成貼著文字的精簡按鈕
    ButtonStyle style = FilledButton.styleFrom(padding: padding);
    if (isCompact) {
      style = FilledButton.styleFrom(
        padding: padding,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    return FilledButton.icon(
      onPressed: () => actions.openRoutePlanner(date: data.selectedDate, events: data.events),
      icon: Icon(Icons.alt_route, size: iconSize),
      label: Text('路線規劃', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
      style: style,
    );
  }
}

/// 視圖切換（月網格／日時間軸／議程清單）：淡灰底的分段按鈕，選中的那格是白底、深色字
class _ViewModeSwitcher extends StatelessWidget {
  final ScheduleViewData data;
  final ScheduleActions actions;
  final bool isCompact;

  const _ViewModeSwitcher({required this.data, required this.actions, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    double outerPadding = 4;
    double gap = 4;
    if (isCompact) {
      outerPadding = 2;
      gap = 2;
    }

    return Container(
      padding: EdgeInsets.all(outerPadding),
      // 外面一圈細框線，和原本的大小、厚度一致
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.control + 2),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeOption(
            icon: Icons.grid_on_outlined,
            label: context.l10n('calendar_view_month'),
            isSelected: data.viewMode == 'month_grid',
            isCompact: isCompact,
            onTap: () => actions.changeViewMode('month_grid'),
          ),
          SizedBox(width: gap),
          _ViewModeOption(
            icon: Icons.view_day_outlined,
            label: context.l10n('calendar_view_timeline'),
            isSelected: data.viewMode == 'timeline',
            isCompact: isCompact,
            onTap: () => actions.changeViewMode('timeline'),
          ),
          SizedBox(width: gap),
          _ViewModeOption(
            icon: Icons.format_list_bulleted_rounded,
            label: context.l10n('calendar_view_agenda'),
            isSelected: data.viewMode == 'agenda',
            isCompact: isCompact,
            onTap: () => actions.changeViewMode('agenda'),
          ),
        ],
      ),
    );
  }
}

/// 視圖切換裡的一格
class _ViewModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  const _ViewModeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    Color foreground = colors.ink2;
    Color background = Colors.transparent;
    List<BoxShadow> shadows = const [];
    if (isSelected) {
      foreground = colors.ink;
      background = colors.surface;
      // 選中的那格微微浮起來
      shadows = [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 2, offset: const Offset(0, 1))];
    }

    double iconSize = 15;
    double fontSize = 12;
    double iconGap = 5;
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    if (isCompact) {
      iconSize = 13;
      fontSize = 11;
      iconGap = 3;
      padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.control),
          boxShadow: shadows,
        ),
        child: Row(
          children: [
            Icon(icon, size: iconSize, color: foreground),
            SizedBox(width: iconGap),
            Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: foreground)),
          ],
        ),
      ),
    );
  }
}

/// 載入中的小轉圈
class _LoadingDot extends StatelessWidget {
  final double size;

  const _LoadingDot({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.acc),
    );
  }
}
