import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/i18n/app_localizations.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/services/location_service.dart';
import 'package:agripulse/shared/widgets/common.dart';
import 'package:agripulse/shared/widgets/broadcast_card.dart';

/// Weather & Alerts — one place for the farmer to see:
///   • current weather + a short forecast for their location,
///   • weather-derived disaster alarms (flood/heat/storm/frost), and
///   • the analyst's disaster broadcasts (flood, cyclone, pest/disease outbreaks).
///
/// Reuses `/weather/alerts` (Open-Meteo) and `/broadcasts`.
class WeatherAlertsScreen extends StatefulWidget {
  const WeatherAlertsScreen({super.key});

  @override
  State<WeatherAlertsScreen> createState() => _WeatherAlertsScreenState();
}

class _WeatherAlertsScreenState extends State<WeatherAlertsScreen> {
  final _api = ApiService.instance;
  Map<String, dynamic>? _weather;
  bool _loading = true;
  bool _denied = false;

  // BroadcastsView reloads itself; bump this key to refresh it on pull.
  Key _broadcastsKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _denied = false;
    });
    try {
      final pos = await LocationService.instance.getPosition();
      if (pos == null) {
        if (mounted) {
          setState(() {
            _denied = true;
            _loading = false;
          });
        }
        return;
      }
      final res = await _api.get("/weather/alerts", {
        "lat": pos.latitude,
        "lon": pos.longitude,
      });
      if (!mounted) return;
      setState(() {
        _weather = res as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _denied = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _broadcastsKey = UniqueKey());
    await _loadWeather();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(tr("weather.title"), subtitle: tr("weather.subtitle")),
                  const SizedBox(height: 20),

                  const SectionTitle("Weather"),
                  const SizedBox(height: 8),
                  _weatherSection(),
                  const SizedBox(height: 24),

                  _weatherWarnings(),

                  const SectionTitle("Disaster broadcasts"),
                  const SizedBox(height: 8),
                  BroadcastsView(key: _broadcastsKey),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final available =
        !_denied && _weather != null && _weather!["available"] == true;
    if (!available) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.softYellow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accentYellow.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          const Icon(Icons.location_off, color: AppTheme.deepAmber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tr("weather.unavailable"),
                style: const TextStyle(color: AppTheme.textDark, height: 1.3)),
          ),
          TextButton(onPressed: _loadWeather, child: Text(tr("common.enable"))),
        ]),
      );
    }

    final current = (_weather!["current"] as Map<String, dynamic>?) ?? const {};
    final daily = (_weather!["daily"] as List?) ?? const [];
    final todayProb = daily.isNotEmpty
        ? (daily.first as Map<String, dynamic>)["precip_prob"]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveGrid(
          minTileWidth: 160,
          childAspectRatio: 1.35,
          children: [
            StatCard(
              icon: Icons.thermostat,
              label: tr("weather.temperature"),
              value: _fmt(current["temperature"], "°C"),
            ),
            StatCard(
              icon: Icons.umbrella,
              label: tr("weather.rain"),
              value: todayProb == null ? "—" : "${todayProb.round()}%",
              accent: AppTheme.accentGreen,
            ),
            StatCard(
              icon: Icons.water_drop_outlined,
              label: tr("weather.humidity"),
              value: current["humidity"] == null ? "—" : "${current["humidity"]}%",
              accent: AppTheme.lightGreen,
            ),
            StatCard(
              icon: Icons.air,
              label: tr("weather.wind"),
              value: _fmt(current["wind_speed"], " km/h"),
              accent: AppTheme.deepAmber,
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionTitle(tr("weather.forecast")),
        const SizedBox(height: 8),
        for (final d in daily) _forecastTile(d as Map<String, dynamic>),
      ],
    );
  }

  /// Weather-service alarms (flood/heat/storm/frost) shown above broadcasts.
  Widget _weatherWarnings() {
    final alerts = (_weather?["alerts"] as List?) ?? const [];
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Weather warnings"),
        const SizedBox(height: 8),
        for (final a in alerts)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber, color: AppTheme.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    a is Map ? "${a["title"] ?? a["message"] ?? a}" : "$a",
                    style: const TextStyle(color: AppTheme.textDark, height: 1.3)),
              ),
            ]),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _forecastTile(Map<String, dynamic> d) {
    final prob = d["precip_prob"];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(children: [
        SizedBox(
          width: 48,
          child: Text(_weekday("${d["date"]}"),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text("${d["description"] ?? ""}",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textFaint, fontSize: 13)),
        ),
        if (prob != null) ...[
          const Icon(Icons.umbrella, size: 15, color: AppTheme.accentGreen),
          Text(" ${prob.round()}%",
              style: const TextStyle(color: AppTheme.textFaint, fontSize: 13)),
          const SizedBox(width: 10),
        ],
        Text(
          "${_fmt(d["temp_max"], "°")} / ${_fmt(d["temp_min"], "°")}",
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textDark),
        ),
      ]),
    );
  }

  static String _fmt(dynamic v, String unit) =>
      v == null ? "—" : "${(v as num).toStringAsFixed(0)}$unit";

  static String _weekday(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return names[(d.weekday - 1) % 7];
  }
}
