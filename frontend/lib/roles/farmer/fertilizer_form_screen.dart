import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Fertilizer advice form.
///
/// The recommendation is only as good as the inputs, so instead of guessing we
/// let the farmer describe their *actual* field — crop, soil and nutrient
/// levels. These are sent to the AI service which returns a tailored fertilizer.
class FertilizerFormScreen extends StatefulWidget {
  const FertilizerFormScreen({super.key});
  @override
  State<FertilizerFormScreen> createState() => _FertilizerFormScreenState();
}

class _FertilizerFormScreenState extends State<FertilizerFormScreen> {
  final _api = ApiService.instance;
  final _formKey = GlobalKey<FormState>();

  // ── Choices the farmer picks from ──
  String _cropType = "Cotton";
  String _growthStage = "Vegetative";
  String _season = "Kharif";
  String _soilType = "Clay";
  String _region = "South";
  String _irrigation = "Canal";
  String _previousCrop = "Wheat";

  static const _crops = ["Cotton", "Wheat", "Rice", "Maize", "Sugarcane", "Soybean", "Potato"];
  static const _stages = ["Seedling", "Vegetative", "Flowering", "Harvest"];
  static const _seasons = ["Kharif", "Rabi", "Zaid"];
  static const _soils = ["Clay", "Sandy", "Loamy", "Silt", "Black", "Red"];
  static const _regions = ["North", "South", "East", "West", "Central"];
  static const _irrigations = ["Canal", "Drip", "Sprinkler", "Rainfed", "Well"];

  // ── Numeric inputs (pre-filled with typical values the farmer can adjust) ──
  final _pH = TextEditingController(text: "6.5");
  final _nitrogen = TextEditingController(text: "60");
  final _phosphorus = TextEditingController(text: "45");
  final _potassium = TextEditingController(text: "80");
  final _moisture = TextEditingController(text: "35");
  final _temperature = TextEditingController(text: "28");
  final _rainfall = TextEditingController(text: "900");

  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [_pH, _nitrogen, _phosphorus, _potassium, _moisture, _temperature, _rainfall]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim()) ?? fallback;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final res = await _api.post("/farmer/fertilizer/recommend", {
        "Soil_Type": _soilType,
        "Soil_pH": _num(_pH, 6.5),
        "Soil_Moisture": _num(_moisture, 35),
        "Organic_Carbon": 0.4,
        "Electrical_Conductivity": 1.5,
        "Nitrogen_Level": _num(_nitrogen, 60),
        "Phosphorus_Level": _num(_phosphorus, 45),
        "Potassium_Level": _num(_potassium, 80),
        "Temperature": _num(_temperature, 28),
        "Humidity": 70,
        "Rainfall": _num(_rainfall, 900),
        "Crop_Type": _cropType,
        "Crop_Growth_Stage": _growthStage,
        "Season": _season,
        "Irrigation_Type": _irrigation,
        "Previous_Crop": _previousCrop,
        "Region": _region,
        "Fertilizer_Used_Last_Season": 250,
        "Yield_Last_Season": 1.2,
      });
      if (!mounted) return;
      showResultDialog(
        context,
        "Recommended Fertilizer",
        "${res["predicted_fertilizer"]}\n"
            "Confidence: ${((res["confidence"] ?? 0) * 100).toStringAsFixed(1)}%",
      );
    } catch (e) {
      if (mounted) showResultDialog(context, "Error", "$e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _banner(),
            const SizedBox(height: 16),
            const SectionHeader("Your crop"),
            _dropdown("Crop type", _cropType, _crops, (v) => setState(() => _cropType = v!)),
            _dropdown("Growth stage", _growthStage, _stages, (v) => setState(() => _growthStage = v!)),
            _dropdown("Previous crop", _previousCrop, _crops, (v) => setState(() => _previousCrop = v!)),
            _dropdown("Season", _season, _seasons, (v) => setState(() => _season = v!)),
            const SectionHeader("Your field"),
            _dropdown("Soil type", _soilType, _soils, (v) => setState(() => _soilType = v!)),
            _dropdown("Region", _region, _regions, (v) => setState(() => _region = v!)),
            _dropdown("Irrigation", _irrigation, _irrigations, (v) => setState(() => _irrigation = v!)),
            const SectionHeader("Soil readings (adjust to your soil test)"),
            _numField("Soil pH", _pH),
            _numField("Nitrogen (N) level", _nitrogen),
            _numField("Phosphorus (P) level", _phosphorus),
            _numField("Potassium (K) level", _potassium),
            _numField("Soil moisture %", _moisture),
            _numField("Avg temperature °C", _temperature),
            _numField("Annual rainfall (mm)", _rainfall),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.science),
              label: Text(_submitting ? "Analysing…" : "Get recommendation"),
            ),
            const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _banner() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.softYellow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.deepAmber),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Tell us about your field so the advice matches your real "
                "soil and crop — not a generic guess.",
                style: TextStyle(color: AppTheme.textDark),
              ),
            ),
          ],
        ),
      );

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
          onChanged: onChanged,
        ),
      );

  Widget _numField(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return "Required";
            if (double.tryParse(v.trim()) == null) return "Enter a number";
            return null;
          },
        ),
      );
}
