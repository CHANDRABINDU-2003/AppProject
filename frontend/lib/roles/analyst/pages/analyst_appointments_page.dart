import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Appointment Management — the analyst works the consultation queue: see every
/// request and accept, reject or mark it completed. Backed by `/appointments`.
class AnalystAppointmentsPage extends StatefulWidget {
  const AnalystAppointmentsPage({super.key});

  @override
  State<AnalystAppointmentsPage> createState() =>
      _AnalystAppointmentsPageState();
}

class _AnalystAppointmentsPageState extends State<AnalystAppointmentsPage> {
  final _api = ApiService.instance;
  List<dynamic> _appointments = const [];
  bool _loading = true;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _appointments = await _api.get("/appointments/all");
    } catch (e) {
      if (mounted) showResultDialog(context, "Error", "$e");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setStatus(int id, String status) async {
    setState(() => _busyId = id);
    try {
      await _api.put("/appointments/$id/status", {"status": status});
      await _load();
    } catch (e) {
      if (mounted) showResultDialog(context, "Error", "$e");
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  int get _pendingCount =>
      _appointments.where((a) => "${a["status"]}" == "pending").length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        PageHeader("Appointment management",
                            subtitle:
                                "$_pendingCount pending consultation request(s) from farmers and sellers."),
                        const SizedBox(height: 20),
                        if (_appointments.isEmpty)
                          const Text("No consultation requests yet.",
                              style: TextStyle(color: AppTheme.textFaint))
                        else
                          for (final a in _appointments)
                            _card(a as Map<String, dynamic>),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _card(Map<String, dynamic> a) {
    final id = a["id"] as int;
    final status = "${a["status"]}";
    final busy = _busyId == id;
    final isPending = status == "pending";
    final isConfirmed = status == "confirmed";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person_pin_circle_outlined,
                  color: AppTheme.primaryGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                              "${a["requester_name"] ?? a["farmer_name"] ?? "Requester #${a["requester_id"] ?? a["farmer_id"]}"}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkGreen)),
                        ),
                        const SizedBox(width: 8),
                        _roleChip("${a["requester_role"] ?? "farmer"}"),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_pretty("${a["scheduled_date"]}"),
                        style: const TextStyle(
                            color: AppTheme.textDark, fontSize: 13)),
                  ],
                ),
              ),
              _statusChip(status),
            ],
          ),
          if (a["topic"] != null && "${a["topic"]}".isNotEmpty) ...[
            const SizedBox(height: 10),
            Text("${a["topic"]}",
                style: const TextStyle(
                    color: AppTheme.textFaint, fontSize: 13, height: 1.3)),
          ],
          if (isPending || isConfirmed) ...[
            const SizedBox(height: 12),
            if (busy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isPending)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          backgroundColor: AppTheme.primaryGreen),
                      onPressed: () => _setStatus(id, "confirmed"),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Accept"),
                    ),
                  if (isPending)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger)),
                      onPressed: () => _setStatus(id, "cancelled"),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("Reject"),
                    ),
                  if (isConfirmed)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          backgroundColor: AppTheme.accentGreen),
                      onPressed: () => _setStatus(id, "completed"),
                      icon: const Icon(Icons.task_alt, size: 18),
                      label: const Text("Mark completed"),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _roleChip(String role) {
    final isSeller = role == "seller";
    final color = isSeller ? AppTheme.deepAmber : AppTheme.accentGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSeller ? Icons.storefront : Icons.agriculture,
              size: 12, color: color),
          const SizedBox(width: 4),
          Text(isSeller ? "Seller" : "Farmer",
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final label = switch (status) {
      "confirmed" => "Accepted",
      "completed" => "Completed",
      "cancelled" => "Rejected",
      _ => "Pending",
    };
    final color = switch (status) {
      "confirmed" => AppTheme.primaryGreen,
      "completed" => AppTheme.accentGreen,
      "cancelled" => AppTheme.danger,
      _ => AppTheme.deepAmber,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style:
              TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  static String _pretty(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    return "${months[d.month - 1]} ${d.day}, ${d.year}";
  }
}
