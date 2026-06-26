import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/i18n/app_localizations.dart';
import 'package:agripulse/shared/services/auth_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// One navigable section of a role dashboard: a label, a pair of icons and the
/// page widget shown when it is selected.
///
/// Pass [labelKey] (an i18n key) to have the label translated; otherwise the
/// raw [label] is shown as-is.
class ShellDestination {
  final String label;
  final String? labelKey;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const ShellDestination({
    required this.label,
    this.labelKey,
    required this.icon,
    IconData? selectedIcon,
    required this.page,
  }) : selectedIcon = selectedIcon ?? icon;

  /// The label to display — translated when a [labelKey] was provided.
  String get displayLabel => labelKey != null ? tr(labelKey!) : label;
}

/// A responsive, multi-page dashboard shell shared by every role.
///
/// This replaces the old "flash-card" home (a grid of tiles that pushed throw-
/// away routes). Instead each role gets one persistent shell:
///
///   • wide screens (web / desktop / tablet) → a left [NavigationRail] that
///     extends to a labelled sidebar on very wide windows;
///   • narrow screens (phones) → a bottom [NavigationBar].
///
/// The selected page is kept alive in an [IndexedStack], so switching sections
/// preserves scroll position and in-progress input. Pages can jump to a sibling
/// section with `RoleShell.of(context)!.goTo(index)`.
class RoleShell extends StatefulWidget {
  /// Human label for the role, e.g. "Farmer" — shown in the app bar/header.
  final String roleTitle;
  final List<ShellDestination> destinations;

  const RoleShell({
    super.key,
    required this.roleTitle,
    required this.destinations,
  });

  /// Lets a page switch the active section (e.g. an overview "shortcut").
  static RoleShellController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RoleShellScope>()?.controller;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

/// Minimal controller surface exposed to descendant pages.
abstract class RoleShellController {
  int get selectedIndex;
  void goTo(int index);
}

class _RoleShellState extends State<RoleShell> implements RoleShellController {
  int _index = 0;

  static const double _railBreakpoint = 820;   // rail ↔ bottom nav
  static const double _extendedBreakpoint = 1180; // rail ↔ labelled sidebar

  @override
  int get selectedIndex => _index;

  @override
  void goTo(int index) {
    if (index >= 0 && index < widget.destinations.length) {
      setState(() => _index = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _index,
      children: [for (final d in widget.destinations) d.page],
    );

    // When the user is on a sub-section, the system / browser "back" gesture
    // should return to the Home dashboard instead of leaving the app. Only
    // allow a real pop when already on Home (index 0).
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) goTo(0);
      },
      child: _RoleShellScope(
        controller: this,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _railBreakpoint;
            final extended = constraints.maxWidth >= _extendedBreakpoint;

            if (wide) {
              return Scaffold(
                appBar: _appBar(context, showMenuIcon: false),
                body: Row(
                  children: [
                    _rail(extended: extended),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: pages),
                  ],
                ),
              );
            }

            return Scaffold(
              appBar: _appBar(context, showMenuIcon: false),
              body: pages,
              bottomNavigationBar: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: goTo,
                destinations: [
                  for (final d in widget.destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.displayLabel,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, {required bool showMenuIcon}) {
    final user = AuthService.instance.currentUser;
    final section = widget.destinations[_index].displayLabel;
    final onHome = _index == 0;
    return AppBar(
      // Off the dashboard, show a back arrow that always returns to Home — so
      // the user is never stranded on a sub-page with no way back.
      automaticallyImplyLeading: false,
      leading: onHome
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: "Back to dashboard",
              onPressed: () => goTo(0),
            ),
      titleSpacing: onHome ? 16 : 4,
      title: Row(
        children: [
          const Icon(Icons.eco, color: AppTheme.primaryGreen),
          const SizedBox(width: 8),
          const Text("AgriPulse",
              style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.darkGreen)),
          const SizedBox(width: 10),
          Container(width: 1, height: 18, color: AppTheme.border),
          const SizedBox(width: 10),
          Flexible(
            child: Text(section,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.textFaint, fontSize: 15)),
          ),
        ],
      ),
      actions: [
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(user.name,
                  style: const TextStyle(color: AppTheme.textFaint, fontSize: 13)),
            ),
          ),
        logoutAction(context),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _rail({required bool extended}) {
    final user = AuthService.instance.currentUser;
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 188,
      selectedIndex: _index,
      onDestinationSelected: goTo,
      backgroundColor: AppTheme.surfaceWhite,
      groupAlignment: -0.9,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
              child: const Icon(Icons.account_circle, color: AppTheme.primaryGreen),
            ),
            if (extended) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 150,
                child: Column(
                  children: [
                    Text(user?.name ?? "User",
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
                    Text(widget.roleTitle,
                        style: const TextStyle(color: AppTheme.textFaint, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      destinations: [
        for (final d in widget.destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.displayLabel),
          ),
      ],
    );
  }
}

class _RoleShellScope extends InheritedWidget {
  final RoleShellController controller;
  const _RoleShellScope({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_RoleShellScope oldWidget) =>
      controller.selectedIndex != oldWidget.controller.selectedIndex;
}
