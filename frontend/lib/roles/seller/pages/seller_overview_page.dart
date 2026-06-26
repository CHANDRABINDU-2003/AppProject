import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/core/shell/role_shell.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/services/auth_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Seller landing page — headline sales KPIs, graphical sales/product charts and
/// shortcuts into catalogue/orders. Backed by `/seller/analytics`.
class SellerOverviewPage extends StatefulWidget {
  const SellerOverviewPage({super.key});

  @override
  State<SellerOverviewPage> createState() => _SellerOverviewPageState();
}

class _SellerOverviewPageState extends State<SellerOverviewPage> {
  final _api = ApiService.instance;
  Map<String, dynamic> _analytics = {};
  bool _loading = true;

  // Consistent colours for the order-status pie chart.
  static const _statusColors = <String, Color>{
    "pending": AppTheme.deepAmber,
    "confirmed": AppTheme.primaryGreen,
    "shipped": Color(0xFF3B82F6),
    "delivered": AppTheme.accentGreen,
    "cancelled": AppTheme.danger,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await _api.get("/seller/analytics");
      if (!mounted) return;
      setState(() {
        _analytics = Map<String, dynamic>.from(a);
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
    final name = AuthService.instance.currentUser?.name ?? "Seller";
    final shell = RoleShell.of(context);
    String v(String k) => _loading ? "…" : "${_analytics[k] ?? 0}";

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader("Welcome, $name",
                    subtitle: "Your store at a glance."),
                const SizedBox(height: 20),
                ResponsiveGrid(
                  minTileWidth: 200,
                  childAspectRatio: 1.45,
                  children: [
                    StatCard(icon: Icons.inventory_2, label: "Products", value: v("total_products")),
                    StatCard(
                        icon: Icons.receipt_long,
                        label: "Orders",
                        value: v("total_orders"),
                        accent: AppTheme.accentGreen),
                    StatCard(
                        icon: Icons.payments,
                        label: "Est. revenue (৳)",
                        value: v("estimated_revenue"),
                        accent: AppTheme.deepAmber),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Graphical sales & product representation ───
                const SectionTitle("Revenue by product (৳)"),
                const SizedBox(height: 8),
                _loading
                    ? _chartPlaceholder()
                    : _barCard("product_revenue", "revenue", AppTheme.primaryGreen),
                const SizedBox(height: 24),
                const SectionTitle("Stock by product"),
                const SizedBox(height: 8),
                _loading
                    ? _chartPlaceholder()
                    : _barCard("product_stock", "stock", AppTheme.deepAmber),
                const SizedBox(height: 24),
                const SectionTitle("Orders by status"),
                const SizedBox(height: 8),
                _loading ? _chartPlaceholder() : _statusPieCard(),
                const SizedBox(height: 24),

                const SectionTitle("Quick actions"),
                const SizedBox(height: 8),
                ResponsiveGrid(
                  minTileWidth: 300,
                  childAspectRatio: 3.4,
                  children: [
                    QuickAction(
                        icon: Icons.add_box,
                        title: "Manage products",
                        subtitle: "Add stock and update your catalogue.",
                        onTap: () => shell?.goTo(1)),
                    QuickAction(
                        icon: Icons.local_shipping,
                        title: "View orders",
                        subtitle: "See who ordered, quantity, status and region.",
                        accent: AppTheme.accentGreen,
                        onTap: () => shell?.goTo(2)),
                    QuickAction(
                        icon: Icons.cloud,
                        title: "Weather & broadcasts",
                        subtitle: "Plan stock around weather and analyst warnings.",
                        accent: AppTheme.deepAmber,
                        onTap: () => shell?.goTo(3)),
                    QuickAction(
                        icon: Icons.event_available,
                        title: "Consult analyst",
                        subtitle: "Book a consultation with the system analyst.",
                        onTap: () => shell?.goTo(4)),
                    QuickAction(
                        icon: Icons.science,
                        title: "Fertilizer assistant",
                        subtitle: "Ask which fertilizer suits a crop.",
                        onTap: () => shell?.goTo(5)),
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

  // ─────────── Bar chart (revenue or stock per product) ───────────
  Widget _barCard(String listKey, String valueKey, Color color) {
    final raw = (_analytics[listKey] as List?) ?? const [];
    final data = [
      for (final e in raw)
        (
          "${(e as Map)["name"]}",
          (e[valueKey] as num?)?.toDouble() ?? 0,
        )
    ];
    if (data.isEmpty || data.every((e) => e.$2 == 0)) {
      return _emptyCard("No product data yet.");
    }
    final maxY = data.map((e) => e.$2).fold<double>(0, (a, b) => a > b ? a : b);
    return _card(SizedBox(
      height: 230,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2 + 1,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: _productTitles(data.map((e) => e.$1).toList()),
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

  // ─────────── Pie chart (orders grouped by status) ───────────
  Widget _statusPieCard() {
    final map = (_analytics["orders_by_status"] as Map?)?.cast<String, dynamic>() ?? {};
    final entries = [
      for (final e in map.entries) (e.key, (e.value as num?)?.toDouble() ?? 0)
    ].where((e) => e.$2 > 0).toList();
    if (entries.isEmpty) return _emptyCard("No orders yet.");
    final total = entries.fold<double>(0, (a, e) => a + e.$2);
    Color colorFor(String s) => _statusColors[s] ?? AppTheme.textFaint;
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
                  color: colorFor(e.$1),
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
                        color: colorFor(e.$1),
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text("${e.$1} (${e.$2.toInt()})",
                    style: const TextStyle(
                        color: AppTheme.textFaint, fontSize: 12)),
              ]),
          ],
        ),
      ],
    ));
  }

  FlTitlesData _productTitles(List<String> labels) => FlTitlesData(
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
                child: Text(l.length <= 6 ? l : l.substring(0, 5),
                    style: const TextStyle(
                        color: AppTheme.textFaint, fontSize: 10)),
              );
            },
          ),
        ),
      );
}
