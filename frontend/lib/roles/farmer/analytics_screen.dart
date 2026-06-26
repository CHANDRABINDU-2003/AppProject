import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/i18n/app_localizations.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Farm Analytics — aggregated KPI cards plus four graphical trends built from
/// the farmer's own data:
///   • Crop yield trend     (yield by month, from crop history)
///   • Disease trend        (disease checks by month, from disease history)
///   • Fertilizer usage     (count per fertilizer, from crop history)
///   • Monthly production    (quantity by month, from crop history)
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _api = ApiService.instance;
  Map<String, dynamic>? _data;
  List<dynamic> _crops = const [];
  List<dynamic> _diseases = const [];
  Map<String, dynamic>? _tips;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get("/farmer/analytics");
      final crops = await _api.get("/farmer/crop-history");
      // Disease history is best-effort — don't fail the page if it errors.
      List<dynamic> diseases = const [];
      try {
        diseases = await _api.get("/farmer/disease/history") as List;
      } catch (_) {}
      // Regional farming tips are best-effort too.
      Map<String, dynamic>? tips;
      try {
        tips = await _api.get("/farmer/regional-tips") as Map<String, dynamic>;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _data = res as Map<String, dynamic>;
        _crops = crops as List;
        _diseases = diseases;
        _tips = tips;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // No AppBar — the dashboard shell provides the title bar and navigation.
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [PageBody(child: _body())],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _data == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageHeader(tr("analytics.title"), subtitle: tr("analytics.subtitle")),
        const SizedBox(height: 24),
        Text("$_error", style: const TextStyle(color: AppTheme.textFaint)),
      ]);
    }

    final d = _data!;
    final revenue = (d["revenue"] as num?)?.toDouble() ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(tr("analytics.title"), subtitle: tr("analytics.subtitle")),
        const SizedBox(height: 20),
        ResponsiveGrid(
          minTileWidth: 170,
          childAspectRatio: 1.35,
          children: [
            StatCard(
                icon: Icons.grass,
                label: tr("analytics.totalCrops"),
                value: "${d["total_crops"] ?? 0}"),
            StatCard(
                icon: Icons.verified,
                label: tr("analytics.healthyCrops"),
                value: "${d["healthy_crops"] ?? 0}",
                accent: AppTheme.accentGreen),
            StatCard(
                icon: Icons.coronavirus,
                label: tr("analytics.diseasedCrops"),
                value: "${d["diseased_crops"] ?? 0}",
                accent: AppTheme.danger),
            StatCard(
                icon: Icons.receipt_long,
                label: tr("analytics.sales"),
                value: "${d["marketplace_orders"] ?? 0}",
                accent: AppTheme.lightGreen),
            StatCard(
                icon: Icons.payments,
                label: tr("analytics.revenue"),
                value: "৳${revenue.toStringAsFixed(0)}",
                accent: AppTheme.deepAmber),
          ],
        ),
        const SizedBox(height: 24),

        // 1) Crop yield trend.
        SectionTitle(tr("analytics.cropYieldTrend")),
        const SizedBox(height: 8),
        _lineChartCard(_monthlySum(_crops, "yield_amount")),
        const SizedBox(height: 24),

        // 2) Disease trend.
        SectionTitle(tr("analytics.diseaseTrend")),
        const SizedBox(height: 8),
        _barChartCard(_monthlyCount(_diseases),
            color: AppTheme.danger, emptyKey: "analytics.noDisease"),
        const SizedBox(height: 24),

        // 3) Fertilizer usage.
        SectionTitle(tr("analytics.fertilizerUsage")),
        const SizedBox(height: 8),
        _categoryBarCard(_countBy(_crops, "fertilizer_used")),
        const SizedBox(height: 24),

        // 4) Monthly production.
        SectionTitle(tr("analytics.monthlyProduction")),
        const SizedBox(height: 8),
        _barChartCard(_monthlySum(_crops, "quantity"), color: AppTheme.primaryGreen),
        const SizedBox(height: 24),

        // 5) Region-specific farming tips.
        ..._regionalTips(),
      ],
    );
  }

  // ─────────── Regional farming tips ───────────
  List<Widget> _regionalTips() {
    final tips = (_tips?["tips"] as List?) ?? const [];
    if (tips.isEmpty) return const [];
    final region = _tips?["region_name"];
    final heading = region != null && "$region".isNotEmpty
        ? "Farming tips for $region"
        : "Regional farming tips";
    return [
      SectionTitle(heading),
      const SizedBox(height: 8),
      for (final t in tips.cast<Map<String, dynamic>>()) _tipCard(t),
      const SizedBox(height: 24),
    ];
  }

  Widget _tipCard(Map<String, dynamic> tip) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tips_and_updates_outlined,
                  color: AppTheme.accentGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${tip["title"] ?? ""}",
                      style: AppTheme.heading(14.5, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text("${tip["body"] ?? ""}",
                      style: const TextStyle(
                          color: AppTheme.textDark, height: 1.35, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );

  // ─────────── Data shaping ───────────

  /// `yyyy-mm` bucket → summed numeric [valueKey] over [rows], sorted by month.
  List<MapEntry<String, double>> _monthlySum(List<dynamic> rows, String valueKey) {
    final map = <String, double>{};
    for (final r in rows.cast<Map<String, dynamic>>()) {
      final month = _monthKey(r);
      if (month == null) continue;
      final v = (r[valueKey] as num?)?.toDouble() ?? 0;
      map[month] = (map[month] ?? 0) + v;
    }
    return _sortedByMonth(map);
  }

  /// `yyyy-mm` bucket → row count, sorted by month.
  List<MapEntry<String, double>> _monthlyCount(List<dynamic> rows) {
    final map = <String, double>{};
    for (final r in rows.cast<Map<String, dynamic>>()) {
      final month = _monthKey(r);
      if (month == null) continue;
      map[month] = (map[month] ?? 0) + 1;
    }
    return _sortedByMonth(map);
  }

  /// Category label → count for a string [key] (e.g. fertilizer name).
  List<MapEntry<String, double>> _countBy(List<dynamic> rows, String key) {
    final map = <String, double>{};
    for (final r in rows.cast<Map<String, dynamic>>()) {
      final raw = (r[key] as String?)?.trim();
      if (raw == null || raw.isEmpty) continue;
      map[raw] = (map[raw] ?? 0) + 1;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(6).toList();
  }

  List<MapEntry<String, double>> _sortedByMonth(Map<String, double> map) {
    final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    // Keep the most recent 8 months for readability.
    return entries.length > 8 ? entries.sublist(entries.length - 8) : entries;
  }

  /// Best date field on a row → `yyyy-mm`, or null if unparseable.
  String? _monthKey(Map<String, dynamic> r) {
    final raw = "${r["crop_date"] ?? r["created_at"] ?? ""}";
    final d = DateTime.tryParse(raw);
    if (d == null) return null;
    return "${d.year}-${d.month.toString().padLeft(2, "0")}";
  }

  // ─────────── Chart cards ───────────

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: child,
      );

  Widget _emptyCard(String key) => _card(SizedBox(
        height: 120,
        child: Center(
          child: Text(tr(key),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textFaint, height: 1.3)),
        ),
      ));

  Widget _lineChartCard(List<MapEntry<String, double>> data) {
    if (data.isEmpty) return _emptyCard("analytics.noData");
    final maxY = data.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    return _card(SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.2 + 1,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: _titles(data),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i].value),
              ],
              isCurved: true,
              color: AppTheme.primaryGreen,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primaryGreen.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _barChartCard(List<MapEntry<String, double>> data,
      {required Color color, String emptyKey = "analytics.noData"}) {
    if (data.isEmpty) return _emptyCard(emptyKey);
    final maxY = data.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    return _card(SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2 + 1,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: _titles(data),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: data[i].value,
                  color: color,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    ));
  }

  /// Fertilizer usage uses raw category labels (not months) on the x-axis.
  Widget _categoryBarCard(List<MapEntry<String, double>> data) {
    if (data.isEmpty) return _emptyCard("analytics.noData");
    final maxY = data.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    return _card(SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2 + 1,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: _leftTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 54,
                      child: Text(_short(data[i].key),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textFaint, fontSize: 10)),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: data[i].value,
                  color: AppTheme.accentGreen,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    ));
  }

  FlTitlesData _titles(List<MapEntry<String, double>> data) => FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: _leftTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= data.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_monthLabel(data[i].key),
                    style: const TextStyle(color: AppTheme.textFaint, fontSize: 10)),
              );
            },
          ),
        ),
      );

  AxisTitles _leftTitles() => AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (v, _) => Text(
              v >= 1000 ? "${(v / 1000).toStringAsFixed(0)}k" : "${v.toInt()}",
              style: const TextStyle(color: AppTheme.textFaint, fontSize: 11)),
        ),
      );

  static String _short(String s) =>
      s.length <= 12 ? s : "${s.substring(0, 11)}…";

  static String _monthLabel(String ym) {
    final parts = ym.split("-");
    if (parts.length < 2) return ym;
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return ym;
    return months[m - 1];
  }
}
