import 'package:flutter/material.dart';
import 'package:agripulse/core/shell/role_shell.dart';
import 'package:agripulse/roles/analyst/pages/analyst_overview_page.dart';
import 'package:agripulse/roles/analyst/pages/analyst_broadcasts_page.dart';
import 'package:agripulse/roles/analyst/pages/analyst_regional_analytics_page.dart';
import 'package:agripulse/roles/analyst/pages/analyst_monitoring_page.dart';
import 'package:agripulse/roles/analyst/pages/analyst_appointments_page.dart';

/// ANALYST dashboard — the single system-wide oversight account.
///
/// There is exactly one analyst login (provisioned in the backend seed); it
/// cannot be self-registered. Beyond the high-level overview the analyst can:
///   • broadcast disaster/early-warning alerts to regions,
///   • study regional farming analytics (yield, revenue, disease, fertilizer),
///   • monitor the community feed (read-only), and
///   • manage farmer consultation requests.
class AnalystDashboard extends StatelessWidget {
  const AnalystDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      roleTitle: "Analyst",
      destinations: [
        ShellDestination(
            label: "Overview",
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights,
            page: AnalystOverviewPage()),
        ShellDestination(
            label: "Regional Analytics",
            icon: Icons.bar_chart_outlined,
            selectedIcon: Icons.bar_chart,
            page: AnalystRegionalAnalyticsPage()),
        ShellDestination(
            label: "Broadcast Alerts",
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign,
            page: AnalystBroadcastsPage()),
        ShellDestination(
            label: "Community Monitoring",
            icon: Icons.travel_explore_outlined,
            selectedIcon: Icons.travel_explore,
            page: AnalystMonitoringPage()),
        ShellDestination(
            label: "Consultation Requests",
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note,
            page: AnalystAppointmentsPage()),
      ],
    );
  }
}
