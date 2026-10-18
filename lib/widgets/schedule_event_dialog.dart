import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule_event.dart';
import '../services/app_localizations.dart';
import '../services/location_service.dart';
import '../services/schedule_service.dart';
import '../services/google_calendar_sync_service.dart';
import '../theme/app_theme.dart';
import 'custom_toast.dart';
import '../main.dart';
import 'categorized_tag_accordion_selector.dart';
import '../screens/visit_projects/schedule_visit_result_bar.dart';
import 'schedule_event/event_form_parts.dart';
import 'schedule_event/event_location_map_dialog.dart';

/// 新增／編輯行程視窗。電腦版是置中的對話框，手機版是從下方滑上來的面板。
/// 這個檔案放資料與存檔、刪除的邏輯；畫面零件在 `schedule_event/` 資料夾。
class ScheduleEventDialog extends StatefulWidget {
  final DateTime initialDate;
  final ScheduleEvent? eventToEdit;
  final String? initialTitle;
  final String? initialEventType;
  final String? initialCustomerId;
  final bool? isBottomSheet;

  const ScheduleEventDialog({
    super.key,
    required this.initialDate,
    this.eventToEdit,
    this.initialTitle,
    this.initialEventType,
    this.initialCustomerId,
    this.isBottomSheet,
  });

  @override
  State<ScheduleEventDialog> createState() => _ScheduleEventDialogState();
}

