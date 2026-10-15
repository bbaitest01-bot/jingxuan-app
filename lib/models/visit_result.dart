/// 一筆專案拜訪結果（資料表 visit_results，4-2b）
/// 讀取時一起帶出專案名稱、客戶名字、連結的拜訪紀錄標題
class VisitResult {
  static const String resultPositive = 'positive';
  static const String resultConsidering = 'considering';
  static const String resultNegative = 'negative';
  static const List<String> resultOptions = [resultPositive, resultConsidering, resultNegative];
  static const int maxNoteLength = 200;

  final String id;
  final String projectId;
  final String projectTitle;
  final String customerId;
  final String customerName;
  final DateTime visitedOn;
  final String result;
  final String note;
  final String? visitRecordId;
  final String visitRecordTitle;
  // 連結的拜訪紀錄已放進垃圾桶
  final bool isVisitRecordDeleted;
  final String? scheduleEventId;
  final DateTime createdAt;

  const VisitResult({
    required this.id,
    required this.projectId,
    this.projectTitle = '',
    required this.customerId,
    this.customerName = '',
    required this.visitedOn,
    required this.result,
    this.note = '',
    this.visitRecordId,
    this.visitRecordTitle = '',
    this.isVisitRecordDeleted = false,
    this.scheduleEventId,
    required this.createdAt,
  });

  factory VisitResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? project = json['visit_projects'] as Map<String, dynamic>?;
    final Map<String, dynamic>? customer = json['customers'] as Map<String, dynamic>?;
    final Map<String, dynamic>? record = json['visit_records'] as Map<String, dynamic>?;
    final DateTime visitedOn = DateTime.tryParse(json['visited_on']?.toString() ?? '') ?? DateTime.now();

    return VisitResult(
      id: json['id'].toString(),
      projectId: json['project_id'].toString(),
      projectTitle: project?['title']?.toString() ?? '',
      customerId: json['customer_id'].toString(),
      customerName: customer?['name']?.toString() ?? '',
      visitedOn: DateTime(visitedOn.year, visitedOn.month, visitedOn.day),
      result: json['result']?.toString() ?? resultConsidering,
      note: json['note']?.toString() ?? '',
      visitRecordId: json['visit_record_id']?.toString(),
      visitRecordTitle: record?['title']?.toString() ?? '',
      isVisitRecordDeleted: record != null && record['deleted_at'] != null,
      scheduleEventId: json['schedule_event_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool get hasVisitRecord => visitRecordId != null;

  /// 新的排前面：拜訪日期新的優先，同一天看建立時間
  static int compareNewestFirst(VisitResult a, VisitResult b) {
    final int byDate = b.visitedOn.compareTo(a.visitedOn);
    if (byDate != 0) return byDate;
    return b.createdAt.compareTo(a.createdAt);
  }
}

/// 記錄或修改一筆拜訪結果時填的內容
class VisitResultDraft {
  final String projectId;
  final String projectTitle;
  final String customerId;
  final String customerName;
  final DateTime visitedOn;
  final String? result;
  final String note;
  final String? visitRecordId;
  final String visitRecordTitle;

  const VisitResultDraft({
    required this.projectId,
    this.projectTitle = '',
    required this.customerId,
    this.customerName = '',
    required this.visitedOn,
    required this.result,
    this.note = '',
    this.visitRecordId,
    this.visitRecordTitle = '',
  });
}

/// 客戶狀態的來源：最新一筆拜訪結果屬於哪個專案、哪一天
class ClientStatusSource {
  final String result;
  final String projectTitle;
  final DateTime visitedOn;

  const ClientStatusSource({required this.result, required this.projectTitle, required this.visitedOn});
}
