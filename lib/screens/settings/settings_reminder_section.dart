import 'package:flutter/material.dart';

import '../../services/schedule_reminder_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_toast.dart';
import 'settings_parts.dart';

/// 系統設定「行程提醒信」區塊：每天定時發送今日/明日行程摘要至信箱（段 2）
class SettingsReminderSection extends StatefulWidget {
  const SettingsReminderSection({super.key});

  @override
  State<SettingsReminderSection> createState() => _SettingsReminderSectionState();
}

class _SettingsReminderSectionState extends State<SettingsReminderSection> {
  final ScheduleReminderService _service = ScheduleReminderService.instance;
  bool _isSendingTest = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    await _service.loadSettings();
    if (mounted) setState(() {});
  }

  Future<void> _toggleEnabled(bool enabled) async {
    try {
      await _service.saveSettings(
        isEnabled: enabled,
        reminderTime: _service.reminderTime,
      );
      if (!mounted) return;
      setState(() {});
      if (enabled) {
        CustomToast.show(
          context,
          '已開啟每日行程提醒信（每天 ${_service.reminderTimeLabel} 寄送）',
          ToastType.success,
        );
      } else {
        CustomToast.show(context, '已關閉每日行程提醒信', ToastType.warning);
      }
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, '儲存設定失敗：$e', ToastType.error);
    }
  }

  Future<void> _changeTime(String? newTime) async {
    if (newTime == null || newTime == _service.reminderTime) return;
    try {
      await _service.saveSettings(
        isEnabled: _service.isEnabled,
        reminderTime: newTime,
      );
      if (!mounted) return;
      setState(() {});
      CustomToast.show(
        context,
        '已更新提醒時間為：${_service.reminderTimeLabel}',
        ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, '更新時間失敗：$e', ToastType.error);
    }
  }

  Future<void> _sendTestEmail() async {
    setState(() => _isSendingTest = true);
    try {
      await _service.sendTestEmail();
      if (!mounted) return;
      CustomToast.show(
        context,
        '測試信已寄出！請至信箱查收',
        ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(context, '發送測試信失敗：$e', ToastType.error);
    } finally {
      if (mounted) setState(() => _isSendingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool isEnabled = _service.isEnabled;

    String statusDescription = '關閉中：開啟後每天定時寄送拜訪行程摘要至信箱';
    Color statusColor = colors.ink3;
    if (isEnabled) {
      statusDescription = '已開啟：每天 ${_service.reminderTimeLabel} 自動發送行程信';
      statusColor = colors.ok;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(
          icon: Icons.email_outlined,
          title: '行程提醒信',
        ),
        SettingsCard(
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.email_outlined,
                title: '每日行程提醒信',
                description: statusDescription,
                descriptionColor: statusColor,
                trailing: Switch(
                  value: isEnabled,
                  onChanged: _toggleEnabled,
                ),
              ),
              if (isEnabled) ...[
                const SettingsDivider(),
                SettingsRow(
                  icon: Icons.access_time_rounded,
                  title: '寄信時間',
                  description: '可選擇當天早上寄或前一晚寄',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surface2,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: colors.line),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _service.reminderTime,
                        icon: Icon(Icons.arrow_drop_down, color: colors.ink2),
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.ink,
                          fontFamily: 'NotoSansTC',
                        ),
                        dropdownColor: colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        items: ScheduleReminderService.timeOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt['value'],
                            child: Text(opt['label'] ?? ''),
                          );
                        }).toList(),
                        onChanged: _changeTime,
                      ),
                    ),
                  ),
                ),
                const SettingsDivider(),
                SettingsRow(
                  icon: Icons.send_rounded,
                  title: '立即寄送測試信',
                  description: '立即寄發一封測試信，確認信箱能否正常收信',
                  trailing: OutlinedButton(
                    onPressed: _isSendingTest ? null : _sendTestEmail,
                    child: Text(_isSendingTest ? '寄送中...' : '寄送測試信'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