class _ScheduleEventDialogState extends State<ScheduleEventDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _tagController;
  late TextEditingController _descriptionController;

  String? _selectedCustomerId;
  List<Map<String, dynamic>> _availableCustomers = [];
  bool _isLoadingCustomers = false;

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  double? _selectedLat;
  double? _selectedLng;
  bool _isSaving = false;
  bool _isDeleting = false;

  // 已經存在資料庫的行程才算「編輯」；語音排程帶入的內容還沒有編號，算「新增」（問題 S18）
  bool get _isExistingEvent {
    final ScheduleEvent? event = widget.eventToEdit;
    if (event == null) return false;
    return event.id.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;

    if (event != null) {
      _titleController = TextEditingController(text: event.title);
      _locationController = TextEditingController(text: event.location ?? '');
      _tagController = TextEditingController(text: event.tag ?? '');
      _descriptionController = TextEditingController(text: event.description ?? '');
      _selectedCustomerId = event.customerId;
      _startDate = event.startAt;
      _startTime = TimeOfDay.fromDateTime(event.startAt);
      _endDate = event.endAt;
      _endTime = TimeOfDay.fromDateTime(event.endAt);
      _selectedLat = event.latitude;
      _selectedLng = event.longitude;
    } else {
      _titleController = TextEditingController(text: widget.initialTitle ?? '');
      _locationController = TextEditingController();
      _tagController = TextEditingController();
      _descriptionController = TextEditingController();
      _selectedCustomerId = widget.initialCustomerId;

      final now = DateTime.now();
      _startDate = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
        now.hour + 1 > 23 ? 23 : now.hour + 1,
        0,
      );
      _startTime = TimeOfDay(hour: _startDate.hour, minute: 0);

      _endDate = _startDate.add(const Duration(hours: 1));
      _endTime = TimeOfDay(hour: _endDate.hour, minute: 0);

      // 自動初始化使用者定位
      LocationService.getCurrentUserLocation().then((loc) {
        if (mounted && loc != null && _selectedLat == null && _selectedLng == null) {
          setState(() {
            _selectedLat = loc['latitude'];
            _selectedLng = loc['longitude'];
          });
        }
      });
    }

    _loadCustomers();
  }

  // 關聯客戶是否在目前的客戶名單裡（名單還沒載入完、或客戶已移到垃圾桶時是 false）。
  // 下拉選單的值一定要在選項裡，不然會出錯（開發模式的紅色畫面，S15）
  bool get _isSelectedCustomerListed {
    final String? customerId = _selectedCustomerId;
    if (customerId == null) return false;
    return _availableCustomers.any((c) => c['id'].toString() == customerId);
  }

  // 下拉選單沒有選到客戶時顯示的提示文字
  String get _customerDropdownHint {
    if (_isLoadingCustomers) return '載入客戶中...';
    if (_selectedCustomerId != null && !_isSelectedCustomerListed) {
      return '關聯的客戶已不在名單中（可能已移至垃圾桶）';
    }
    return '選擇此行程關聯的客戶 (選定後自動帶入備註)';
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      // 離線預覽沒有初始化 Supabase，不能直接問登入者，改用服務裡的安全寫法（問題 X18）
      final String? userId = ScheduleService.instance.currentUserId;
      if (isOfflineMode || userId == null) {
        _availableCustomers = List<Map<String, dynamic>>.from(OfflineDataStore.customers)
            .where((c) => c['deleted_at'] == null)
            .toList();
      } else {
        final data = await Supabase.instance.client
            .from('customers')
            .select('id, name, nickname, phone, tags, custom_attributes')
            .isFilter('deleted_at', null)
            .order('name');
        _availableCustomers = List<Map<String, dynamic>>.from(data as List);
      }
    } catch (e) {
      debugPrint('⚠️ 載入客戶清單失敗，降級本地: $e');
      _availableCustomers = List<Map<String, dynamic>>.from(OfflineDataStore.customers)
          .where((c) => c['deleted_at'] == null)
          .toList();
    } finally {
      if (mounted) setState(() => _isLoadingCustomers = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      CustomToast.show(context, '結束時間不能早於開始時間', ToastType.warning);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String profileId = ScheduleService.instance.currentUserId ?? 'offline-user';

      // 行程類型判定：關聯客戶時對齊資料庫白名單 'customer_visit'
      String calculatedEventType;
      if (widget.eventToEdit != null) {
        final oldType = widget.eventToEdit!.eventType;
        // 若原本為個人行程但編輯時選擇了關聯客戶，自動升級為 customer_visit
        if ((oldType == 'personal' || oldType.isEmpty) && _selectedCustomerId != null) {
          calculatedEventType = 'customer_visit';
        } else {
          calculatedEventType = ScheduleEvent.normalizeEventType(oldType, hasCustomer: _selectedCustomerId != null);
        }
      } else {
        calculatedEventType = widget.initialEventType != null
            ? ScheduleEvent.normalizeEventType(widget.initialEventType, hasCustomer: _selectedCustomerId != null)
            : (_selectedCustomerId != null ? 'customer_visit' : 'personal');
      }

      final eventToSave = ScheduleEvent(
        id: widget.eventToEdit?.id ?? '',
        profileId: widget.eventToEdit?.profileId ?? profileId,
        customerId: _selectedCustomerId,
        title: _titleController.text.trim(),
        startAt: startDateTime,
        endAt: endDateTime,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        latitude: _selectedLat,
        longitude: _selectedLng,
        tag: _tagController.text.trim().isEmpty ? null : _tagController.text.trim(),
        eventType: calculatedEventType,
        isCompleted: widget.eventToEdit?.isCompleted ?? false,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        googleEventId: widget.eventToEdit?.googleEventId,
        googleCalendarId: widget.eventToEdit?.googleCalendarId,
        syncStatus: widget.eventToEdit?.syncStatus ?? 'local_only',
        lastSyncedAt: widget.eventToEdit?.lastSyncedAt,
      );

      if (_isExistingEvent) {
        await ScheduleService.instance.updateEvent(eventToSave);
        if (mounted) {
          CustomToast.show(context, '行程更新成功 ✅', ToastType.success);
        }
      } else {
        await ScheduleService.instance.createEvent(eventToSave);
        if (mounted) {
          CustomToast.show(context, '行程建立成功 📅', ToastType.success);
        }
      }

      if (mounted) {
        final resultAction = _isExistingEvent ? 'updated' : 'created';
        Navigator.of(context).pop(resultAction);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '儲存失敗：$e', ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteEvent() async {
    if (!_isExistingEvent) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除行程'),
        content: const Text('行程會移到垃圾桶，30 天內可以從垃圾桶還原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppButtonStyles.dangerText(ctx),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      await ScheduleService.instance.deleteEvent(widget.eventToEdit!.id);
      if (mounted) {
        CustomToast.show(context, '行程已移到垃圾桶', ToastType.warning);
        Navigator.of(context).pop('deleted');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '刪除失敗：$e', ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // 選了客戶：自動帶入行程標題與客戶地址（標題空白或是自動產生的才覆蓋）
  void _onCustomerChanged(String? customerId) {
    setState(() {
      _selectedCustomerId = customerId;
      if (customerId == null) return;
      final Map<String, dynamic> customer = _availableCustomers.firstWhere(
        (Map<String, dynamic> item) => item['id'].toString() == customerId,
        orElse: () => {},
      );
      if (customer.isEmpty) return;
      final String name = customer['name']?.toString() ?? '';
      if (_titleController.text.trim().isEmpty || _titleController.text.startsWith('拜訪:')) {
        _titleController.text = '拜訪 $name';
      }
      // 客戶自訂欄位裡有地址，而且地點還沒填時帶入
      final Map<String, dynamic>? customAttributes = customer['custom_attributes'] as Map<String, dynamic>?;
      final String address = customAttributes?['address']?.toString() ?? '';
      if (address.isNotEmpty && _locationController.text.trim().isEmpty) {
        _locationController.text = address;
      }
    });
  }

  // 打開地圖選點；選到的位置會立刻寫回這個視窗
  void _openInteractiveMapModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => EventLocationMapDialog(
        initialLatitude: _selectedLat,
        initialLongitude: _selectedLng,
        initialAddress: _locationController.text,
        onLocationPicked: (double latitude, double longitude, String? address) {
          setState(() {
            _selectedLat = latitude;
            _selectedLng = longitude;
            if (address != null && address.isNotEmpty) {
              _locationController.text = address;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = widget.isBottomSheet ?? (MediaQuery.of(context).size.width < 768);
    return EventDialogFrame(
      isBottomSheet: isMobile,
      child: Form(key: _formKey, child: _buildFormColumn(context)),
    );
  }

  // 表單內容：電腦版、手機版共用
  Widget _buildFormColumn(BuildContext context) {
    final bool isEdit = _isExistingEvent;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AppColors colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventDialogHeader(
          isEdit: isEdit,
          isGoogleSyncEnabled: GoogleCalendarSyncService.instance.isSyncEnabled,
          isGoogleSynced: widget.eventToEdit?.isGoogleSynced ?? false,
        ),
        const SizedBox(height: 16),
        // 有客戶、時間已到的行程：記錄拜訪結果（4-2c）
        if (isEdit) ScheduleVisitResultBar(eventId: widget.eventToEdit?.id ?? ''),

        EventCustomerSelector(
          customers: _availableCustomers,
          // 客戶不在名單裡時先不顯示值（但仍記住 _selectedCustomerId，儲存時不會遺失關聯）
          dropdownValue: _isSelectedCustomerListed ? _selectedCustomerId : null,
          hasSelectedCustomer: _selectedCustomerId != null,
          showNoCustomerOption: _selectedCustomerId == null || _isSelectedCustomerListed,
          hintText: _customerDropdownHint,
          onChanged: _onCustomerChanged,
          onClear: () => setState(() => _selectedCustomerId = null),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _titleController,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _saveEvent(),
          decoration: InputDecoration(
            labelText: '${context.l10n('event_title_label')} *',
            hintText: context.l10n('event_title_hint'),
            prefixIcon: const Icon(Icons.event_note),
          ),
          validator: (val) => (val == null || val.trim().isEmpty) ? context.l10n('event_title_hint') : null,
        ),
        const SizedBox(height: 16),

        EventDateTimeRow(
          dateLabel: context.l10n('event_start_date'),
          timeLabel: context.l10n('event_start_time'),
          date: _startDate,
          time: _startTime,
          onDatePicked: (DateTime picked) {
            setState(() {
              _startDate = picked;
              if (_endDate.isBefore(_startDate)) {
                _endDate = _startDate;
              }
            });
          },
          onTimePicked: (TimeOfDay picked) => setState(() => _startTime = picked),
        ),
        const SizedBox(height: 16),
        EventDateTimeRow(
          dateLabel: context.l10n('event_end_date'),
          timeLabel: context.l10n('event_end_time'),
          date: _endDate,
          time: _endTime,
          onDatePicked: (DateTime picked) => setState(() => _endDate = picked),
          onTimePicked: (TimeOfDay picked) => setState(() => _endTime = picked),
        ),
        const SizedBox(height: 16),

        // 地點：右邊的地圖按鈕可以打開地圖選點
        TextFormField(
          controller: _locationController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: context.l10n('event_location_label'),
            hintText: context.l10n('event_location_hint'),
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: Tooltip(
              message: '開啟地圖定位選點',
              child: IconButton(
                icon: Icon(Icons.map, color: colors.acc, size: 22),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                visualDensity: VisualDensity.compact,
                splashRadius: 20,
                onPressed: () => _openInteractiveMapModal(context),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        if (_selectedLat != null && _selectedLng != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.pin_drop, size: 14, color: colors.ok),
              const SizedBox(width: 4),
              Text(
                '已定位經緯度: ${_selectedLat!.toStringAsFixed(4)}, ${_selectedLng!.toStringAsFixed(4)}',
                style: AppTextStyles.mono(fontSize: 11, color: colors.ink3),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),

        // 行程備註／拜訪重點
        TextFormField(
          controller: _descriptionController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: '行程詳細備註 / 拜訪重點',
            hintText: '例：討論醫療險續約、檢視實支實付收據、客戶偏好下午喝茶...',
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Icon(Icons.notes_outlined),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 分類標籤選擇
        CategorizedTagAccordionSelector(
          tagsController: _tagController,
          isDark: isDark,
          primaryColor: colors.acc,
        ),
        const SizedBox(height: 24),

        EventActionBar(
          isEdit: isEdit,
          isSaving: _isSaving,
          isDeleting: _isDeleting,
          onDelete: _deleteEvent,
          onSave: _saveEvent,
        ),
      ],
    );
  }
}
