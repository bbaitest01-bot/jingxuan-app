/// 一篇拜訪紀錄（資料表 visit_records，第 4 階段 4-A）
class VisitRecord {
  final String id;
  final String profileId;
  final String? customerId;
  // 連結客戶的名字與是否已在垃圾桶（讀取時一起帶出，4-C）
  final String? customerName;
  final bool isCustomerDeleted;
  final String title;
  final String rawTranscript;
  final String? organizedContent;
  final String status;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  // 放進垃圾桶的時間；null 代表正常紀錄（4-D）
  final DateTime? deletedAt;

  const VisitRecord({
    required this.id,
    required this.profileId,
    required this.title,
    required this.rawTranscript,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.customerId,
    this.customerName,
    this.isCustomerDeleted = false,
    this.organizedContent,
    this.failureReason,
    this.deletedAt,
  });

  // 處理狀態：raw 尚未整理／processing 整理中／done 完成／failed 失敗
  static const String statusRaw = 'raw';
  static const String statusProcessing = 'processing';
  static const String statusDone = 'done';
  static const String statusFailed = 'failed';

  /// 狀態的中文名稱
  String get statusLabel {
    switch (status) {
      case statusProcessing:
        return '整理中';
      case statusDone:
        return '完成';
      case statusFailed:
        return '失敗';
      default:
        return '尚未整理';
    }
  }

  /// 列表上要顯示的內容摘要：有整理後內容就用它，否則用原始轉錄
  String get previewText {
    final String organized = organizedContent ?? '';
    if (organized.trim().isNotEmpty) return organized.trim();
    return rawTranscript.trim();
  }

  factory VisitRecord.fromJson(Map<String, dynamic> json) {
    // 查詢時用 customers(name, deleted_at) 一起帶出連結客戶
    final Map<String, dynamic>? customer = json['customers'] as Map<String, dynamic>?;
    return VisitRecord(
      id: json['id'].toString(),
      profileId: json['profile_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString(),
      customerName: customer?['name'] as String?,
      isCustomerDeleted: customer?['deleted_at'] != null,
      title: json['title'] as String? ?? '',
      rawTranscript: json['raw_transcript'] as String? ?? '',
      organizedContent: json['organized_content'] as String?,
      status: json['status'] as String? ?? statusRaw,
      failureReason: json['failure_reason'] as String?,
      createdAt: _parseTime(json['created_at']),
      updatedAt: _parseTime(json['updated_at']),
      deletedAt: json['deleted_at'] == null ? null : _parseTime(json['deleted_at']),
    );
  }

  /// 放進垃圾桶或還原（傳 null 代表還原）
  VisitRecord withDeletedAt(DateTime? time) {
    return VisitRecord(
      id: id,
      profileId: profileId,
      customerId: customerId,
      customerName: customerName,
      isCustomerDeleted: isCustomerDeleted,
      title: title,
      rawTranscript: rawTranscript,
      organizedContent: organizedContent,
      status: status,
      failureReason: failureReason,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      deletedAt: time,
    );
  }

  /// 換掉連結的客戶（傳 null 代表取消連結）
  VisitRecord withCustomer({String? customerId, String? customerName}) {
    return VisitRecord(
      id: id,
      profileId: profileId,
      customerId: customerId,
      customerName: customerName,
      title: title,
      rawTranscript: rawTranscript,
      organizedContent: organizedContent,
      status: status,
      failureReason: failureReason,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static DateTime _parseTime(dynamic value) {
    final DateTime? parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return DateTime.now();
    return parsed.toLocal();
  }

  /// 預設標題，例：2026/10/14 15:30 拜訪紀錄
  static String defaultTitle(DateTime time) {
    final String month = time.month.toString().padLeft(2, '0');
    final String day = time.day.toString().padLeft(2, '0');
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}/$month/$day $hour:$minute 拜訪紀錄';
  }
}
