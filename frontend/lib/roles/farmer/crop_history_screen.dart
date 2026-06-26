import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';

/// Full-screen "My Crop History".
///
/// Replaces the old half-height bottom sheet (which opened low on the screen
/// and looked empty). Shows every crop the farmer has logged — with quantity,
/// price and date — and lets them add a new entry, which is also appended to
/// their dataset on the backend.
class CropHistoryScreen extends StatefulWidget {
  const CropHistoryScreen({super.key});
  @override
  State<CropHistoryScreen> createState() => _CropHistoryScreenState();
}

class _CropHistoryScreenState extends State<CropHistoryScreen> {
  final _api = ApiService.instance;
  List<dynamic> _rows = [];
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
      final rows = await _api.get("/farmer/crop-history");
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  Future<void> _addCrop() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // so the sheet rises above the keyboard
      builder: (_) => const _AddCropForm(),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCrop,
        icon: const Icon(Icons.add),
        label: const Text("Add crop"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _rows.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(onRefresh: _load, child: _list()),
    );
  }

  Widget _list() => ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _cropCard(_rows[i] as Map),
      );

  Widget _cropCard(Map r) {
    final details = <String>[
      if (r["quantity"] != null) "Qty: ${r["quantity"]}",
      if (r["price"] != null) "Price: ৳${r["price"]}",
      if (r["yield_amount"] != null) "Yield: ${r["yield_amount"]}",
      if (r["fertilizer_used"] != null && "${r["fertilizer_used"]}".isNotEmpty)
        "Fertilizer: ${r["fertilizer_used"]}",
    ];
    final date = r["crop_date"];
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.cardGreen,
          child: Icon(Icons.eco, color: AppTheme.lightGreen),
        ),
        title: Text("${r["crop_type"]} • ${r["season"]}",
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(details.join("  •  "),
                    style: const TextStyle(color: AppTheme.textFaint)),
              ),
            if (date != null && "$date".isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text("Date: $date",
                    style: const TextStyle(color: AppTheme.textFaint, fontSize: 12)),
              ),
          ],
        ),
        isThreeLine: details.isNotEmpty && date != null,
      ),
    );
  }

  Widget _emptyView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.grass, size: 56, color: AppTheme.accentGreen),
              const SizedBox(height: 12),
              const Text("No crops logged yet",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                "Tap “Add crop” to record a crop with its quantity, price and "
                "date. Each entry is saved to your dataset.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textFaint),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _addCrop,
                icon: const Icon(Icons.add),
                label: const Text("Add your first crop"),
              ),
            ],
          ),
        ),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppTheme.accentYellow),
              const SizedBox(height: 12),
              Text("Couldn't load crop history.\n$_error",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textFaint)),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry")),
            ],
          ),
        ),
      );
}

/// Bottom-sheet form to log a new crop (crop, season, quantity, price, date).
class _AddCropForm extends StatefulWidget {
  const _AddCropForm();
  @override
  State<_AddCropForm> createState() => _AddCropFormState();
}

class _AddCropFormState extends State<_AddCropForm> {
  final _crop = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _yield = TextEditingController();
  final _fertilizerOther = TextEditingController();
  String _season = "Kharif";
  String? _fertilizer; // selected from the dropdown (null = none)
  DateTime? _date;
  bool _saving = false;
  String? _error;

  // Common fertilizers — kept as a fixed list so the "Fertilizer usage" chart
  // groups entries under consistent category labels. "Other" reveals a text box.
  static const _fertilizers = <String>[
    "Urea", "DAP", "TSP", "MOP", "NPK", "Gypsum",
    "Zinc Sulphate", "Compost", "Vermicompost", "Organic", "Other",
  ];

  @override
  void dispose() {
    _crop.dispose();
    _quantity.dispose();
    _price.dispose();
    _yield.dispose();
    _fertilizerOther.dispose();
    super.dispose();
  }

  /// The fertilizer value to save: the dropdown choice, or the custom text when
  /// "Other" is selected. Null when nothing was chosen.
  String? _fertilizerValue() {
    if (_fertilizer == null) return null;
    if (_fertilizer == "Other") {
      final custom = _fertilizerOther.text.trim();
      return custom.isEmpty ? null : custom;
    }
    return _fertilizer;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _isoDate() => _date == null
      ? null
      : "${_date!.year.toString().padLeft(4, '0')}-"
          "${_date!.month.toString().padLeft(2, '0')}-"
          "${_date!.day.toString().padLeft(2, '0')}";

  Future<void> _save() async {
    if (_crop.text.trim().isEmpty) {
      setState(() => _error = "Crop name is required.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.instance.post("/farmer/crop-history", {
        "crop_type": _crop.text.trim(),
        "season": _season,
        "quantity": double.tryParse(_quantity.text.trim()),
        "price": double.tryParse(_price.text.trim()),
        "yield_amount": double.tryParse(_yield.text.trim()),
        "fertilizer_used": _fertilizerValue(),
        "crop_date": _isoDate(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = "$e";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add a crop",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _crop,
              decoration: const InputDecoration(labelText: "Crop name *"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _season,
              decoration: const InputDecoration(labelText: "Season"),
              items: const [
                DropdownMenuItem(value: "Kharif", child: Text("Kharif")),
                DropdownMenuItem(value: "Rabi", child: Text("Rabi")),
                DropdownMenuItem(value: "Zaid", child: Text("Zaid")),
              ],
              onChanged: (v) => setState(() => _season = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Quantity"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Price (৳)"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: "Date"),
                child: Text(
                  _isoDate() ?? "Select a date",
                  style: TextStyle(
                    color: _date == null ? AppTheme.textFaint : AppTheme.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _yield,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Yield",
                helperText: "Amount harvested — powers the yield chart.",
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fertilizer,
              isExpanded: true,
              decoration: const InputDecoration(labelText: "Fertilizer used"),
              hint: const Text("Select a fertilizer"),
              items: _fertilizers
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => _fertilizer = v),
            ),
            if (_fertilizer == "Other") ...[
              const SizedBox(height: 12),
              TextField(
                controller: _fertilizerOther,
                decoration: const InputDecoration(labelText: "Fertilizer name"),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Save crop"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
