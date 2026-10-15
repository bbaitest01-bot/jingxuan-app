import 'visit_project.dart';
import 'visit_result.dart';

/// 成效圖表的計算（4-2d，設計見全景地圖 4-G）：把拜訪結果分到一格一格（天或月），算出每條線的數字。
/// 這裡只算數字，不畫圖；畫圖在 lib/screens/visit_projects/visit_chart_card.dart。
class VisitChartRange {
  static const String week = 'week';
  static const String month = 'month';
  static const String year = 'year';
}

class VisitChartMode {
  static const String byResult = 'result';
  static const String byProject = 'project';
  static const String byTag = 'tag';
}

/// 圖表上的一格：週、月是一天，年是一個月
class VisitChartBucket {
  final DateTime start;
  final String axisLabel;
  final String fullLabel;
  // 還沒到的日子不畫線
  final bool isFuture;

  const VisitChartBucket({required this.start, required this.axisLabel, required this.fullLabel, required this.isFuture});
}

/// 一個期間（例：本週、2026 年 10 月）：有哪些格子、標題、起訖日
class VisitChartPeriod {
  final List<VisitChartBucket> buckets;
  final String title;
  final DateTime from;
  final DateTime to;

  const VisitChartPeriod({required this.buckets, required this.title, required this.from, required this.to});
}

/// 圖表用的一筆結果：日期、結果、專案、客戶的標籤
class VisitChartPoint {
  final DateTime visitedOn;
  final String result;
  final String projectId;
  final List<String> customerTags;

  const VisitChartPoint({required this.visitedOn, required this.result, required this.projectId, this.customerTags = const []});
}

/// 一條線：每一格的次數；還沒到的格子是 null
class VisitChartSeries {
  final String id;
  final String name;
  final List<int?> values;

  const VisitChartSeries({required this.id, required this.name, required this.values});

  int get total {
    int sum = 0;
    for (final int? value in values) {
      sum += value ?? 0;
    }
    return sum;
  }
}

const List<String> _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

String _monthDay(DateTime date) => '${date.month}/${date.day}';

/// 算出一個期間的格子。[offset] 0＝這一期，-1＝上一期。
/// 週：週一到週日；月：1 號到月底；年：1 到 12 月
VisitChartPeriod buildVisitChartPeriod(String range, int offset, DateTime today) {
  final DateTime day = DateTime(today.year, today.month, today.day);
  final List<VisitChartBucket> buckets = [];

  if (range == VisitChartRange.week) {
    final DateTime thisMonday = day.subtract(Duration(days: day.weekday - DateTime.monday));
    final DateTime monday = DateTime(thisMonday.year, thisMonday.month, thisMonday.day + offset * 7);
    for (int index = 0; index < 7; index++) {
      final DateTime date = DateTime(monday.year, monday.month, monday.day + index);
      buckets.add(VisitChartBucket(
        start: date,
        axisLabel: _monthDay(date),
        fullLabel: '${_monthDay(date)}（${_weekdayNames[date.weekday - 1]}）',
        isFuture: date.isAfter(day),
      ));
    }
    final DateTime sunday = DateTime(monday.year, monday.month, monday.day + 6);
    String title = '${_monthDay(monday)}～${_monthDay(sunday)}';
    if (offset == 0) title = '本週 $title';
    return VisitChartPeriod(buckets: buckets, title: title, from: monday, to: sunday);
  }

  if (range == VisitChartRange.year) {
    final int year = day.year + offset;
    for (int month = 1; month <= 12; month++) {
      final DateTime start = DateTime(year, month, 1);
      final bool isFuture = start.isAfter(DateTime(day.year, day.month, 1));
      buckets.add(VisitChartBucket(start: start, axisLabel: '$month月', fullLabel: '$year 年 $month 月', isFuture: isFuture));
    }
    return VisitChartPeriod(buckets: buckets, title: '$year 年', from: DateTime(year, 1, 1), to: DateTime(year, 12, 31));
  }

  // 月：1 號到月底（下個月 0 號＝這個月最後一天）
  final DateTime first = DateTime(day.year, day.month + offset, 1);
  final DateTime last = DateTime(first.year, first.month + 1, 0);
  for (int dayNumber = 1; dayNumber <= last.day; dayNumber++) {
    final DateTime date = DateTime(first.year, first.month, dayNumber);
    buckets.add(VisitChartBucket(
      start: date,
      axisLabel: _monthDay(date),
      fullLabel: '${_monthDay(date)}（${_weekdayNames[date.weekday - 1]}）',
      isFuture: date.isAfter(day),
    ));
  }
  return VisitChartPeriod(buckets: buckets, title: '${first.year} 年 ${first.month} 月', from: first, to: last);
}

/// 某筆結果落在第幾格；不在這一期回傳 -1
int _bucketIndexOf(VisitChartPeriod period, String range, DateTime visitedOn) {
  final DateTime day = DateTime(visitedOn.year, visitedOn.month, visitedOn.day);
  if (day.isBefore(period.from) || day.isAfter(period.to)) return -1;
  if (range == VisitChartRange.year) return day.month - 1;
  return day.difference(period.from).inDays;
}

/// 算出每條線。按結果／按標籤：✔ △ ✖ 和總數；按專案：每個專案一條。
/// 按標籤時只算客戶有 [tag] 這個標籤的結果
List<VisitChartSeries> buildVisitChartSeries({
  required String mode,
  required String range,
  required VisitChartPeriod period,
  required List<VisitChartPoint> points,
  required List<VisitProject> projects,
  String tag = '',
}) {
  final int count = period.buckets.length;
  // 每條線先放 0，還沒到的格子放 null
  List<int?> emptyValues() {
    final List<int?> values = [];
    for (final VisitChartBucket bucket in period.buckets) {
      values.add(bucket.isFuture ? null : 0);
    }
    return values;
  }

  final List<VisitChartSeries> series = [];
  if (mode == VisitChartMode.byProject) {
    for (final VisitProject project in projects) {
      series.add(VisitChartSeries(id: project.id, name: project.title, values: emptyValues()));
    }
  } else {
    for (final String result in VisitResult.resultOptions) {
      series.add(VisitChartSeries(id: result, name: result, values: emptyValues()));
    }
    series.add(VisitChartSeries(id: 'total', name: '總數', values: emptyValues()));
  }

  for (final VisitChartPoint point in points) {
    if (mode == VisitChartMode.byTag && !point.customerTags.contains(tag)) continue;
    final int index = _bucketIndexOf(period, range, point.visitedOn);
    if (index < 0 || index >= count || period.buckets[index].isFuture) continue;
    for (final VisitChartSeries line in series) {
      final bool matches = line.id == point.result || line.id == point.projectId || line.id == 'total';
      if (!matches) continue;
      line.values[index] = (line.values[index] ?? 0) + 1;
    }
  }
  return series;
}
