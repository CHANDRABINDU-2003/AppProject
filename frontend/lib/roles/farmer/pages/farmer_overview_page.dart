import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/core/shell/role_shell.dart';
import 'package:agripulse/shared/i18n/app_localizations.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/services/auth_service.dart';
import 'package:agripulse/shared/services/location_service.dart';
import 'package:agripulse/shared/widgets/common.dart';
import 'package:agripulse/roles/farmer/widgets/dashboard_widgets.dart';

/// Landing page of the farmer dashboard.
///
/// Replaces the old flash-card home: a greeting, a few live KPIs pulled from the
/// backend, quick shortcuts into each section (which switch the shell tab rather
/// than push a throwaway route), and a tip. The section indices below match the
/// destination order declared in [FarmerDashboard].
class FarmerOverviewPage extends StatefulWidget {
  const FarmerOverviewPage({super.key});

  @override
  State<FarmerOverviewPage> createState() => _FarmerOverviewPageState();
}

class _FarmerOverviewPageState extends State<FarmerOverviewPage> {
  final _api = ApiService.instance;
  List<dynamic> _cropList = const [];
  int? _crops;
  int? _orders;
  bool _loading = true;

  // Weather / disaster alerts (location based).
  Map<String, dynamic>? _weather;
  bool _weatherLoading = true;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _load();
    // Right after login the farmer lands here — ask for location permission and
    // load weather/disaster alerts for their farm.
    _loadWeather();
  }

  Future<void> _load() async {
    try {
      final crops = await _api.get("/farmer/crop-history");
      final orders = await _api.get("/marketplace/orders");
      if (!mounted) return;
      setState(() {
        _cropList = crops as List;
        _crops = _cropList.length;
        _orders = (orders as List).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWeather() async {
    if (mounted) {
      setState(() {
        _weatherLoading = true;
        _weatherError = null;
      });
    }
    try {
      final pos = await LocationService.instance.getPosition();
      if (pos == null) {
        if (mounted) {
          setState(() {
            _weatherError = "location-denied";
            _weatherLoading = false;
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
        _weatherLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherError = "$e";
          _weatherLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService.instance.currentUser?.name ?? "Farmer";
    final shell = RoleShell.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader("${tr("overview.welcome")}, $name",
                    subtitle: tr("overview.snapshot")),
                const SizedBox(height: 20),
                ResponsiveGrid(
                  minTileWidth: 200,
                  childAspectRatio: 1.45,
                  children: [
                    StatCard(
                        icon: Icons.history,
                        label: "Crops logged",
                        value: _loading ? "…" : "${_crops ?? 0}"),
                    StatCard(
                        icon: Icons.receipt_long,
                        label: "Marketplace orders",
                        value: _loading ? "…" : "${_orders ?? 0}",
                        accent: AppTheme.deepAmber),
                    const StatCard(
                        icon: Icons.eco,
                        label: "AI tools available",
                        value: "3",
                        accent: AppTheme.accentGreen),
                  ],
                ),
                const SizedBox(height: 24),
                WeatherAlertsCard(
                  weather: _weather,
                  loading: _weatherLoading,
                  error: _weatherError,
                  onRetry: _loadWeather,
                ),
                const SizedBox(height: 24),
                const SectionTitle("Quick actions"),
                const SizedBox(height: 8),
                ResponsiveGrid(
                  minTileWidth: 300,
                  childAspectRatio: 3.4,
                  children: [
                    QuickAction(
                      icon: Icons.grass,
                      title: "Log a crop",
                      subtitle: "Record yield, quantity and price to fill your charts.",
                      onTap: () => shell?.goTo(1),
                    ),
                    QuickAction(
                      icon: Icons.camera_alt,
                      title: "Detect crop disease",
                      subtitle: "Snap a leaf photo for an instant diagnosis.",
                      onTap: () => shell?.goTo(2),
                    ),
                    QuickAction(
                      icon: Icons.science,
                      title: "Fertilizer advice",
                      subtitle: "Get a recommendation for your field.",
                      accent: AppTheme.deepAmber,
                      onTap: () => shell?.goTo(3),
                    ),
                    QuickAction(
                      icon: Icons.storefront,
                      title: "Nearby sellers",
                      subtitle: "Find sellers in your region and order.",
                      onTap: () => shell?.goTo(5),
                    ),
                    QuickAction(
                      icon: Icons.shopping_cart,
                      title: "Browse marketplace",
                      subtitle: "See all products on offer and place an order.",
                      accent: AppTheme.deepAmber,
                      onTap: () => shell?.goTo(6),
                    ),
                    QuickAction(
                      icon: Icons.chat,
                      title: "Ask AI",
                      subtitle: "Chat about crops, soil and pests.",
                      accent: AppTheme.accentGreen,
                      onTap: () => shell?.goTo(10),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SectionTitle(tr("tools.title")),
                const SizedBox(height: 8),
                ResponsiveGrid(
                  minTileWidth: 300,
                  childAspectRatio: 3.4,
                  children: [
                    QuickAction(
                      icon: Icons.cloud,
                      title: tr("tools.weather"),
                      subtitle: tr("tools.weatherSub"),
                      onTap: () => shell?.goTo(4),
                    ),
                    QuickAction(
                      icon: Icons.insights,
                      title: tr("tools.analytics"),
                      subtitle: tr("tools.analyticsSub"),
                      accent: AppTheme.accentGreen,
                      onTap: () => shell?.goTo(9),
                    ),
                    QuickAction(
                      icon: Icons.event_available,
                      title: tr("tools.consult"),
                      subtitle: tr("tools.consultSub"),
                      accent: AppTheme.deepAmber,
                      onTap: () => shell?.goTo(8),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionTitle("Farm at a glance"),
                const SizedBox(height: 8),
                ForecastChart(weather: _weather),
                const SizedBox(height: 12),
                CropYieldChart(crops: _cropList),
                const SizedBox(height: 12),
                SeasonMixChart(crops: _cropList),
                const SizedBox(height: 24),
                _tipBanner(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.softYellow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accentYellow.withValues(alpha: 0.5)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: AppTheme.deepAmber),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Tip of the day",
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkGreen)),
                  SizedBox(height: 4),
                  Text(
                    "Snap a leaf photo to detect disease early, or open Fertilizer "
                    "Advice and enter your soil details for a recommendation made "
                    "for your field.",
                    style: TextStyle(color: AppTheme.textDark, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
