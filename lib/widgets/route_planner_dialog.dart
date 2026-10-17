import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/schedule_event.dart';
import '../theme/app_theme.dart';
import 'custom_toast.dart';

class RoutePlannerDialog extends StatefulWidget {
  final DateTime selectedDate;
  final List<ScheduleEvent> events;
  final bool? isBottomSheet;

  const RoutePlannerDialog({
    super.key,
    required this.selectedDate,
    required this.events,
    this.isBottomSheet,
  });

  @override
  State<RoutePlannerDialog> createState() => _RoutePlannerDialogState();
}

class _RoutePlannerDialogState extends State<RoutePlannerDialog> {
  late List<ScheduleEvent> _validEvents;
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    // 篩選當日有填寫地點的行程，並按開始時間順序排序
    _validEvents = widget.events
        .where((e) => e.location != null && e.location!.trim().isNotEmpty)
        .toList();
    _validEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

    // 預設全選所有包含地點的行程
    _selectedIds = _validEvents.map((e) => e.id).toSet();
  }

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      if (selectAll) {
        _selectedIds = _validEvents.map((e) => e.id).toSet();
      } else {
        _selectedIds.clear();
      }
    });
  }

  Future<void> _launchGoogleMapsNavigation() async {
    final selectedEvents = _validEvents.where((e) => _selectedIds.contains(e.id)).toList();

    if (selectedEvents.isEmpty) {
      CustomToast.show(context, '請至少勾選 1 個有地點的行程進行導航', ToastType.warning);
      return;
    }

    String getLocStr(ScheduleEvent e) {
      if (e.latitude != null && e.longitude != null) {
        return '${e.latitude},${e.longitude}';
      }
      return Uri.encodeComponent(e.location!);
    }

    String url;
    if (selectedEvents.length == 1) {
      // 1 個地點：起點自動為使用者「目前位置」，導航至該選定地點
      final destStr = getLocStr(selectedEvents.first);
      url = 'https://www.google.com/maps/dir/?api=1&destination=$destStr&travelmode=driving';
    } else {
      // 2 個以上地點：起點自動為使用者「目前位置」，將前 N-1 個行程作為 Waypoints，最後 1 個行程作為 Destination
      final destEv = selectedEvents.last;
      final waypointsEv = selectedEvents.sublist(0, selectedEvents.length - 1);

      final destStr = getLocStr(destEv);
      final waypointsStr = waypointsEv.map((e) => getLocStr(e)).join('|');

      url = 'https://www.google.com/maps/dir/?api=1&destination=$destStr&waypoints=$waypointsStr&travelmode=driving';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        CustomToast.show(context, '無法開啟 Google Maps 連結', ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String dateStr = DateFormat('yyyy年MM月dd日', 'zh_TW').format(widget.selectedDate);
    final bool isMobile = widget.isBottomSheet ?? (MediaQuery.of(context).size.width < 768);

    Widget buildContent() {
      double titleSize = 18;
      if (isMobile) {
        titleSize = 16;
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題列：圖示、標題（宋體）、關閉
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.accSoft,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(Icons.alt_route, color: colors.acc, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '行程路線規劃 ($dateStr)',
                  style: AppTextStyles.serif(fontSize: titleSize, color: colors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.ink2),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '起點自動為目前位置。勾選要前往的地點，將依時間順序自動在 Google Maps 規劃多站駕駛路線：',
            style: TextStyle(fontSize: 12, color: colors.ink2),
          ),
          const SizedBox(height: 12),

          // 全選／全不選與已選站數
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: colors.acc),
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('全選'),
                onPressed: () => _toggleSelectAll(true),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: colors.ink2),
                icon: const Icon(Icons.deselect, size: 16),
                label: const Text('全不選'),
                onPressed: () => _toggleSelectAll(false),
              ),
              const Spacer(),
              Text(
                '已選擇 ${_selectedIds.length} / ${_validEvents.length} 站',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.acc),
              ),
            ],
          ),
          Divider(color: colors.line),

          // 行程勾選清單
          if (_validEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text('今日尚無任何包含地點的行程記錄', style: TextStyle(color: colors.ink3)),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: isMobile ? 260 : 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _validEvents.length,
                itemBuilder: (ctx, index) => _buildStopTile(colors, index),
              ),
            ),

          const SizedBox(height: 16),
          _buildActions(isMobile),
        ],
      );
    }

    if (isMobile) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: colors.line)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頂部小把手
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: buildContent(),
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: buildContent(),
          ),
        ),
      ),
    );
  }

  // 一站：順序編號、時間與標題、地點；勾選後編號變主題色
  Widget _buildStopTile(AppColors colors, int index) {
    final ScheduleEvent event = _validEvents[index];
    final bool isSelected = _selectedIds.contains(event.id);
    final int orderNum = index + 1;
    Color badgeColor = colors.surface2;
    Color badgeTextColor = colors.ink3;
    if (isSelected) {
      badgeColor = colors.acc;
      badgeTextColor = colors.onAcc;
    }

    return CheckboxListTile(
      value: isSelected,
      onChanged: (val) {
        setState(() {
          if (val == true) {
            _selectedIds.add(event.id);
          } else {
            _selectedIds.remove(event.id);
          }
        });
      },
      secondary: CircleAvatar(
        radius: 12,
        backgroundColor: badgeColor,
        child: Text('$orderNum', style: AppTextStyles.mono(fontSize: 11, color: badgeTextColor)),
      ),
      title: Text(
        '${DateFormat('HH:mm').format(event.startAt)} ${event.title}',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.ink),
      ),
      subtitle: Text(
        '${event.location}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: colors.ink2),
      ),
      activeColor: colors.acc,
      checkColor: colors.onAcc,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      dense: true,
    );
  }

  // 下方按鈕：手機版上下排、電腦版靠右並排
  Widget _buildActions(bool isMobile) {
    final Widget navigateButton = FilledButton.icon(
      onPressed: _validEvents.isEmpty ? null : _launchGoogleMapsNavigation,
      icon: const Icon(Icons.navigation, size: 18),
      label: const Text('開啟 Google 地圖導航 (免費)', style: TextStyle(fontWeight: FontWeight.bold)),
      style: FilledButton.styleFrom(
        padding: isMobile
            ? const EdgeInsets.symmetric(vertical: 14)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
    final Widget cancelButton = TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('取消'),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [navigateButton, const SizedBox(height: 8), cancelButton],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [cancelButton, const SizedBox(width: 12), navigateButton],
    );
  }
}
