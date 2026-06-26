import 'package:flutter/material.dart';
import 'package:agripulse/core/shell/role_shell.dart';
import 'package:agripulse/roles/community/community_screen.dart';
import 'package:agripulse/roles/farmer/pages/farmer_overview_page.dart';
import 'package:agripulse/roles/farmer/crop_history_screen.dart';
import 'package:agripulse/roles/farmer/disease_screen.dart';
import 'package:agripulse/roles/farmer/fertilizer_form_screen.dart';
import 'package:agripulse/roles/farmer/weather_alerts_screen.dart';
import 'package:agripulse/roles/farmer/nearby_sellers_screen.dart';
import 'package:agripulse/roles/farmer/marketplace_screen.dart';
import 'package:agripulse/roles/farmer/appointment_screen.dart';
import 'package:agripulse/roles/farmer/analytics_screen.dart';
import 'package:agripulse/roles/farmer/assistant_screen.dart';

/// FARMER dashboard — a persistent, multi-page shell. The destination order here
/// defines the indices used by the overview's quick actions.
///
/// Final menu: Overview · Disease Detection · Fertilizer Recommendation ·
/// Weather & Alerts · Nearby Sellers · Community · Consult Analyst · Analytics ·
/// Ask AI.
class FarmerDashboard extends StatelessWidget {
  const FarmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      roleTitle: "Farmer",
      destinations: [
        ShellDestination(
            label: "Overview",
            labelKey: "nav.overview",
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            page: FarmerOverviewPage()),
        ShellDestination(
            label: "My Crops",
            labelKey: "nav.crops",
            icon: Icons.grass_outlined,
            selectedIcon: Icons.grass,
            page: CropHistoryScreen()),
        ShellDestination(
            label: "Disease Detection",
            labelKey: "nav.disease",
            icon: Icons.camera_alt_outlined,
            selectedIcon: Icons.camera_alt,
            page: DiseaseScreen()),
        ShellDestination(
            label: "Fertilizer Recommendation",
            labelKey: "nav.fertilizer",
            icon: Icons.science_outlined,
            selectedIcon: Icons.science,
            page: FertilizerFormScreen()),
        ShellDestination(
            label: "Weather & Alerts",
            labelKey: "nav.weatherAlerts",
            icon: Icons.cloud_outlined,
            selectedIcon: Icons.cloud,
            page: WeatherAlertsScreen()),
        ShellDestination(
            label: "Nearby Sellers",
            labelKey: "nav.sellers",
            icon: Icons.storefront_outlined,
            selectedIcon: Icons.storefront,
            page: NearbySellersScreen()),
        ShellDestination(
            label: "Marketplace",
            labelKey: "nav.marketplace",
            icon: Icons.shopping_cart_outlined,
            selectedIcon: Icons.shopping_cart,
            page: MarketplaceScreen()),
        ShellDestination(
            label: "Community",
            labelKey: "nav.community",
            icon: Icons.forum_outlined,
            selectedIcon: Icons.forum,
            page: CommunityScreen()),
        ShellDestination(
            label: "Consult Analyst",
            labelKey: "nav.consult",
            icon: Icons.event_available_outlined,
            selectedIcon: Icons.event_available,
            page: AppointmentScreen()),
        ShellDestination(
            label: "Analytics",
            labelKey: "nav.analytics",
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights,
            page: AnalyticsScreen()),
        ShellDestination(
            label: "Ask AI",
            labelKey: "nav.askAi",
            icon: Icons.chat_outlined,
            selectedIcon: Icons.chat,
            page: AssistantScreen()),
      ],
    );
  }
}
