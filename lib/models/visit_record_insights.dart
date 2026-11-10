import 'schedule_event.dart';

/// AI 從拜訪內容整理出的重點（全景地圖 4-Q）。資料由 AI 產生，每個欄位都要防護形狀不對的情況
class VisitKeyPoints {
  final String interviewee;
  final List<String> needs;
  final List<String> healthConcerns;
  final List<String> insuranceMentioned;
  final List<String> nextSteps;

  const VisitKeyPoints({
    this.interviewee = '',
    this.needs = const [],
    this.healthConcerns = const [],
    this.insuranceMentioned = const [],
    this.nextSteps = const [],
  });

  bool get isEmpty {
    return interviewee.isEmpty && needs.isEmpty && healthConcerns.isEmpty && insuranceMentioned.isEmpty && nextSteps.isEmpty;
  }

  /// 資料不是物件時回傳 null（畫面就不顯示重點）
  static VisitKeyPoints? tryParse(dynamic value) {
    if (value is! Map) return null;
    final dynamic intervieweeValue = value['interviewee'];
    return VisitKeyPoints(
      interviewee: intervieweeValue is String ? intervieweeValue.trim() : '',
      needs: _readTextList(value['needs']),
      healthConcerns: _readTextList(value['health_concerns']),
      insuranceMentioned: _readTextList(value['insurance_mentioned']),
      nextSteps: _readTextList(value['next_steps']),
    );
  }

  static List<String> _readTextList(dynamic value) {
    if (value is! List) return const [];
    final List<String> texts = [];
    for (final dynamic item in value) {
      if (item is String && item.trim().isNotEmpty) texts.add(item.trim());
    }
    return texts;
  }
}

/// 一筆待辦草稿：使用者按「建立行程」並儲存後才會變成真的行程
class VisitFollowUpDraft {
  static const String statePending = 'pending';
  static const String stateAccepted = 'accepted';
  static const String stateDismissed = 'dismissed';

  // 沒有講時間時，行程視窗預設帶入的時間
  static const int defaultHour = 10;

  final String draftId;
  final String title;
  final DateTime? date;
  final int? hour;
  final int? minute;
  final String? location;
  final String? sourceQuote;
  final String state;

  const VisitFollowUpDraft({
    required this.draftId,
    required this.title,
    required this.state,
    this.date,
    this.hour,
    this.minute,
    this.location,
    this.sourceQuote,
  });

  bool get isPending => state == statePending;
  bool get isAccepted => state == stateAccepted;

  /// 畫面上的時間文字，例：11/20 15:00；沒有日期時回傳「日期未定」
  String get whenLabel {
    final DateTime? draftDate = date;
    if (draftDate == null) return '日期未定';
    final String dateText = '${draftDate.month}/${draftDate.day}';
    final int? draftHour = hour;
    if (draftHour == null) return dateText;
    final String hourText = draftHour.toString().padLeft(2, '0');
    final String minuteText = (minute ?? 0).toString().padLeft(2, '0');
    return '$dateText $hourText:$minuteText';
  }

  /// 資料形狀不對（沒有編號或標題）時回傳 null，這筆就不顯示
  static VisitFollowUpDraft? tryParse(dynamic value) {
    if (value is! Map) return null;
    final dynamic idValue = value['draft_id'];
    final dynamic titleValue = value['title'];
    if (idValue is! String || idValue.isEmpty) return null;
    if (titleValue is! String || titleValue.trim().isEmpty) return null;

    final dynamic stateValue = value['draft_state'];
    final List<int>? time = _parseTime(value['time']);
    return VisitFollowUpDraft(
      draftId: idValue,
      title: titleValue.trim(),
      date: _parseDate(value['date']),
      hour: time?[0],
      minute: time?[1],
      location: _readOptionalText(value['location']),
      sourceQuote: _readOptionalText(value['source_quote']),
      state: stateValue is String ? stateValue : statePending,
    );
  }

  static List<VisitFollowUpDraft> parseList(dynamic value) {
    if (value is! List) return const [];
    final List<VisitFollowUpDraft> drafts = [];
    for (final dynamic item in value) {
      final VisitFollowUpDraft? draft = tryParse(item);
      if (draft != null) drafts.add(draft);
    }
    return drafts;
  }

  // 只接受 YYYY-MM-DD，且日期要真的存在（例如 2 月 30 日不算）
  static DateTime? _parseDate(dynamic value) {
    if (value is! String) return null;
    final RegExpMatch? match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final DateTime parsed = DateTime(year, month, day);
    if (parsed.month != month || parsed.day != day) return null;
    return parsed;
  }

  // 只接受 HH:MM，回傳 [時, 分]
  static List<int>? _parseTime(dynamic value) {
    if (value is! String) return null;
    final RegExpMatch? match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final int parsedHour = int.parse(match.group(1)!);
    final int parsedMinute = int.parse(match.group(2)!);
    if (parsedHour > 23 || parsedMinute > 59) return null;
    return [parsedHour, parsedMinute];
  }

  static String? _readOptionalText(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  /// 組出要帶入行程視窗的內容；編號空白代表「新增」，使用者按儲存才會建立
  ScheduleEvent buildScheduleEvent({required DateTime now, String? customerId}) {
    final DateTime? draftDate = date;
    DateTime startAt;
    if (draftDate == null) {
      // 沒有日期：預設下一個整點，由使用者自己選
      startAt = DateTime(now.year, now.month, now.day, now.hour).add(const Duration(hours: 1));
    } else {
      startAt = DateTime(draftDate.year, draftDate.month, draftDate.day, hour ?? defaultHour, minute ?? 0);
    }

    final bool hasCustomer = customerId != null;
    final String? quote = sourceQuote;
    return ScheduleEvent(
      id: '',
      profileId: '',
      customerId: customerId,
      title: title,
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
      location: location,
      eventType: hasCustomer ? 'customer_visit' : 'follow_up',
      description: quote == null ? '來自拜訪紀錄' : '來自拜訪紀錄：$quote',
    );
  }

  Map<String, dynamic> toJson() {
    final DateTime? draftDate = date;
    String? dateText;
    if (draftDate != null) {
      final String month = draftDate.month.toString().padLeft(2, '0');
      final String day = draftDate.day.toString().padLeft(2, '0');
      dateText = '${draftDate.year}-$month-$day';
    }
    final int? draftHour = hour;
    String? timeText;
    if (draftHour != null) {
      timeText = '${draftHour.toString().padLeft(2, '0')}:${(minute ?? 0).toString().padLeft(2, '0')}';
    }
    return {
      'draft_id': draftId,
      'title': title,
      'date': dateText,
      'time': timeText,
      'location': location,
      'source_quote': sourceQuote,
      'draft_state': state,
    };
  }

  VisitFollowUpDraft withState(String newState) {
    return VisitFollowUpDraft(
      draftId: draftId,
      title: title,
      state: newState,
      date: date,
      hour: hour,
      minute: minute,
      location: location,
      sourceQuote: sourceQuote,
    );
  }
}
