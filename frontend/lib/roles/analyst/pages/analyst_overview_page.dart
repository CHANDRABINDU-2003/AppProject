import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/core/shell/role_shell.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/services/auth_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Analyst landing page — a high-level snapshot of the platform plus a graphical
/// regional-analytics representation (revenue & yield by region).
///
/// Uses the public `/regions` and `/marketplace/products` reads for the KPI
/// tiles and `/analyst/regional-analytics` for the dashboard charts.
class AnalystOverviewPage extends StatefulWidget {
  const AnalystOverviewPage({super.key});

  @override
  State<AnalystOverviewPage> createState() => _AnalystOverviewPageState();
}

class _AnalystOverviewPageState extends State<AnalystOverviewPage> {
  final _api = ApiService.instance;
  int? _regions;
  int? _products;
  int? _broadcasts;
  List<Map<String, dynamic>> _regionStats = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final regions = await _api.get("/regions");
      final products = await _api.get("/marketplace/products");
      // Active broadcasts is best-effort — don't fail the overview if it errors.
      int broadcasts = 0;
      try {
        broadcasts = (await _api.get("/broadcasts") as List).length;
      } catch (_) {}
      // Regional analytics for the dashboard charts — also best-effort.
      List<Map<String, dynamic>> regionStats = const [];
      try {
        final ra = await _api.get("/analyst/regional-analytics");
        regionStats = ((ra as Map)["regions"] as List).cast<Map<String, dynamic>>();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _regions = (regions as List).length;
        _products = (products as List).length;
        _broadcasts = broadcasts;
        _regionStats = regionStats;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showResultDialog(context, "Error", "$e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService.instance.currentUser?.name ?? "Analyst";
    final shell = RoleShell.of(context);
    String v(int? n) => _loading ? "…" : "${n ?? 0}";

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader("Welcome, $name",
                    subtitle: "System-wide oversight."),
                const SizedBox(height: 20),
                ResponsiveGrid(
                  minTileWidth: 180,
                  childAspectRatio: 1.45,
                  children: [
                    StatCard(
                        icon: Icons.map,
                        label: "Regions",
                        value: v(_regions)),
                    StatCard(
                        icon: Icons.inventory_2,
                        label: "Products in market",
                        value: v(_products),
                        accent: AppTheme.accentGreen),
                    StatCard(
                        icon: Icons.campaign,
                        label: "Active broadcasts",
                        value: v(_broadcasts),
                        accent: AppTheme.deepAmber),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Regional analytics graphical representation ───
                const SectionTitle("Revenue by region (৳)"),
                const SizedBox(height: 8),
                _loading
                    ? _chartPlaceholder()
                    : _barCard("revenue", AppTheme.primaryGreen),
                const SizedBox(height: 24),
                const SectionTitle("Total yield by region"),
                const SizedBox(height: 8),
                _loading
                    ? _chartPlaceholder()
                    : _barCard("total_yield", AppTheme.accentGreen),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => shell?.goTo(1),
                    icon: const Icon(Icons.bar_chart, size: 18),
                    label: const Text("Full regional analytics"),
                  ),
                ),
                const SizedBox(height: 12),

                const SectionTitle("Quick actions"),
                const SizedBox(height: 8),
                ResponsiveGrid(
                  minTileWidth: 300,
                  childAspectRatio: 3.4,
                  children: [
                    QuickAction(
                        icon: Icons.bar_chart,
                        title: "Regional analytics",
                        subtitle: "Compare yield, revenue and disease by region.",
                        onTap: () => shell?.goTo(1)),
                    QuickAction(
                        icon: Icons.campaign,
                        title: "Broadcast an alert",
                        subtitle: "Warn a region about a flood, cyclone or outbreak.",
                        accent: AppTheme.deepAmber,
                        onTap: () => shell?.goTo(2)),
                    QuickAction(
                        icon: Icons.travel_explore,
                        title: "Community monitoring",
                        subtitle: "Track trending problems and reported posts.",
                        accent: AppTheme.accentGreen,
                        onTap: () => shell?.goTo(3)),
                    QuickAction(
                        icon: Icons.event_note,
                        title: "Consultation requests",
                        subtitle: "Accept or reject consultation requests.",
                        onTap: () => shell?.goTo(4)),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
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

  Widget _chartPlaceholder() => _card(const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ));

  Widget _emptyCard(String msg) => _card(SizedBox(
        height: 120,
        child: Center(
          child: Text(msg, style: const TextStyle(color: AppTheme.textFaint)),
        ),
      ));

  // ─────────── Bar chart (a metric per region) ───────────
  Widget _barCard(String key, Color color) {
    final data = [
      for (final r in _regionStats)
        ("${r["region_name"]}", (r[key] as num?)?.toDouble() ?? 0)
    ];
    if (data.isEmpty || data.every((e) => e.$2 == 0)) {
      return _emptyCard("No regional data recorded yet.");
    }
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]),
        ],
      )),
    ));
  }

  FlTitlesData _regionTitles(List<String> labels) => FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, _) => Text(
                v >= 1000
                    ? "${(v / 1000).toStringAsFixed(0)}k"
                    : "${v.toInt()}",
                style: const TextStyle(
                    color: AppTheme.textFaint, fontSize: 11)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= labels.length) return const SizedBox.shrink();
              final l = labels[i];
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.length <= 5 ? l : l.substring(0, 4),
                    style: const TextStyle(
                        color: AppTheme.textFaint, fontSize: 10)),
              );
            },
          ),
        ),
      );
}
