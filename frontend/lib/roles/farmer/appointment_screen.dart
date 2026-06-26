import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/i18n/app_localizations.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Consult analyst — the farmer books a consultation with the system analyst by
/// picking a date and describing their problem. Below the form is a list of
/// their existing appointments, each of which can be cancelled.
class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  final _api = ApiService.instance;
  final _problem = TextEditingController();

  List<dynamic> _appointments = const [];
  DateTime _date = DateTime.now().add(const Duration(days: 1));

  bool _loading = true;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _problem.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final mine = await _api.get("/appointments");
      if (!mounted) return;
      setState(() {
        _appointments = mine as List;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showResultDialog(context, tr("common.error"), "$e");
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _book() async {
    if (_problem.text.trim().isEmpty || _booking) return;
    setState(() => _booking = true);
    try {
      await _api.post("/appointments", {
        "scheduled_date": _date.toIso8601String().split("T").first,
        "topic": _problem.text.trim(),
      });
      _problem.clear();
      if (!mounted) return;
      showResultDialog(context, tr("appt.title"), tr("appt.booked"));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      showResultDialog(context, tr("common.error"), "$e");
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await _api.put("/appointments/$id/cancel");
      await _load();
    } catch (e) {
      if (!mounted) return;
      showResultDialog(context, tr("common.error"), "$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // No AppBar — the dashboard shell provides the title bar and navigation.
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PageHeader(tr("appt.title"), subtitle: tr("appt.subtitle")),
                      const SizedBox(height: 20),
                      _bookingForm(),
                      const SizedBox(height: 28),
                      SectionTitle(tr("appt.mine")),
                      const SizedBox(height: 8),
                      if (_appointments.isEmpty)
                        _emptyState()
                      else
                        for (final a in _appointments)
                          _appointmentCard(a as Map<String, dynamic>),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _bookingForm() {
    final dateStr = _date.toIso8601String().split("T").first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: InputDecoration(labelText: tr("appt.selectDate")),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 16, color: AppTheme.lightGreen),
                const SizedBox(width: 8),
                Text(dateStr, style: const TextStyle(color: AppTheme.textDark)),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _problem,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}), // refresh Book enabled state
            decoration: InputDecoration(
              labelText: tr("appt.problem"),
              hintText: tr("appt.problemHint"),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                _booking || _problem.text.trim().isEmpty ? null : _book,
            icon: _booking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.event_available),
            label: Text(tr("appt.book")),
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(Map<String, dynamic> a) {
    final status = "${a["status"]}";
    final active = status == "pending" || status == "confirmed";
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.support_agent, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${tr("appt.with")} ${a["expert_name"]}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
                const SizedBox(height: 2),
                Text(_pretty("${a["scheduled_date"]}"),
                    style: const TextStyle(color: AppTheme.textDark, fontSize: 13)),
                if (a["topic"] != null && "${a["topic"]}".isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text("${a["topic"]}",
                      style: const TextStyle(
                          color: AppTheme.textFaint, fontSize: 12.5, height: 1.25)),
                ],
                const SizedBox(height: 8),
                _statusChip(status),
              ],
            ),
          ),
          if (active)
            TextButton(
              onPressed: () => _cancel(a["id"] as int),
              child: Text(tr("appt.cancel")),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final label = switch (status) {
      "confirmed" => tr("appt.statusConfirmed"),
      "completed" => tr("appt.statusCompleted"),
      "cancelled" => tr("appt.statusCancelled"),
      _ => tr("appt.statusPending"),
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
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(tr("appt.none"),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textFaint, height: 1.3)),
      );

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
