import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/visit_chart.dart';
import '../../models/visit_project.dart';
import '../../services/customer_service.dart';
import '../../services/tag_manager_service.dart';
import '../../services/visit_result_service.dart';
import '../customers/customer_status_widgets.dart';
import 'visit_chart_controls.dart';
import 'visit_project_card.dart';
import '../../theme/app_theme.dart';

/// 專案拜訪頁最上方的「拜訪成效」折線圖（4-2d／P4）：
/// 週／月／年＋上一期；按結果（✔△✖＋總數）、按專案、按標籤；滑鼠移上去（手機點一下）看數字
class VisitChartCard extends StatefulWidget {
  final List<VisitProject> projects;
  // 頁面每重讀一次就加 1，圖表跟著重讀
  final int refreshToken;

  const VisitChartCard({super.key, required this.projects, required this.refreshToken});

  @override
  State<VisitChartCard> createState() => _VisitChartCardState();
}

class _VisitChartCardState extends State<VisitChartCard> {
  String _range = VisitChartRange.month;
  int _offset = 0;
  String _mode = VisitChartMode.byResult;
  String _tag = '';
  List<VisitChartTagGroup> _tagGroups = [];
  final Set<String> _hiddenSeries = {};
  List<VisitChartPoint> _points = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTags();
    _loadPoints();
  }

  @override
  void didUpdateWidget(covariant VisitChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _loadPoints();
  }

  VisitChartPeriod _period() => buildVisitChartPeriod(_range, _offset, DateTime.now());

  Future<void> _loadPoints() async {
    final VisitChartPeriod period = _period();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<VisitChartPoint> points = await VisitResultService.instance.fetchChartPoints(period.from, period.to);
      if (!mounted) return;
      setState(() {
        _points = points;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '讀取圖表資料失敗：$e';
        _isLoading = false;
      });
    }
  }

  // 「按標籤」的下拉選單：依大分類分組
  Future<void> _loadTags() async {
    List<TagCategoryModel> categories = [];
    List<TagItemModel> tags = [];
    try {
      categories = await TagManagerService.getCategories();
      tags = await TagManagerService.getTags();
    } catch (_) {
      // 讀不到標籤時「按標籤」顯示提示，其他看法照常
    }
    final List<VisitChartTagGroup> groups = [];
    for (final TagCategoryModel category in categories) {
      final List<String> names = [];
      for (final TagItemModel tag in tags) {
        if (tag.categoryId == category.id) names.add(tag.name);
      }
      if (names.isNotEmpty) groups.add(VisitChartTagGroup(categoryName: category.name, tagNames: names));
    }
    if (!mounted) return;
    setState(() {
      _tagGroups = groups;
      if (_tag.isEmpty && groups.isNotEmpty) _tag = groups.first.tagNames.first;
    });
  }

  void _changeRange(String range) {
    setState(() {
      _range = range;
      _offset = 0;
    });
    _loadPoints();
  }

  void _changeOffset(int delta) {
    setState(() => _offset += delta);
    _loadPoints();
  }

  void _changeMode(String mode) {
    setState(() {
      _mode = mode;
      _hiddenSeries.clear();
    });
  }

  void _toggleSeries(String id) {
    setState(() {
      if (_hiddenSeries.contains(id)) {
        _hiddenSeries.remove(id);
      } else {
        _hiddenSeries.add(id);
      }
    });
  }

  // 每條線的顏色：結果用客戶狀態的顏色；總數灰色；專案跟卡片色點同色
  Color _colorOf(String seriesId, int index) {
    if (seriesId == 'total') return context.appColors.ink3;
    if (VisitChartLegend.isResultId(seriesId)) return customerStatusColor(context, seriesId);
    return visitProjectColor(context, index);
  }

  String _nameOf(VisitChartSeries series) {
    if (series.id == 'total') return '總數';
    if (VisitChartLegend.isResultId(series.id)) {
      return '${CustomerService.clientStatusSymbol(series.id)} ${CustomerService.clientStatusLabel(series.id)}';
    }
    return series.name;
  }

  @override
  Widget build(BuildContext context) {
    final VisitChartPeriod period = _period();
    final List<VisitChartSeries> series = buildVisitChartSeries(
      mode: _mode,
      range: _range,
      period: period,
      points: _points,
      projects: widget.projects,
      tag: _tag,
    );

    final List<VisitChartLegendItem> legendItems = [];
    for (int index = 0; index < series.length; index++) {
      final VisitChartSeries line = series[index];
      legendItems.add(VisitChartLegendItem(
        id: line.id,
        name: _nameOf(line),
        color: _colorOf(line.id, index),
        total: line.total,
        isHidden: _hiddenSeries.contains(line.id),
      ));
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VisitChartControls(
              range: _range,
              mode: _mode,
              periodTitle: period.title,
              canGoNext: _offset < 0,
              tag: _tag,
              tagGroups: _tagGroups,
              onRangeChanged: _changeRange,
              onModeChanged: _changeMode,
              onPrevious: () => _changeOffset(-1),
              onNext: () => _changeOffset(1),
              onTagChanged: (String tag) => setState(() => _tag = tag),
            ),
            const SizedBox(height: 8),
            VisitChartSummary(mode: _mode, items: legendItems, tag: _tag),
            const SizedBox(height: 12),
            SizedBox(height: 240, child: _buildChart(period, series, legendItems)),
            const SizedBox(height: 8),
            VisitChartLegend(items: legendItems, onToggle: _toggleSeries),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(VisitChartPeriod period, List<VisitChartSeries> series, List<VisitChartLegendItem> legendItems) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final String? errorMessage = _errorMessage;
    if (errorMessage != null) return Center(child: Text(errorMessage));
    if (_mode == VisitChartMode.byTag && _tag.isEmpty) {
      return const Center(child: Text('還沒有客戶標籤，請先到標籤管理新增'));
    }

    final List<LineChartBarData> bars = [];
    int maxValue = 0;
    for (int index = 0; index < series.length; index++) {
      final VisitChartLegendItem item = legendItems[index];
      if (item.isHidden) continue;
      final List<FlSpot> spots = [];
      final List<int?> values = series[index].values;
      for (int bucketIndex = 0; bucketIndex < values.length; bucketIndex++) {
        final int? value = values[bucketIndex];
        if (value == null) continue; // 還沒到的日子不畫
        spots.add(FlSpot(bucketIndex.toDouble(), value.toDouble()));
        maxValue = math.max(maxValue, value);
      }
      final bool isTotal = item.id == 'total';
      bars.add(LineChartBarData(
        spots: spots,
        color: item.color,
        barWidth: isTotal ? 1.8 : 2.4,
        dashArray: isTotal ? [5, 4] : null,
        dotData: FlDotData(show: period.buckets.length <= 12),
      ));
    }

    final double maxY = niceChartMax(maxValue).toDouble();
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (period.buckets.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: bars,
        gridData: FlGridData(drawVerticalLine: false, horizontalInterval: maxY / 4),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: maxY / 4,
              getTitlesWidget: (double value, TitleMeta meta) => SideTitleWidget(
                meta: meta,
                child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 11)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) => _bottomTitle(period, value, meta),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Theme.of(context).colorScheme.surfaceContainerHighest,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (List<LineBarSpot> touched) => _tooltipItems(period, touched, legendItems),
          ),
        ),
      ),
    );
  }

  // 下方日期：一個月 28～31 格太擠，只標 1、6、11…號和最後一天
  Widget _bottomTitle(VisitChartPeriod period, double value, TitleMeta meta) {
    final int index = value.round();
    if (index < 0 || index >= period.buckets.length) return const SizedBox.shrink();
    final bool isLast = index == period.buckets.length - 1;
    final bool isCrowded = period.buckets.length > 12;
    if (isCrowded && index % 5 != 0 && !isLast) return const SizedBox.shrink();
    if (isCrowded && !isLast && period.buckets.length - 1 - index < 3) return const SizedBox.shrink();
    return SideTitleWidget(meta: meta, child: Text(period.buckets[index].axisLabel, style: const TextStyle(fontSize: 11)));
  }

  // 提示框：第一行是日期，下面每條線的次數
  List<LineTooltipItem?> _tooltipItems(VisitChartPeriod period, List<LineBarSpot> touched, List<VisitChartLegendItem> legendItems) {
    final List<VisitChartLegendItem> shown = legendItems.where((item) => !item.isHidden).toList();
    final List<LineTooltipItem?> items = [];
    for (int index = 0; index < touched.length; index++) {
      final LineBarSpot spot = touched[index];
      final VisitChartLegendItem item = shown[spot.barIndex];
      String text = '${item.name}  ${spot.y.toInt()} 次';
      if (index == 0) text = '${period.buckets[spot.x.toInt()].fullLabel}\n$text';
      items.add(LineTooltipItem(text, TextStyle(color: item.color, fontWeight: FontWeight.bold, fontSize: 12)));
    }
    return items;
  }
}

/// y 軸最大值取整齊的數字（4 等分），至少 4
int niceChartMax(int maxValue) {
  final double rough = math.max(maxValue, 4) / 4;
  final double power = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  for (final int step in [1, 2, 5, 10]) {
    if (step * power >= rough) return (step * power * 4).ceil();
  }
  return (power * 40).ceil();
}
