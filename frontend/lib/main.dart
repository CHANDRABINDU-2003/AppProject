import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/roles/auth/login_screen.dart';
import 'package:agripulse/roles/farmer/farmer_dashboard.dart';
import 'package:agripulse/roles/seller/seller_dashboard.dart';
import 'package:agripulse/roles/analyst/analyst_dashboard.dart';

void main() {
  runApp(const AgriPulseApp());
}

class AgriPulseApp extends StatelessWidget {
  const AgriPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "AgriPulse",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(), // formal green & white theme
      // Always start at the login screen — we never auto-skip into a
      // dashboard, so even a returning/registered user has to log in first.
      home: const LoginScreen(),
    );
  }
}

/// Maps a role string to its dashboard widget. Reused after login.
///
/// The system has exactly three roles, each in its own folder under
/// `lib/roles/`:
///   farmer  → roles/farmer
///   seller  → roles/seller
///   analyst → roles/analyst  (single oversight account)
Widget dashboardForRole(String role) {
  switch (role) {
    case "seller":
      return const SellerDashboard();
    case "analyst":
      return const AnalystDashboard();
    case "farmer":
    default:
      return const FarmerDashboard();
  }
}
