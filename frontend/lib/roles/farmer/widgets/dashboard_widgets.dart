import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';

/// Maps an alert severity string to a colour + icon for the alert UI.
({Color color, IconData icon}) _severityStyle(String severity) {
  switch (severity) {
    case "critical":
      return (color: const Color(0xFFC0392B), icon: Icons.crisis_alert);
    case "high":
      return (color: AppTheme.deepAmber, icon: Icons.warning_amber_rounded);
    case "medium":
      return (color: const Color(0xFFB8860B), icon: Icons.info_outline);
    default:
      return (color: AppTheme.textFaint, icon: Icons.info_outline);
  }
}

/// A bordered white card with a title — matches the app's formal look.
class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Card({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.darkGreen, fontSize: 15)),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

/// Environmental-disaster + weather card driven by the farmer's location.
///
/// Presentational: the parent fetches location + `/weather/alerts` and passes
/// the result in. Handles the loading, permission-denied and error states so the
/// dashboard always shows something sensible.
class WeatherAlertsCard extends StatelessWidget {
  final Map<String, dynamic>? weather;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const WeatherAlertsCard({
    super.key,
    required this.weather,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: "Weather & disaster alerts",
      icon: Icons.cloud_outlined,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
          SizedBox(width: 12),
          Text("Getting alerts for your location…",
              style: TextStyle(color: AppTheme.textFaint)),
        ]),
      );
    }

    if (error != null || weather == null || weather!["available"] != true) {
      return Row(children: [
        const Expanded(
          child: Text(
            "Location unavailable. Allow location access to see weather and "
            "disaster alerts for your farm.",
            style: TextStyle(color: AppTheme.textFaint, height: 1.3),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text("Enable")),
      ]);
    }

    final current = weather!["current"] as Map<String, dynamic>?;
    final alerts = (weather!["alerts"] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current != null) _currentRow(current),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.4)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle_outline, color: AppTheme.primaryGreen, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text("No disaster alerts near you right now.",
                    style: TextStyle(color: AppTheme.darkGreen)),
              ),
            ]),
          )
        else
          ...alerts.map((a) => _alertTile(a as Map<String, dynamic>)),
      ],
    );
  }

  Widget _currentRow(Map<String, dynamic> c) {
    final temp = c["temperature"];
    final desc = c["description"] ?? "";
    final humidity = c["humidity"];
    final wind = c["wind_speed"];
    return Row(children: [
      const Icon(Icons.thermostat, color: AppTheme.lightGreen, size: 18),
      const SizedBox(width: 4),
      Text(temp == null ? "—" : "${temp.toStringAsFixed(0)}°C",
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textDark)),
      const SizedBox(width: 10),
      Flexible(
        child: Text("$desc",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textFaint)),
      ),
      const Spacer(),
      if (humidity != null) ...[
        const Icon(Icons.water_drop_outlined, size: 16, color: AppTheme.lightGreen),
        Text(" $humidity%", style: const TextStyle(color: AppTheme.textFaint, fontSize: 13)),
        const SizedBox(width: 8),
      ],
      if (wind != null) ...[
        const Icon(Icons.air, size: 16, color: AppTheme.lightGreen),
        Text(" ${wind.toStringAsFixed(0)}km/h",
            style: const TextStyle(color: AppTheme.textFaint, fontSize: 13)),
      ],
    ]);
  }

  Widget _alertTile(Map<String, dynamic> a) {
    final style = _severityStyle("${a["severity"]}");
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: style.color.withValues(alpha: 0.45)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(style.icon, color: style.color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text("${a["title"]}",
                    style: TextStyle(fontWeight: FontWeight.w700, color: style.color)),
              ),
              Text("${a["severity"]}".toUpperCase(),
                  style: TextStyle(
                      color: style.color, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text("${a["message"]}",
                style: const TextStyle(color: AppTheme.textDark, height: 1.3, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

/// 3-day max/min temperature forecast as a line chart.
class ForecastChart extends StatelessWidget {
  final Map<String, dynamic>? weather;
  const ForecastChart({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final daily = (weather?["daily"] as List?) ?? const [];
    if (weather == null || weather!["available"] != true || daily.isEmpty) {
      return const _Card(
        title: "Temperature forecast",
        icon: Icons.show_chart,
        child: _Placeholder("Forecast appears once location is enabled."),
      );
    }

    final maxSpots = <FlSpot>[];
    final minSpots = <FlSpot>[];
    final labels = <String>[];
    for (var i = 0; i < daily.length; i++) {
      final d = daily[i] as Map<String, dynamic>;
      final mx = (d["temp_max"] as num?)?.toDouble();
      final mn = (d["temp_min"] as num?)?.toDouble();
      if (mx != null) maxSpots.add(FlSpot(i.toDouble(), mx));
      if (mn != null) minSpots.add(FlSpot(i.toDouble(), mn));
      labels.add(_weekday("${d["date"]}"));
    }

    return _Card(
      title: "Temperature forecast (°C)",
      icon: Icons.show_chart,
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) => Text("${v.toInt()}",
                      style: const TextStyle(color: AppTheme.textFaint, fontSize: 11)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(labels[i],
                          style: const TextStyle(color: AppTheme.textFaint, fontSize: 11)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: maxSpots,
                isCurved: true,
                color: AppTheme.deepAmber,
                barWidth: 3,
                dotData: const FlDotData(show: true),
              ),
              LineChartBarData(
                spots: minSpots,
                isCurved: true,
                color: AppTheme.primaryGreen,
                barWidth: 3,
                dotData: const FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _weekday(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return names[(d.weekday - 1) % 7];
  }
}

/// Total yield per crop, from the farmer's logged crop history, as a bar chart.
class CropYieldChart extends StatelessWidget {
  final List<dynamic> crops;
  const CropYieldChart({super.key, required this.crops});

  @override
  Widget build(BuildContext context) {
    // Sum yield_amount per crop_type.
    final totals = <String, double>{};
    for (final c in crops) {
      final m = c as Map<String, dynamic>;
      final name = (m["crop_type"] ?? "Other").toString();
      final y = (m["yield_amount"] as num?)?.toDouble() ?? 0;
      totals[name] = (totals[name] ?? 0) + y;
    }
    final entries = totals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();

    if (top.isEmpty) {
      return const _Card(
        title: "Yield by crop",
        icon: Icons.bar_chart,
        child: _Placeholder("Log crops with a yield to see this chart."),
      );
    }

    final maxY = top.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return _Card(
      title: "Yield by crop",
      icon: Icons.bar_chart,
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY * 1.2,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (v, _) => Text("${v.toInt()}",
                      style: const TextStyle(color: AppTheme.textFaint, fontSize: 11)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= top.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(top[i].key,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textFaint, fontSize: 11)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < top.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: top[i].value,
                    color: AppTheme.primaryGreen,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Share of crops logged per season, as a pie chart.
class SeasonMixChart extends StatelessWidget {
  final List<dynamic> crops;
  const SeasonMixChart({super.key, required this.crops});

  static const _palette = [
    AppTheme.primaryGreen,
    AppTheme.deepAmber,
    AppTheme.accentGreen,
    AppTheme.lightGreen,
    Color(0xFF6A7B70),
  ];

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final c in crops) {
      final m = c as Map<String, dynamic>;
      final season = (m["season"] ?? "Unknown").toString();
      counts[season] = (counts[season] ?? 0) + 1;
    }
    final entries = counts.entries.toList();

    if (entries.isEmpty) {
      return const _Card(
        title: "Crops by season",
        icon: Icons.pie_chart_outline,
        child: _Placeholder("Log crops to see your seasonal mix."),
      );
    }

    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return _Card(
      title: "Crops by season",
      icon: Icons.pie_chart_outline,
      child: SizedBox(
        height: 180,
        child: Row(children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 28,
                sectionsSpace: 2,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value.toDouble(),
                      color: _palette[i % _palette.length],
                      title: "${(entries[i].value / total * 100).round()}%",
                      radius: 52,
                      titleStyle: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: _palette[i % _palette.length],
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text("${entries[i].key} (${entries[i].value})",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textDark, fontSize: 12)),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String text;
  const _Placeholder(this.text);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textFaint, height: 1.3)),
        ),
      );
}
