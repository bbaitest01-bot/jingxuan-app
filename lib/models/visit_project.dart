/// 專案拜訪（4-2，設計見全景地圖 4-G）：一個專案＝週期（或固定期間）＋每期目標次數＋選填名單
class VisitProject {
  // 週期代碼（資料庫 visit_projects.period_type）
  static const String periodDay = 'day';
  static const String periodWeek = 'week';
  static const String periodMonth = 'month';
  static const String periodYear = 'year';
  static const String periodRange = 'range';
  static const List<String> repeatPeriods = [periodDay, periodWeek, periodMonth, periodYear];

  static const String defaultTitle = '日常拜訪';
  static const int defaultTargetCount = 20;
  static const int maxTargetCount = 1000;

  final String id;
  final String title;
  final String purpose;
  final String periodType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int targetCount;
  final bool isDefault;
  // 名單：客戶編號 → 客戶名字（沒有名單＝任何客戶都算）
  final Map<String, String> members;
  final DateTime createdAt;

  const VisitProject({
    required this.id,
    required this.title,
    this.purpose = '',
    required this.periodType,
    this.startDate,
    this.endDate,
    required this.targetCount,
    this.isDefault = false,
    this.members = const {},
    required this.createdAt,
  });

  bool get isRange => periodType == periodRange;
  bool get hasMembers => members.isNotEmpty;

  /// 讀資料庫一列；名單從 visit_project_customers(customer_id, customers(name, deleted_at)) 帶出
  /// 客戶已放進垃圾桶的不列入名單
  factory VisitProject.fromJson(Map<String, dynamic> json) {
    final Map<String, String> members = {};
    final List<dynamic> memberRows = json['visit_project_customers'] as List<dynamic>? ?? [];
    for (final dynamic memberRow in memberRows) {
      final Map<String, dynamic> member = memberRow as Map<String, dynamic>;
      final Map<String, dynamic>? customer = member['customers'] as Map<String, dynamic>?;
      if (customer == null || customer['deleted_at'] != null) continue;
      members[member['customer_id'].toString()] = customer['name']?.toString() ?? '';
    }

    return VisitProject(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      periodType: json['period_type']?.toString() ?? periodMonth,
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      targetCount: (json['target_count'] as num?)?.toInt() ?? 10,
      isDefault: json['is_default'] == true,
      members: members,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final DateTime? parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// 週期的中文名稱，例：每月
  static String periodLabel(String periodType) {
    switch (periodType) {
      case periodDay:
        return '每天';
      case periodWeek:
        return '每週';
      case periodMonth:
        return '每月';
      case periodYear:
        return '每年';
      case periodRange:
        return '固定期間';
    }
    return '每月';
  }

  /// 「這一期」的起訖日（含頭尾）。週從週一開始；固定期間就是設定的起訖日
  ({DateTime start, DateTime end}) currentPeriod(DateTime today) {
    final DateTime day = DateTime(today.year, today.month, today.day);
    switch (periodType) {
      case periodDay:
        return (start: day, end: day);
      case periodWeek:
        final DateTime monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
        return (start: monday, end: monday.add(const Duration(days: 6)));
      case periodYear:
        return (start: DateTime(day.year, 1, 1), end: DateTime(day.year, 12, 31));
      case periodRange:
        final DateTime start = startDate ?? day;
        final DateTime end = endDate ?? start;
        return (start: start, end: end);
    }
    // 每月：1 號到月底（下個月 0 號＝這個月最後一天）
    return (start: DateTime(day.year, day.month, 1), end: DateTime(day.year, day.month + 1, 0));
  }

  /// 卡片上的期間說明，例：「每月重來・本月 10/1～10/31」「固定期間 11/1～11/30」
  String periodText(DateTime today) {
    final ({DateTime start, DateTime end}) period = currentPeriod(today);
    final String range = '${formatMonthDay(period.start)}～${formatMonthDay(period.end)}';
    if (isRange) return '固定期間 $range';
    const Map<String, String> currentNames = {
      periodDay: '今天',
      periodWeek: '本週',
      periodMonth: '本月',
      periodYear: '今年',
    };
    final String currentName = currentNames[periodType] ?? '本月';
    return '${periodLabel(periodType)}重來・$currentName $range';
  }

  static String formatMonthDay(DateTime date) => '${date.month}/${date.day}';
}

/// 一筆拜訪結果（資料表 visit_results；4-2b 才會新增，4-2a 先用來算進度）
class VisitResultSummary {
  final String projectId;
  final String customerId;
  final DateTime visitedOn;
  final String result;

  const VisitResultSummary({
    required this.projectId,
    required this.customerId,
    required this.visitedOn,
    required this.result,
  });

  factory VisitResultSummary.fromJson(Map<String, dynamic> json) {
    final DateTime parsed = DateTime.tryParse(json['visited_on']?.toString() ?? '') ?? DateTime.now();
    return VisitResultSummary(
      projectId: json['project_id'].toString(),
      customerId: json['customer_id'].toString(),
      visitedOn: DateTime(parsed.year, parsed.month, parsed.day),
      result: json['result']?.toString() ?? '',
    );
  }
}

/// 專案「這一期」的進度：拜訪次數、○△× 各幾次、名單裡還沒拜訪的人
class VisitProjectProgress {
  final int visitCount;
  final int positiveCount;
  final int consideringCount;
  final int negativeCount;
  final List<String> unvisitedMemberNames;

  const VisitProjectProgress({
    required this.visitCount,
    required this.positiveCount,
    required this.consideringCount,
    required this.negativeCount,
    required this.unvisitedMemberNames,
  });

  /// 進度條比例（最多 1.0）
  double ratioOf(int targetCount) {
    if (targetCount <= 0) return 0;
    final double ratio = visitCount / targetCount;
    if (ratio > 1) return 1;
    return ratio;
  }

  /// 計算某專案這一期的進度；同一位客戶拜訪多次，每次都算（P2 決定）
  static VisitProjectProgress calculate(VisitProject project, List<VisitResultSummary> results, DateTime today) {
    final ({DateTime start, DateTime end}) period = project.currentPeriod(today);
    int visitCount = 0;
    int positiveCount = 0;
    int consideringCount = 0;
    int negativeCount = 0;
    final Set<String> visitedCustomerIds = {};

    for (final VisitResultSummary result in results) {
      if (result.projectId != project.id) continue;
      if (result.visitedOn.isBefore(period.start) || result.visitedOn.isAfter(period.end)) continue;
      visitCount++;
      visitedCustomerIds.add(result.customerId);
      if (result.result == 'positive') positiveCount++;
      if (result.result == 'considering') consideringCount++;
      if (result.result == 'negative') negativeCount++;
    }

    final List<String> unvisitedMemberNames = [];
    for (final MapEntry<String, String> member in project.members.entries) {
      if (!visitedCustomerIds.contains(member.key)) unvisitedMemberNames.add(member.value);
    }

    return VisitProjectProgress(
      visitCount: visitCount,
      positiveCount: positiveCount,
      consideringCount: consideringCount,
      negativeCount: negativeCount,
      unvisitedMemberNames: unvisitedMemberNames,
    );
  }
}
