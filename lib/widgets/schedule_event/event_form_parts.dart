import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 新增／編輯行程視窗用到的畫面零件。
/// 這些零件只負責「長什麼樣子」；資料與存檔邏輯都在 `schedule_event_dialog.dart`。

/// 視窗外框：電腦版是置中的對話框；手機版是從下方滑上來的面板，上面有一條小把手。
/// 內容太長時可以捲動。
class EventDialogFrame extends StatelessWidget {
  final bool isBottomSheet;
  final Widget child;

  const EventDialogFrame({super.key, required this.isBottomSheet, required this.child});

  @override
  Widget build(BuildContext context) {
    if (isBottomSheet) {
      return _buildBottomSheet(context);
    }

    double dialogWidth = MediaQuery.of(context).size.width * 0.94;
    if (MediaQuery.of(context).size.width >= 560) {
      dialogWidth = 520;
    }
    return Dialog(
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(child: child),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    final AppColors colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: colors.line)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              physics: const ClampingScrollPhysics(),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// 視窗最上方：圖示＋標題（新增或編輯）、Google 同步標籤、關閉按鈕
class EventDialogHeader extends StatelessWidget {
  final bool isEdit;
  final bool isGoogleSyncEnabled;
  final bool isGoogleSynced;

  const EventDialogHeader({
    super.key,
    required this.isEdit,
    required this.isGoogleSyncEnabled,
    required this.isGoogleSynced,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    String title = context.l10n('event_add_title');
    if (isEdit) {
      title = context.l10n('event_edit_title');
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.accSoft,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(Icons.event_available, color: colors.acc, size: 22),
              ),
              // 視窗標題用宋體
              Text(title, style: AppTextStyles.serif(fontSize: 20, color: colors.ink)),
              if (isGoogleSyncEnabled) _GoogleSyncBadge(isSynced: isGoogleSynced),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.ink2),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// 「Google 已對齊／自動對齊 Google」小標籤
class _GoogleSyncBadge extends StatelessWidget {
  final bool isSynced;

  const _GoogleSyncBadge({required this.isSynced});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    IconData icon = Icons.cloud_sync_outlined;
    String label = '單向推送 Google';
    if (isSynced) {
      icon = Icons.sync;
      label = 'Google 已推送';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.accSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.acc),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: colors.acc, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 「關聯客戶」區塊：標題、清除關聯、客戶下拉選單
class EventCustomerSelector extends StatelessWidget {
  final List<Map<String, dynamic>> customers;

  /// 下拉選單目前顯示的值（客戶不在名單裡時是 null）
  final String? dropdownValue;

  /// 是否已經有關聯客戶（決定要不要顯示「清除關聯」）
  final bool hasSelectedCustomer;

  /// 有關聯客戶但不在名單裡（載入中或已刪除）時，不放「無關聯」選項，避免看起來像關聯被清掉
  final bool showNoCustomerOption;
  final String hintText;
  final ValueChanged<String?> onChanged;
  final VoidCallback onClear;

  const EventCustomerSelector({
    super.key,
    required this.customers,
    required this.dropdownValue,
    required this.hasSelectedCustomer,
    required this.showNoCustomerOption,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: colors.acc),
                  const SizedBox(width: 6),
                  Text(
                    '關聯客戶 (可選)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.ink2),
                  ),
                ],
              ),
              if (hasSelectedCustomer)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('清除關聯', style: TextStyle(fontSize: 12, color: colors.ink3)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: dropdownValue,
              isExpanded: true,
              hint: Text(hintText, style: TextStyle(fontSize: 13, color: colors.ink3)),
              items: _buildItems(colors),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String?>> _buildItems(AppColors colors) {
    final List<DropdownMenuItem<String?>> items = [];
    if (showNoCustomerOption) {
      items.add(const DropdownMenuItem<String?>(
        value: null,
        child: Text('無關聯客戶 (個人行程)', style: TextStyle(fontSize: 13)),
      ));
    }
    for (final Map<String, dynamic> customer in customers) {
      items.add(DropdownMenuItem<String?>(
        value: customer['id'].toString(),
        child: _CustomerOptionRow(customer: customer, colors: colors),
      ));
    }
    return items;
  }
}

/// 客戶下拉選單裡的一列：名字縮寫圓圈、名字、電話
class _CustomerOptionRow extends StatelessWidget {
  final Map<String, dynamic> customer;
  final AppColors colors;

  const _CustomerOptionRow({required this.customer, required this.colors});

  @override
  Widget build(BuildContext context) {
    final String name = customer['name']?.toString() ?? '未命名';
    final String phone = customer['phone']?.toString() ?? '';
    String initial = '?';
    if (name.isNotEmpty) {
      initial = name[0];
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: colors.accSoft,
          child: Text(initial, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.acc)),
        ),
        const SizedBox(width: 8),
        Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.ink)),
        if (phone.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text('($phone)', style: AppTextStyles.mono(fontSize: 11, color: colors.ink3)),
        ],
      ],
    );
  }
}

/// 一排「日期＋時間」選擇（開始或結束各一排）
class EventDateTimeRow extends StatelessWidget {
  final String dateLabel;
  final String timeLabel;
  final DateTime date;
  final TimeOfDay time;
  final ValueChanged<DateTime> onDatePicked;
  final ValueChanged<TimeOfDay> onTimePicked;

  const EventDateTimeRow({
    super.key,
    required this.dateLabel,
    required this.timeLabel,
    required this.date,
    required this.time,
    required this.onDatePicked,
    required this.onTimePicked,
  });

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      onDatePicked(picked);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: time);
    if (picked != null) {
      onTimePicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle valueStyle = AppTextStyles.mono(fontSize: 14, color: context.appColors.ink);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pickDate(context),
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: dateLabel,
                prefixIcon: const Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(DateFormat('yyyy/MM/dd').format(date), style: valueStyle),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => _pickTime(context),
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: timeLabel,
                prefixIcon: const Icon(Icons.access_time, size: 18),
              ),
              child: Text(time.format(context), style: valueStyle),
            ),
          ),
        ),
      ],
    );
  }
}

/// 視窗最下方：刪除（只有編輯時有）、取消、儲存
class EventActionBar extends StatelessWidget {
  final bool isEdit;
  final bool isSaving;
  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback onSave;

  const EventActionBar({
    super.key,
    required this.isEdit,
    required this.isSaving,
    required this.isDeleting,
    required this.onDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    String saveLabel = context.l10n('event_add_title');
    if (isEdit) {
      saveLabel = context.l10n('profile_save_changes');
    }

    Widget saveChild = Text(saveLabel, style: const TextStyle(fontWeight: FontWeight.bold));
    if (isSaving) {
      saveChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.onAcc),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isEdit)
          TextButton.icon(
            onPressed: isDeleting ? null : onDelete,
            style: AppButtonStyles.dangerText(context),
            icon: const Icon(Icons.delete_outline),
            label: Text(context.l10n('event_delete_btn')),
          ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n('cancel')),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: isSaving ? null : onSave,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: saveChild,
        ),
      ],
    );
  }
}
