import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/auth_service.dart';
import 'package:agripulse/roles/auth/login_screen.dart';

/// AppBar logout button shared by every dashboard.
Widget logoutAction(BuildContext context) => IconButton(
      tooltip: "Log out",
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await AuthService.instance.logout();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      },
    );

/// Simple title/body dialog for showing a result or an error.
void showResultDialog(BuildContext context, String title, String body) => showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );

/// Full-screen blocking spinner (e.g. while an ML request runs).
void showLoading(BuildContext context) => showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

/// A bold, green section heading used to group lists inside a dashboard.
class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(title, style: AppTheme.heading(16, weight: FontWeight.w700)),
      );
}

/// Constrains a dashboard page's content to a comfortable reading width and
/// centres it, so pages don't stretch edge-to-edge on wide desktop windows.
class PageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = 980,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// A page title + optional subtitle, rendered as the signature green→lime
/// gradient hero banner at the top of each dashboard page.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const PageHeader(this.title, {this.subtitle, super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppTheme.heading(23, weight: FontWeight.w700, color: Colors.white)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: const TextStyle(
                      color: Colors.white, height: 1.35, fontSize: 13.5)),
            ],
          ],
        ),
      );
}

/// A small, padding-free section heading for use inside [PageBody] content.
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(title, style: AppTheme.heading(16, weight: FontWeight.w700));
}

/// A compact KPI tile (label + big value + icon) for dashboard overviews.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppTheme.primaryGreen;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(height: 12),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.heading(25, weight: FontWeight.w700, color: AppTheme.textDark)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textFaint, fontSize: 13)),
        ],
      ),
    );
  }
}

/// A large, tappable shortcut card used on overview pages to jump to a section.
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;
  const QuickAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppTheme.primaryGreen;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: tint),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTheme.heading(15, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: AppTheme.textFaint, fontSize: 12.5, height: 1.25)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays children out in a responsive grid of [minTileWidth]-wide columns.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final double childAspectRatio;
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 220,
    this.spacing = 12,
    this.childAspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final cols = (c.maxWidth / minTileWidth).floor().clamp(1, 4);
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
            children: children,
          );
        },
      );
}

/// A compact, tappable feature tile for grid-style dashboards (e.g. Farmer).
///
/// Kept small and dense so a whole menu of actions fits near the top of the
/// screen — tap one to open its page. Pass [accent] to tint the icon chip.
class DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  const DashboardTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppTheme.accentGreen;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 24, color: tint),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
