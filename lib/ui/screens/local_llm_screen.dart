import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/llm_controller.dart';
import '../../state/settings_controller.dart';

/// Manages the optional offline voice-assistant model: download the recommended
/// Llama-3.2-1B, side-load a `.gguf`, and load/eject it. Reached from Settings →
/// Offline AI. Inference is an enhancement — with no model the deterministic
/// matcher answers, so nothing here is required for the app to work.
class LocalLlmScreen extends StatelessWidget {
  const LocalLlmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final llm = context.watch<LlmController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Offline AI')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _StatusCard(llm: llm),
          if (llm.modelPath != null) ...[
            const SizedBox(height: 12),
            _PathCard(path: llm.modelPath!),
          ],
          const SizedBox(height: 16),
          ..._actions(context, llm),
          const SizedBox(height: 20),
          const _AboutNote(),
        ],
      ),
    );
  }
  /// Actions relevant to the current status. Download/pause/resume/cancel run
  /// the model download; load/eject manage the native engine.
  List<Widget> _actions(BuildContext context, LlmController llm) {
    final read = context.read<LlmController>();
    final hasModel = llm.modelPath != null;
    final out = <Widget>[];

    switch (llm.status) {
      case LlmStatus.disabled:
        out.add(_ActionCard(
          icon: Icons.toggle_on_outlined,
          title: 'Turn on Offline AI',
          subtitle: 'Enable the local voice model.',
          onTap: () => context.read<SettingsController>().setUseLocalLlm(true),
        ));
        return out; // nothing else is actionable while the feature is off
      case LlmStatus.downloading:
        out.add(_ActionCard(
            icon: Icons.pause, title: 'Pause download', onTap: read.pause));
        out.add(_ActionCard(
            icon: Icons.close, title: 'Cancel download', onTap: read.cancel));
        return out;
      case LlmStatus.paused:
        out.add(_ActionCard(
            icon: Icons.play_arrow,
            title: 'Resume download',
            onTap: read.resume));
        out.add(_ActionCard(
            icon: Icons.close, title: 'Cancel download', onTap: read.cancel));
        return out;
      case LlmStatus.verifying:
      case LlmStatus.loading:
        return out; // nothing to do while it settles / loads
      case LlmStatus.present:
        out.add(_ActionCard(
          icon: Icons.play_circle_outline,
          title: 'Load model',
          subtitle: 'Load it into memory to start answering.',
          onTap: read.inject,
        ));
      case LlmStatus.error:
        out.add(_ActionCard(
            icon: Icons.refresh, title: 'Retry', onTap: read.retry));
      case LlmStatus.absent:
      case LlmStatus.ready:
        break;
    }

    if (!hasModel) {
      out.add(_ActionCard(
        icon: Icons.download_outlined,
        title: 'Download recommended model',
        subtitle: 'Llama-3.2-1B-Instruct · ~0.8 GB · one time',
        onTap: read.downloadDefault,
      ));
      out.add(_ActionCard(
        icon: Icons.folder_open_outlined,
        title: 'Import .gguf from storage',
        subtitle: 'Use a model file you already have.',
        onTap: read.importFromStorage,
      ));
    } else {
      out.add(_ActionCard(
        icon: Icons.delete_outline,
        title: 'Eject model',
        subtitle: 'Unload and forget it. The file stays on disk.',
        onTap: read.eject,
      ));
    }
    return out;
  }
}
/// The status header: an icon + title + one-line explanation, with a progress
/// bar while a download runs (determinate) or the file settles / loads
/// (indeterminate). Mirrors the map screen's status banner idiom.
class _StatusCard extends StatelessWidget {
  final LlmController llm;
  const _StatusCard({required this.llm});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final (icon, title, subtitle) = _display(llm);
    final showBar = llm.status == LlmStatus.downloading ||
        llm.status == LlmStatus.paused ||
        llm.status == LlmStatus.verifying ||
        llm.status == LlmStatus.loading;
    final indeterminate =
        llm.status == LlmStatus.verifying || llm.status == LlmStatus.loading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: t.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
            ),
          ]),
          if (showBar) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: indeterminate ? null : llm.progress,
                minHeight: 6,
              ),
            ),
          ],
        ]),
      ),
    );
  }
  (IconData, String, String) _display(LlmController llm) {
    switch (llm.status) {
      case LlmStatus.disabled:
        return (
          Icons.toggle_off_outlined,
          'Offline AI is off',
          'Turn it on to download or load a voice model.'
        );
      case LlmStatus.absent:
        return (
          Icons.help_outline,
          'No model yet',
          'Download the recommended model or import a .gguf file.'
        );
      case LlmStatus.downloading:
        return (
          Icons.downloading_outlined,
          'Downloading model…',
          '${(llm.progress * 100).round()}% · keep using the app while it downloads.'
        );
      case LlmStatus.paused:
        return (
          Icons.pause_circle_outline,
          'Download paused',
          'Resume to finish downloading the model.'
        );
      case LlmStatus.verifying:
        return (
          Icons.hourglass_bottom,
          'Finishing up…',
          'Settling the model file into place.'
        );
      case LlmStatus.present:
        return (
          Icons.inventory_2_outlined,
          'Model ready to load',
          llm.modelName ?? 'A model file is set.'
        );
      case LlmStatus.loading:
        return (
          Icons.memory,
          'Loading model…',
          'Loading into the on-device engine.'
        );
      case LlmStatus.ready:
        return (
          Icons.check_circle_outline,
          'Model loaded',
          '${llm.modelName ?? 'Model'} is answering voice questions.'
        );
      case LlmStatus.error:
        return (
          Icons.error_outline,
          'Something went wrong',
          llm.error ?? 'Please retry.'
        );
    }
  }
}

/// Shows where the active model file lives on disk.
class _PathCard extends StatelessWidget {
  final String path;
  const _PathCard({required this.path});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.folder_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(path,
                style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ]),
      ),
    );
  }
}

/// A tappable action row.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        onTap: onTap,
      ),
    );
  }
}

/// The honest footer: the model only rephrases, never invents, and voice always
/// works without it.
class _AboutNote extends StatelessWidget {
  const _AboutNote();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'The offline model only rephrases facts the app already computes — it '
          'never invents places or directions. If it is unavailable, the '
          'built-in matcher answers instead, so voice always works.',
          style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    ]);
  }
}