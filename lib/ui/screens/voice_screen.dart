import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/permissions.dart';
import '../../state/voice_controller.dart';

/// Hands-free voice assistant. Speech recognition and answers run entirely
/// on-device; a text field is always available as a fallback when the mic or
/// recognizer is unavailable.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});
  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle(VoiceController voice) async {
    if (!voice.listening) {
      await AppPermissions.ensureMicrophone();
    }
    await voice.toggleListen();
  }

  void _ask(VoiceController voice, String q) {
    if (q.trim().isEmpty) return;
    _textCtrl.clear();
    FocusScope.of(context).unfocus();
    voice.ask(q);
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceController>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Voice assistant')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _MicButton(
            listening: voice.listening,
            ready: voice.ready,
            onTap: () => _toggle(voice),
          ),
          const SizedBox(height: 20),
          if (!voice.ready) _UnavailableNote(error: voice.error),
          if (voice.heardText.isNotEmpty)
            _Bubble(
                label: 'You asked',
                text: voice.heardText,
                primary: false),
          if (voice.answer != null) ...[
            const SizedBox(height: 12),
            _Bubble(label: 'AetherNav', text: voice.answer!, primary: true),
          ],
          const SizedBox(height: 24),
          Text('Try asking',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in const [
              'Where is Exit 4?',
              'Find the stairs',
              'Where are the exits?',
              'Where are the restrooms?'
            ])
              ActionChip(label: Text(s), onPressed: () => _ask(voice, s)),
          ]),
          const SizedBox(height: 20),
          _AskField(controller: _textCtrl, onSubmit: (q) => _ask(voice, q)),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool listening;
  final bool ready;
  final VoidCallback onTap;
  const _MicButton(
      {required this.listening, required this.ready, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final bg = listening ? scheme.primary : scheme.primaryContainer;
    final fg = listening ? scheme.onPrimary : scheme.onPrimaryContainer;
    return Center(
      child: Column(children: [
        Semantics(
          button: true,
          label: listening ? 'Stop listening' : 'Start listening',
          child: InkWell(
            onTap: ready ? onTap : null,
            customBorder: const CircleBorder(),
            child: Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ready ? bg : scheme.surfaceContainerHighest),
              child: Icon(listening ? Icons.stop : Icons.mic,
                  size: 52,
                  color: ready ? fg : scheme.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          !ready
              ? 'Voice input unavailable'
              : listening
                  ? 'Listening…'
                  : 'Tap to speak',
          style: t.titleMedium,
        ),
      ]),
    );
  }
}

class _UnavailableNote extends StatelessWidget {
  final String? error;
  const _UnavailableNote({this.error});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, color: scheme.onSurfaceVariant, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            error == null
                ? 'Speech recognition is unavailable on this device. You can '
                    'still type a question below.'
                : 'Voice input unavailable: $error. You can type below instead.',
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String label;
  final String text;
  final bool primary;
  const _Bubble(
      {required this.label, required this.text, required this.primary});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final bg = primary ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final fg = primary ? scheme.onPrimaryContainer : scheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: t.labelSmall?.copyWith(
                color: fg.withValues(alpha: 0.7),
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(text, style: t.titleMedium?.copyWith(color: fg)),
      ]),
    );
  }
}

class _AskField extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String value) onSubmit;
  const _AskField({required this.controller, required this.onSubmit});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.send,
      onSubmitted: onSubmit,
      decoration: InputDecoration(
        hintText: 'Type a question',
        prefixIcon: const Icon(Icons.keyboard_outlined),
        suffixIcon: IconButton(
          icon: const Icon(Icons.send),
          tooltip: 'Send',
          onPressed: () => onSubmit(controller.text),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
