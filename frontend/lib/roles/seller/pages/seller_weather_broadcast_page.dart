import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/services/location_service.dart';
import 'package:agripulse/shared/widgets/common.dart';
import 'package:agripulse/shared/widgets/broadcast_card.dart';

/// Seller "Weather & Broadcast" — stock-planning intelligence in one place:
///   • current weather + rain outlook for the seller's location,
///   • the analyst's disaster broadcasts (flood/cyclone/pest/disease), and
///   • any weather-derived alarms returned by the weather service.
///
/// A seller uses this to anticipate demand spikes (e.g. fungicide before a wet
/// spell) and supply risks before they order stock.
class SellerWeatherBroadcastPage extends StatefulWidget {
  const SellerWeatherBroadcastPage({super.key});

  @override
  State<SellerWeatherBroadcastPage> createState() =>
      _SellerWeatherBroadcastPageState();
}

class _SellerWeatherBroadcastPageState
    extends State<SellerWeatherBroadcastPage> {
  final _api = ApiService.instance;
  Map<String, dynamic>? _weather;
  bool _loadingWeather = true;
  bool _weatherDenied = false;

  // BroadcastsView reloads itself; we bump this key to force a refresh on pull.
  Key _broadcastsKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _loadingWeather = true;
      _weatherDenied = false;
    });
    try {
      final pos = await LocationService.instance.getPosition();
      if (pos == null) {
        if (mounted) {
          setState(() {
            _weatherDenied = true;
            _loadingWeather = false;
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
        _loadingWeather = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _weatherDenied = true;
          _loadingWeather = false;
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
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader("Weather & alerts",
                    subtitle: "Plan your stock around the weather and analyst warnings."),
                const SizedBox(height: 20),

                const SectionTitle("Weather"),
                const SizedBox(height: 8),
                _weatherSection(),
                const SizedBox(height: 24),

                _analystWarnings(),

                const SectionTitle("Disaster broadcasts"),
                const SizedBox(height: 8),
                BroadcastsView(key: _broadcastsKey),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherSection() {
    if (_loadingWeather) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final available =
        !_weatherDenied && _weather != null && _weather!["available"] == true;
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
          const Expanded(
            child: Text(
                "Enable location to see local weather for stock planning.",
                style: TextStyle(color: AppTheme.textDark, height: 1.3)),
          ),
          TextButton(onPressed: _loadWeather, child: const Text("Enable")),
        ]),
      );
    }

    final current = (_weather!["current"] as Map<String, dynamic>?) ?? const {};
    final daily = (_weather!["daily"] as List?) ?? const [];
    final todayProb = daily.isNotEmpty
        ? (daily.first as Map<String, dynamic>)["precip_prob"]
        : null;

    return ResponsiveGrid(
      minTileWidth: 160,
      childAspectRatio: 1.35,
      children: [
        StatCard(
          icon: Icons.thermostat,
          label: "Temperature",
          value: _fmt(current["temperature"], "°C"),
        ),
        StatCard(
          icon: Icons.umbrella,
          label: "Rain chance",
          value: todayProb == null ? "—" : "${todayProb.round()}%",
          accent: AppTheme.accentGreen,
        ),
        StatCard(
          icon: Icons.water_drop_outlined,
          label: "Humidity",
          value: current["humidity"] == null ? "—" : "${current["humidity"]}%",
          accent: AppTheme.lightGreen,
        ),
        StatCard(
          icon: Icons.air,
          label: "Wind",
          value: _fmt(current["wind_speed"], " km/h"),
          accent: AppTheme.deepAmber,
        ),
      ],
    );
  }

  /// Weather-service alarms (flood/heat/storm/frost) shown as analyst warnings.
  Widget _analystWarnings() {
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

  static String _fmt(dynamic v, String unit) =>
      v == null ? "—" : "${(v as num).toStringAsFixed(0)}$unit";
}
