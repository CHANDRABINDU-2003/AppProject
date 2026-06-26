import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/widgets/common.dart';
import 'package:agripulse/shared/widgets/broadcast_card.dart';

/// Disaster Broadcast Module — the analyst composes early-warning alerts (flood,
/// cyclone, heavy rain, pest/disease outbreak) for a region (or all regions) and
/// manages the live list. Farmers and sellers read these elsewhere in the app.
class AnalystBroadcastsPage extends StatefulWidget {
  const AnalystBroadcastsPage({super.key});

  @override
  State<AnalystBroadcastsPage> createState() => _AnalystBroadcastsPageState();
}

class _AnalystBroadcastsPageState extends State<AnalystBroadcastsPage> {
  final _api = ApiService.instance;

  List<dynamic> _broadcasts = const [];
  List<dynamic> _regions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _regions = await _api.get("/regions");
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _broadcasts = await _api.get("/broadcasts");
    } catch (e) {
      if (mounted) showResultDialog(context, "Error", "$e");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(int id) async {
    try {
      await _api.delete("/broadcasts/$id");
      await _load();
    } catch (e) {
      if (mounted) showResultDialog(context, "Error", "$e");
    }
  }

  Future<void> _compose() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _ComposeBroadcastDialog(regions: _regions),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.campaign),
        label: const Text("New alert"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  PageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PageHeader("Disaster broadcasts",
                            subtitle:
                                "Send early-warning alerts to a region. Farmers and sellers see them instantly."),
                        const SizedBox(height: 20),
                        const SectionTitle("Active alerts"),
                        const SizedBox(height: 8),
                        if (_broadcasts.isEmpty)
                          const Text("No alerts yet — tap “New alert” to broadcast one.",
                              style: TextStyle(color: AppTheme.textFaint))
                        else
                          for (final b in _broadcasts)
                            BroadcastCard(
                              data: b as Map<String, dynamic>,
                              onDelete: () => _delete(b["id"] as int),
                            ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// The compose form, kept as its own stateful dialog so the dropdowns/date hold
/// their selection while the analyst fills it in.
class _ComposeBroadcastDialog extends StatefulWidget {
  final List<dynamic> regions;
  const _ComposeBroadcastDialog({required this.regions});

  @override
  State<_ComposeBroadcastDialog> createState() => _ComposeBroadcastDialogState();
}

class _ComposeBroadcastDialogState extends State<_ComposeBroadcastDialog> {
  final _api = ApiService.instance;
  final _title = TextEditingController();
  final _description = TextEditingController();

  String _category = kBroadcastCategories.first.$1;
  String _severity = "medium";
  int? _regionId; // null = all regions
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await _api.post("/broadcasts", {
        "title": _title.text.trim(),
        "category": _category,
        "description": _description.text.trim(),
        "region_id": _regionId,
        "severity": _severity,
        "event_date": _date.toIso8601String().split("T").first,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showResultDialog(context, "Could not broadcast", "$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _date.toIso8601String().split("T").first;
    return AlertDialog(
      title: const Text("New broadcast"),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: "Alert type"),
                items: [
                  for (final c in kBroadcastCategories)
                    DropdownMenuItem(
                      value: c.$1,
                      child: Row(children: [
                        Icon(c.$3, size: 18, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Text(c.$2),
                      ]),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _regionId,
                decoration: const InputDecoration(labelText: "Affected region"),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text("All regions")),
                  for (final r in widget.regions)
                    DropdownMenuItem<int?>(
                        value: r["id"] as int, child: Text("${r["region_name"]}")),
                ],
                onChanged: (v) => setState(() => _regionId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(labelText: "Severity"),
                items: [
                  for (final s in kSeverities)
                    DropdownMenuItem(
                      value: s,
                      child: Row(children: [
                        Icon(Icons.circle, size: 12, color: broadcastSeverityColor(s)),
                        const SizedBox(width: 8),
                        Text(broadcastSeverityLabel(s)),
                      ]),
                    ),
                ],
                onChanged: (v) => setState(() => _severity = v ?? _severity),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "Date"),
                  child: Row(children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: AppTheme.lightGreen),
                    const SizedBox(width: 8),
                    Text(dateStr, style: const TextStyle(color: AppTheme.textDark)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send),
          label: const Text("Broadcast"),
        ),
      ],
    );
  }
}
