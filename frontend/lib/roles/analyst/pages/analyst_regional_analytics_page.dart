import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Regional Analytics — system-wide farming performance broken down by region.
///
/// Surfaces the five superlatives (best/worst performing, highest yield/disease/
/// fertilizer) and three charts: a yield bar chart, a revenue line chart and a
/// disease-distribution pie chart. Backed by `/analyst/regional-analytics`.
class AnalystRegionalAnalyticsPage extends StatefulWidget {
  const AnalystRegionalAnalyticsPage({super.key});

  @override
  State<AnalystRegionalAnalyticsPage> createState() =>
      _AnalystRegionalAnalyticsPageState();
}

class _AnalystRegionalAnalyticsPageState
    extends State<AnalystRegionalAnalyticsPage> {
  final _api = ApiService.instance;
  Map<String, dynamic>? _data;
  bool _loading = true;
  Object? _error;

  // A small palette so each region keeps a consistent colour across charts.
  static const _palette = [
    AppTheme.primaryGreen,
    AppTheme.accentGreen,
    AppTheme.deepAmber,
    AppTheme.warning,
    AppTheme.danger,
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
  ];

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
      final res = await _api.get("/analyst/regional-analytics");
      if (!mounted) return;
      setState(() {
        _data = res as Map<String, dynamic>;
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [PageBody(child: _body())]),
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
        const PageHeader("Regional analytics",
            subtitle: "Performance across all regions."),
        const SizedBox(height: 24),
        Text("$_error", style: const TextStyle(color: AppTheme.textFaint)),
      ]);
    }

    final d = _data!;
    final regions = (d["regions"] as List).cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader("Regional analytics",
            subtitle: "Yield, revenue, disease and fertilizer use by region."),
        const SizedBox(height: 20),

        // ─── Superlatives ───
        const SectionTitle("Highlights"),
        const SizedBox(height: 8),
        ResponsiveGrid(
          minTileWidth: 220,
          childAspectRatio: 1.6,
          children: [
            _superlativeCard("Best performing region", d["best_performing"],
                Icons.emoji_events, AppTheme.primaryGreen, "৳"),
            _superlativeCard("Worst performing region", d["worst_performing"],
                Icons.trending_down, AppTheme.danger, "৳"),
            _superlativeCard("Highest yield", d["highest_yield"],
                Icons.grass, AppTheme.accentGreen, ""),
            _superlativeCard("Highest disease", d["highest_disease"],
                Icons.coronavirus, AppTheme.warning, ""),
            _superlativeCard("Highest fertilizer usage", d["highest_fertilizer"],
                Icons.science, AppTheme.deepAmber, ""),
          ],
        ),
        const SizedBox(height: 24),

        // ─── Bar chart: yield by region ───
        const SectionTitle("Total yield by region"),
        const SizedBox(height: 8),
        _barCard(regions, "total_yield", AppTheme.primaryGreen),
        const SizedBox(height: 24),

        // ─── Line chart: revenue by region ───
        const SectionTitle("Revenue by region (৳)"),
        const SizedBox(height: 8),
        _lineCard(regions, "revenue"),
        const SizedBox(height: 24),

        // ─── Pie chart: disease distribution ───
        const SectionTitle("Disease distribution by region"),
        const SizedBox(height: 8),
        _pieCard(regions, "disease_count"),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─────────── Superlative card ───────────
  Widget _superlativeCard(
      String label, dynamic raw, IconData icon, Color color, String prefix) {
    final s = (raw as Map?)?.cast<String, dynamic>();
    final name = s?["region_name"] as String?;
    final value = (s?["value"] as num?)?.toDouble() ?? 0;
    final valueStr = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textFaint, fontSize: 12.5)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(name ?? "—",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.heading(19, weight: FontWeight.w700)),
          Text("$prefix$valueStr",
              style: const TextStyle(
                  color: AppTheme.textDark, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: child,
      );

  // ─────────── Bar chart ───────────
  Widget _barCard(List<Map<String, dynamic>> regions, String key, Color color) {
    final data = [
      for (final r in regions) (r["region_name"] as String, (r[key] as num?)?.toDouble() ?? 0)
    ];
    if (data.every((e) => e.$2 == 0)) return _emptyCard();
    final maxY = data.map((e) => e.$2).fold<double>(0, (a, b) => a > b ? a : b);
    return _card(SizedBox(
      height: 230,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2 + 1,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: _regionTitles(data.map((e) => e.$1).toList()),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: data[i].$2,
                color: color,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]),
        ],
      )),
    ));
  }

  // ─────────── Line chart ───────────
  Widget _lineCard(List<Map<String, dynamic>> regions, String key) {
    final data = [
      for (final r in regions) (r["region_name"] as String, (r[key] as num?)?.toDouble() ?? 0)
    ];
    if (data.every((e) => e.$2 == 0)) return _emptyCard();
    final maxY = data.map((e) => e.$2).fold<double>(0, (a, b) => a > b ? a : b);
    return _card(SizedBox(
      height: 230,
      child: LineChart(LineChartData(
        minY: 0,
        maxY: maxY * 1.2 + 1,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: _regionTitles(data.map((e) => e.$1).toList()),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].$2),
            ],
            isCurved: true,
            color: AppTheme.deepAmber,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.deepAmber.withValues(alpha: 0.12),
            ),
          ),
        ],
      )),
    ));
  }

  // ─────────── Pie chart ───────────
  Widget _pieCard(List<Map<String, dynamic>> regions, String key) {
    final entries = [
      for (var i = 0; i < regions.length; i++)
        (regions[i]["region_name"] as String, (regions[i][key] as num?)?.toDouble() ?? 0, i)
    ].where((e) => e.$2 > 0).toList();
    if (entries.isEmpty) return _emptyCard();
    final total = entries.fold<double>(0, (a, e) => a + e.$2);
    return _card(Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 44,
            sections: [
              for (final e in entries)
                PieChartSectionData(
                  value: e.$2,
                  title: "${(e.$2 / total * 100).round()}%",
                  color: _palette[e.$3 % _palette.length],
                  radius: 58,
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
            ],
          )),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final e in entries)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: _palette[e.$3 % _palette.length],
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text("${e.$1} (${e.$2.toInt()})",
                    style: const TextStyle(color: AppTheme.textFaint, fontSize: 12)),
              ]),
          ],
        ),
      ],
    ));
  }

  Widget _emptyCard() => _card(const SizedBox(
        height: 120,
        child: Center(
          child: Text("No data recorded yet.",
              style: TextStyle(color: AppTheme.textFaint)),
        ),
      ));

  FlTitlesData _regionTitles(List<String> labels) => FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, _) => Text(
                v >= 1000 ? "${(v / 1000).toStringAsFixed(0)}k" : "${v.toInt()}",
                style: const TextStyle(color: AppTheme.textFaint, fontSize: 11)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= labels.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    labels[i].length <= 5 ? labels[i] : labels[i].substring(0, 4),
                    style: const TextStyle(color: AppTheme.textFaint, fontSize: 10)),
              );
            },
          ),
        ),
      );
}
