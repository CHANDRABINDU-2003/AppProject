import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';

/// Shared presentation + data helpers for disaster broadcasts, so the analyst,
/// seller and farmer screens all render alerts identically.

/// Severity → colour used for the badge and the card's left accent bar.
Color broadcastSeverityColor(String severity) => switch (severity) {
      "critical" => AppTheme.danger,
      "high" => AppTheme.deepAmber,
      "low" => AppTheme.accentGreen,
      _ => AppTheme.warning, // medium
    };

String broadcastSeverityLabel(String severity) => switch (severity) {
      "critical" => "Critical",
      "high" => "High",
      "low" => "Low",
      _ => "Medium",
    };

/// Disaster category → icon + human label.
IconData broadcastCategoryIcon(String category) => switch (category) {
      "flood" => Icons.water,
      "cyclone" => Icons.cyclone,
      "heavy_rain" => Icons.thunderstorm,
      "pest_outbreak" => Icons.pest_control,
      "disease_outbreak" => Icons.coronavirus,
      _ => Icons.warning_amber,
    };

String broadcastCategoryLabel(String category) => switch (category) {
      "flood" => "Flood Alert",
      "cyclone" => "Cyclone Alert",
      "heavy_rain" => "Heavy Rain Alert",
      "pest_outbreak" => "Pest Outbreak Alert",
      "disease_outbreak" => "Disease Outbreak Alert",
      _ => "Alert",
    };

/// The five disaster types the analyst can broadcast — (value, label, icon).
const List<(String, String, IconData)> kBroadcastCategories = [
  ("flood", "Flood Alert", Icons.water),
  ("cyclone", "Cyclone Alert", Icons.cyclone),
  ("heavy_rain", "Heavy Rain Alert", Icons.thunderstorm),
  ("pest_outbreak", "Pest Outbreak Alert", Icons.pest_control),
  ("disease_outbreak", "Disease Outbreak Alert", Icons.coronavirus),
];

const List<String> kSeverities = ["low", "medium", "high", "critical"];

/// A single broadcast rendered as a card. Pass [onDelete] (analyst only) to show
/// a withdraw button.
class BroadcastCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onDelete;
  const BroadcastCard({super.key, required this.data, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final severity = "${data["severity"] ?? "medium"}";
    final category = "${data["category"] ?? ""}";
    final color = broadcastSeverityColor(severity);
    final region = data["region_name"] as String?;
    final eventDate = data["event_date"] as String?;
    final desc = data["description"] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(broadcastCategoryIcon(category), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${data["title"] ?? ""}",
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkGreen,
                              fontSize: 15)),
                      Text(broadcastCategoryLabel(category),
                          style: const TextStyle(
                              color: AppTheme.textFaint, fontSize: 12)),
                    ],
                  ),
                ),
                _severityBadge(severity, color),
                if (onDelete != null)
                  IconButton(
                    tooltip: "Withdraw alert",
                    icon: const Icon(Icons.delete_outline, color: AppTheme.textFaint),
                    onPressed: onDelete,
                  ),
              ],
            ),
            if (desc != null && desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(desc,
                  style: const TextStyle(
                      color: AppTheme.textDark, fontSize: 13, height: 1.35)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _meta(Icons.location_on_outlined, region ?? "All regions"),
                if (eventDate != null && eventDate.isNotEmpty)
                  _meta(Icons.event_outlined, eventDate),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _severityBadge(String severity, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(broadcastSeverityLabel(severity),
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      );

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textFaint),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(color: AppTheme.textFaint, fontSize: 12)),
        ],
      );
}

/// A self-loading list of broadcasts (read-only) for farmers and sellers.
/// Fetches `/broadcasts` and renders a [BroadcastCard] for each.
class BroadcastsView extends StatefulWidget {
  /// Optional empty-state hint shown when there are no active alerts.
  final String emptyText;
  const BroadcastsView({
    super.key,
    this.emptyText = "No active alerts right now. You're all clear.",
  });

  @override
  State<BroadcastsView> createState() => _BroadcastsViewState();
}

class _BroadcastsViewState extends State<BroadcastsView> {
  final _api = ApiService.instance;
  List<dynamic> _broadcasts = const [];
  bool _loading = true;
  Object? _error;

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
      final res = await _api.get("/broadcasts");
      if (!mounted) return;
      setState(() {
        _broadcasts = res as List;
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
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Text("Couldn't load alerts: $_error",
          style: const TextStyle(color: AppTheme.textFaint));
    }
    if (_broadcasts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.softYellow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accentYellow.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          const Icon(Icons.shield_outlined, color: AppTheme.deepAmber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.emptyText,
                style: const TextStyle(color: AppTheme.textDark, height: 1.3)),
          ),
        ]),
      );
    }
    return Column(
      children: [
        for (final b in _broadcasts)
          BroadcastCard(data: b as Map<String, dynamic>),
      ],
    );
  }
}
