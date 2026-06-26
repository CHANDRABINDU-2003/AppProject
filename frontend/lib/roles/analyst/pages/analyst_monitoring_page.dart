import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Community Monitoring — a strictly read-only oversight view of the community
/// feed. The analyst can see all posts, the ones flagged as urgent problems, the
/// farmer discussions and the trending problems. No editing of posts.
class AnalystMonitoringPage extends StatefulWidget {
  const AnalystMonitoringPage({super.key});

  @override
  State<AnalystMonitoringPage> createState() => _AnalystMonitoringPageState();
}

class _AnalystMonitoringPageState extends State<AnalystMonitoringPage> {
  final _api = ApiService.instance;
  Map<String, dynamic>? _data;
  bool _loading = true;
  Object? _error;
  bool _showFlaggedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get("/analyst/community-monitor");
      if (!mounted) return;
      setState(() {
        _data = res as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [PageBody(child: _body())]),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _data == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PageHeader("Community monitoring",
            subtitle: "Read-only oversight of the community feed."),
        const SizedBox(height: 24),
        Text("$_error", style: const TextStyle(color: AppTheme.textFaint)),
      ]);
    }

    final d = _data!;
    final trending = (d["trending"] as List).cast<Map<String, dynamic>>();
    final allPosts = (d["posts"] as List).cast<Map<String, dynamic>>();
    final flaggedPosts = (d["flagged_posts"] as List).cast<Map<String, dynamic>>();
    final visible = _showFlaggedOnly ? flaggedPosts : allPosts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader("Community monitoring",
            subtitle: "Monitor farmer discussions, reported posts and trends. Read-only."),
        const SizedBox(height: 20),

        ResponsiveGrid(
          minTileWidth: 160,
          childAspectRatio: 1.4,
          children: [
            StatCard(
                icon: Icons.forum,
                label: "Total posts",
                value: "${d["total_posts"] ?? 0}"),
            StatCard(
                icon: Icons.mode_comment_outlined,
                label: "Comments",
                value: "${d["total_comments"] ?? 0}",
                accent: AppTheme.accentGreen),
            StatCard(
                icon: Icons.flag,
                label: "Reported / flagged",
                value: "${d["flagged_count"] ?? 0}",
                accent: AppTheme.danger),
          ],
        ),
        const SizedBox(height: 24),

        // ─── Trending problems ───
        const SectionTitle("Trending problems"),
        const SizedBox(height: 8),
        if (trending.isEmpty)
          const Text("No recurring problems detected.",
              style: TextStyle(color: AppTheme.textFaint))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in trending)
                Chip(
                  avatar: const Icon(Icons.trending_up,
                      size: 16, color: AppTheme.deepAmber),
                  label: Text("${t["keyword"]} · ${t["count"]}"),
                  backgroundColor: AppTheme.softYellow,
                  labelStyle: const TextStyle(color: AppTheme.deepAmber),
                ),
            ],
          ),
        const SizedBox(height: 24),

        // ─── Posts (with reported-only toggle) ───
        Row(
          children: [
            const Expanded(child: SectionTitle("Farmer discussions")), // read-only
            FilterChip(
              label: const Text("Reported only"),
              selected: _showFlaggedOnly,
              onSelected: (v) => setState(() => _showFlaggedOnly = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Text(
              _showFlaggedOnly
                  ? "No reported posts. The community looks healthy."
                  : "No posts yet.",
              style: const TextStyle(color: AppTheme.textFaint))
        else
          for (final p in visible) _postCard(p),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _postCard(Map<String, dynamic> p) {
    final flagged = p["flagged"] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: flagged
            ? const Border(left: BorderSide(color: AppTheme.danger, width: 5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle, color: AppTheme.lightGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text("${p["author_name"] ?? "User"}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
              ),
              if (flagged)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text("Reported",
                      style: TextStyle(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text("${p["text"] ?? ""}",
              style: const TextStyle(color: AppTheme.textDark, height: 1.35)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.favorite, size: 14, color: AppTheme.accentYellow),
            Text(" ${p["likes"] ?? 0}",
                style: const TextStyle(color: AppTheme.textFaint, fontSize: 12)),
            const SizedBox(width: 14),
            const Icon(Icons.mode_comment_outlined,
                size: 14, color: AppTheme.textFaint),
            Text(" ${p["comment_count"] ?? 0}",
                style: const TextStyle(color: AppTheme.textFaint, fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}
