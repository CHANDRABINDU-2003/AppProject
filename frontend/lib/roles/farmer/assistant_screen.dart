import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/i18n/app_localizations.dart';
import 'package:agripulse/shared/services/api_service.dart';

/// AI Assistant — a focused Q&A helper with three modes instead of a single
/// generic chatbot: **Farming**, **Disease** and **Fertilizer** questions.
///
/// The selected mode tailors the greeting and input hint, and frames the
/// question sent to the trained FLAN-T5 model so the answer stays on-topic.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

/// The three question domains the assistant supports.
enum AskMode { farming, disease, fertilizer }

class _Message {
  final String text;
  final bool fromUser;
  _Message(this.text, {required this.fromUser});
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _api = ApiService.instance;
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  AskMode _mode = AskMode.farming;
  late List<_Message> _messages = [_greetingFor(_mode)];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ─────────── Mode metadata ───────────
  String _greetKey(AskMode m) => switch (m) {
        AskMode.farming => "assistant.greetFarming",
        AskMode.disease => "assistant.greetDisease",
        AskMode.fertilizer => "assistant.greetFertilizer",
      };

  String _hintKey(AskMode m) => switch (m) {
        AskMode.farming => "assistant.hintFarming",
        AskMode.disease => "assistant.hintDisease",
        AskMode.fertilizer => "assistant.hintFertilizer",
      };

  String _labelKey(AskMode m) => switch (m) {
        AskMode.farming => "assistant.modeFarming",
        AskMode.disease => "assistant.modeDisease",
        AskMode.fertilizer => "assistant.modeFertilizer",
      };

  IconData _iconFor(AskMode m) => switch (m) {
        AskMode.farming => Icons.agriculture,
        AskMode.disease => Icons.coronavirus_outlined,
        AskMode.fertilizer => Icons.science_outlined,
      };

  _Message _greetingFor(AskMode m) => _Message(tr(_greetKey(m)), fromUser: false);

  /// Frames the raw question with a domain instruction so the model answers in
  /// the right context for the selected mode.
  String _framed(String q) => switch (_mode) {
        AskMode.farming => "Answer this farming question: $q",
        AskMode.disease =>
          "Answer this crop disease question, naming the likely disease and a "
              "treatment: $q",
        AskMode.fertilizer =>
          "Answer this fertilizer question, recommending a suitable fertilizer: $q",
      };

  void _switchMode(AskMode m) {
    if (m == _mode) return;
    setState(() {
      _mode = m;
      // Reset the thread so each mode starts focused.
      _messages = [_greetingFor(m)];
    });
  }

  Future<void> _send() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add(_Message(q, fromUser: true));
      _sending = true;
    });
    _scrollToEnd();
    try {
      final res = await _api.post("/assistant/chat", {"question": _framed(q)});
      final answer = (res["answer"] as String?)?.trim();
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(
          answer == null || answer.isEmpty ? "Sorry, I couldn't answer that." : answer,
          fromUser: false,
        ));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages
          .add(_Message("⚠ ${tr("assistant.unavailable")}: $e", fromUser: false)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // No AppBar — the dashboard shell provides the title bar and navigation.
    return Scaffold(
      body: Column(
        children: [
          _modeSelector(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) {
                  return _bubble(_Message("…", fromUser: false), thinking: true);
                }
                return _bubble(_messages[i]);
              },
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  // ─────────── Mode selector ───────────
  Widget _modeSelector() {
    return Container(
      width: double.infinity,
      color: AppTheme.surfaceWhite,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final m in AskMode.values)
            ChoiceChip(
              avatar: Icon(_iconFor(m),
                  size: 18,
                  color: m == _mode ? Colors.white : AppTheme.primaryGreen),
              label: Text(tr(_labelKey(m))),
              selected: m == _mode,
              showCheckmark: false,
              selectedColor: AppTheme.primaryGreen,
              labelStyle: TextStyle(
                color: m == _mode ? Colors.white : AppTheme.textDark,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => _switchMode(m),
            ),
        ],
      ),
    );
  }

  Widget _bubble(_Message m, {bool thinking = false}) {
    final align = m.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = m.fromUser ? AppTheme.primaryGreen : AppTheme.surfaceWhite;
    final textColor = m.fromUser ? Colors.white : AppTheme.textDark;
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: m.fromUser ? null : AppTheme.cardShadow,
        ),
        child: thinking
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
              )
            : Text(m.text, style: TextStyle(color: textColor)),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(hintText: tr(_hintKey(_mode))),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: _sending ? null : _send,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
