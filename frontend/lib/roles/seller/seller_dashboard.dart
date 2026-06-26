import 'package:flutter/material.dart';
import 'package:agripulse/core/shell/role_shell.dart';
import 'package:agripulse/roles/seller/pages/seller_overview_page.dart';
import 'package:agripulse/roles/seller/pages/seller_products_page.dart';
import 'package:agripulse/roles/seller/pages/seller_orders_page.dart';
import 'package:agripulse/roles/seller/pages/seller_weather_broadcast_page.dart';
import 'package:agripulse/roles/farmer/assistant_screen.dart';
import 'package:agripulse/roles/farmer/appointment_screen.dart';

/// SELLER dashboard — multi-page shell. Backend RBAC restricts `/seller/*` to
/// seller accounts.
///
/// Final menu: Overview · Products · Orders · Weather & Alerts ·
/// Fertilizer Assistant.
class SellerDashboard extends StatelessWidget {
  const SellerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      roleTitle: "Seller",
      destinations: [
        ShellDestination(
            label: "Overview",
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            page: SellerOverviewPage()),
        ShellDestination(
            label: "Products",
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2,
            page: SellerProductsPage()),
        ShellDestination(
            label: "Orders",
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            page: SellerOrdersPage()),
        ShellDestination(
            label: "Weather & Alerts",
            icon: Icons.cloud_outlined,
            selectedIcon: Icons.cloud,
            page: SellerWeatherBroadcastPage()),
        ShellDestination(
            label: "Consult Analyst",
            icon: Icons.event_available_outlined,
            selectedIcon: Icons.event_available,
            page: AppointmentScreen()),
        ShellDestination(
            label: "Fertilizer Assistant",
            icon: Icons.science_outlined,
            selectedIcon: Icons.science,
            page: AssistantScreen()),
      ],
    );
  }
}
