import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';

/// Full-page crop-disease helper for farmers.
///
/// Two ways to get an answer — and you can use both at once:
///   1. **Detect by photo** — the leaf image goes to the trained plant-disease
///      CNN (`/farmer/disease/detect`), which returns the disease, a confidence
///      score and treatment advice.
///   2. **Ask in text** — a free-text question goes to the trained farming
///      chatbot (`/assistant/chat`).
///
/// Results render inline on the same page so the farmer never leaves this view.
class DiseaseScreen extends StatefulWidget {
  const DiseaseScreen({super.key});

  @override
  State<DiseaseScreen> createState() => _DiseaseScreenState();
}

class _DiseaseScreenState extends State<DiseaseScreen> {
  final _api = ApiService.instance;
  final _question = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageName;

  bool _loading = false;
  String? _error;

  // Photo result.
  String? _disease;
  double? _confidence;
  String? _treatment;

  // Text result.
  String? _answer;

  bool get _hasInput => _imageBytes != null || _question.text.trim().isNotEmpty;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name;
    });
  }

  void _removeImage() => setState(() {
        _imageBytes = null;
        _imageName = null;
      });

  Future<void> _analyze() async {
    final question = _question.text.trim();
    if (!_hasInput || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _disease = null;
      _confidence = null;
      _treatment = null;
      _answer = null;
    });

    try {
      // 1) Photo → trained disease model.
      if (_imageBytes != null) {
        final res = await _api.uploadBytes(
          "/farmer/disease/detect",
          "image",
          _imageBytes!,
          filename: _imageName ?? "leaf.jpg",
        );
        _disease = (res["disease_name"] as String?) ?? "Unknown";
        _confidence = (res["confidence"] as num?)?.toDouble();
        _treatment = (res["recommendation"] as String?)?.trim();
      }

      // 2) Text → trained farming chatbot.
      if (question.isNotEmpty) {
        final res = await _api.post("/assistant/chat", {"question": question});
        final answer = (res["answer"] as String?)?.trim();
        _answer = (answer == null || answer.isEmpty)
            ? "Sorry, I couldn't answer that."
            : answer;
      }
    } catch (e) {
      _error = "$e";
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasResult =>
      _disease != null || _answer != null || _error != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
          _intro(),
          const SizedBox(height: 20),
          const _SectionLabel("1", "Photo of the affected crop", Icons.photo_camera_outlined),
          const SizedBox(height: 10),
          _photoCard(),
          const SizedBox(height: 24),
          const _SectionLabel("2", "Describe or ask about the problem", Icons.help_outline),
          const SizedBox(height: 10),
          _questionField(),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: (_hasInput && !_loading) ? _analyze : null,
            icon: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.biotech_outlined),
            label: Text(_loading ? "Analyzing…" : "Analyze"),
          ),
          if (_hasResult) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            _results(),
          ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────── Intro banner ───────────
  Widget _intro() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.eco_outlined, color: AppTheme.primaryGreen),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Upload a photo of the affected leaf, type your question, or do "
                "both. The photo is checked by our trained disease model and your "
                "question is answered by the farming assistant.",
                style: TextStyle(color: AppTheme.textFaint, height: 1.35),
              ),
            ),
          ],
        ),
      );

  // ─────────── Photo picker ───────────
  Widget _photoCard() {
    if (_imageBytes != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_imageBytes!, height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text("Change"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _removeImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text("Remove"),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.add_a_photo_outlined, size: 40, color: AppTheme.lightGreen),
          const SizedBox(height: 12),
          const Text("Add a clear photo of the affected leaf",
              style: TextStyle(color: AppTheme.textFaint)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text("Gallery"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text("Camera"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────── Question field ───────────
  Widget _questionField() => TextField(
        controller: _question,
        minLines: 2,
        maxLines: 5,
        onChanged: (_) => setState(() {}), // refresh Analyze enabled state
        decoration: const InputDecoration(
          hintText: "e.g. My tomato leaves have yellow spots — what should I do?",
        ),
      );

  // ─────────── Results ───────────
  Widget _results() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) _errorCard(_error!),
        if (_disease != null) ...[
          _diagnosisCard(),
          const SizedBox(height: 12),
        ],
        if (_answer != null) _answerCard(_answer!),
      ],
    );
  }

  Widget _diagnosisCard() {
    final pct = ((_confidence ?? 0) * 100);
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
          const Row(
            children: [
              Icon(Icons.local_florist_outlined, color: AppTheme.primaryGreen),
              SizedBox(width: 8),
              Text("Diagnosis",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.darkGreen, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_disease ?? "Unknown",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text("Confidence", style: TextStyle(color: AppTheme.textFaint)),
              const Spacer(),
              Text("${pct.toStringAsFixed(1)}%",
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_confidence ?? 0).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: AppTheme.border,
            ),
          ),
          if (_treatment != null && _treatment!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text("Treatment advice",
                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGreen)),
            const SizedBox(height: 6),
            Text(_treatment!, style: const TextStyle(color: AppTheme.textDark, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _answerCard(String answer) {
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
          const Row(
            children: [
              Icon(Icons.forum_outlined, color: AppTheme.primaryGreen),
              SizedBox(width: 8),
              Text("Assistant answer",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.darkGreen, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(answer, style: const TextStyle(color: AppTheme.textDark, height: 1.4)),
        ],
      ),
    );
  }

  Widget _errorCard(String message) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEDEC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7B5B0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFC0392B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Color(0xFF8C2D24))),
            ),
          ],
        ),
      );
}

/// A numbered, labelled section heading ("1  Photo of the affected crop").
class _SectionLabel extends StatelessWidget {
  final String number;
  final String text;
  final IconData icon;
  const _SectionLabel(this.number, this.text, this.icon);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppTheme.primaryGreen,
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: AppTheme.lightGreen),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.darkGreen, fontSize: 15)),
          ),
        ],
      );
}
