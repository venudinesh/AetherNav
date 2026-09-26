import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/hazard_event.dart';
import '../../state/llm_controller.dart';
import '../../state/navigation_controller.dart';
import '../../state/perception_controller.dart';
import '../widgets/status_chip.dart';
import 'local_llm_screen.dart';

/// The dashboard: brand header, a live status summary, and entry points to the
/// four features. Feature rows are a plain vertical list (not a decorative
/// icon-card grid) so each row is a real, tappable destination.
class HomeScreen extends StatelessWidget {
  final void Function(int tabIndex) onNavigate;
  final VoidCallback onOpenSettings;
  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AetherNav Edge'),
        actions: [
          IconButton(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _HomeBody(onNavigate: onNavigate),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final void Function(int tabIndex) onNavigate;
  const _HomeBody({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const _Hero(),
        const SizedBox(height: 20),
        const _LlmDownloadCard(),
        const _LiveStatusCard(),
        const SizedBox(height: 24),
        Text('Features',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        _FeatureTile(
          icon: Icons.center_focus_strong_outlined,
          title: 'Camera perception',
          subtitle: 'Read signs and spot obstacles, fully offline',
          onTap: () => onNavigate(1),
        ),
        _FeatureTile(
          icon: Icons.map_outlined,
          title: 'Live map',
          subtitle: 'Your location on an OpenStreetMap view',
          onTap: () => onNavigate(2),
        ),
        _FeatureTile(
          icon: Icons.route_outlined,
          title: 'Trip',
          subtitle: 'Heading, steps, distance and landmarks',
          onTap: () => onNavigate(3),
        ),
        _FeatureTile(
          icon: Icons.mic_none_outlined,
          title: 'Voice assistant',
          subtitle: 'Ask where things are, hands-free',
          onTap: () => onNavigate(4),
        ),
        const SizedBox(height: 20),
        const _OfflineNote(),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // The single sanctioned decorative gradient: the brand mark.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF0D9488)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.navigation_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Text('AetherNav Edge',
              style: t.titleLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Text(
          'On-device help for reading your surroundings, staying oriented, '
          'and avoiding hazards — plus an optional live map.',
          style: t.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ]),
    );
  }
}

/// A slim Home-screen card that surfaces the offline voice-model download:
/// live progress while it downloads/verifies, then a one-time "ready" note the
/// user dismisses. Hidden (zero height) otherwise, so Home is unchanged when no
/// download is happening. Tapping opens the Offline AI screen.
class _LlmDownloadCard extends StatelessWidget {
  const _LlmDownloadCard();

  void _open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LocalLlmScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final llm = context.watch<LlmController>();
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final downloading = llm.status == LlmStatus.downloading ||
        llm.status == LlmStatus.paused ||
        llm.status == LlmStatus.verifying;
    final ready = llm.showReadyOnHome &&
        (llm.status == LlmStatus.present || llm.status == LlmStatus.ready);

    if (!downloading && !ready) return const SizedBox.shrink();

    final Widget card;
    if (ready) {
      card = Card(
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(children: [
              Icon(Icons.check_circle_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Voice model ready', style: t.titleSmall),
                      Text('Tap to manage it in Offline AI.',
                          style: t.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ]),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Dismiss',
                onPressed: () =>
                    context.read<LlmController>().dismissHomeReady(),
              ),
            ]),
          ),
        ),
      );
    } else {
      final verifying = llm.status == LlmStatus.verifying;
      final paused = llm.status == LlmStatus.paused;
      final pct = (llm.progress.clamp(0, 1) * 100).round();
      final label = verifying
          ? 'Finishing up…'
          : paused
              ? 'Download paused · $pct%'
              : 'Downloading voice model · $pct%';
      card = Card(
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.download_outlined,
                        size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label, style: t.bodyMedium)),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: verifying ? null : llm.progress.clamp(0, 1),
                      minHeight: 6,
                    ),
                  ),
                ]),
          ),
        ),
      );
    }

    // Own the bottom gap so hiding the card doesn't leave a double space.
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: card);
  }
}

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard();
  @override
  Widget build(BuildContext context) {
    final perception = context.watch<PerceptionController>();
    final nav = context.watch<NavigationController>();
    final t = Theme.of(context).textTheme;
    final hz = perception.hazard;
    final tone = switch (hz.level) {
      HazardLevel.none => StatusTone.success,
      HazardLevel.caution => StatusTone.info,
      HazardLevel.warning => StatusTone.warning,
      HazardLevel.danger => StatusTone.danger,
    };
    final cameraOn = perception.status == PerceptionStatus.running;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Live status', style: t.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            StatusChip(
                label: hz.level.display,
                tone: tone,
                icon: Icons.shield_outlined),
            StatusChip(
              label: cameraOn ? 'Camera on' : 'Camera idle',
              tone: cameraOn ? StatusTone.info : StatusTone.neutral,
              icon: Icons.photo_camera_outlined,
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _Metric(
                    label: 'Steps', value: '${nav.snapshot.stepCount}')),
            Expanded(
                child: _Metric(
                    label: 'Distance',
                    value: '${nav.snapshot.distanceMeters.toStringAsFixed(0)} m')),
            Expanded(
                child: _Metric(
                    label: 'Heading', value: nav.snapshot.cardinal)),
          ]),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(label,
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: t.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ])),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Row(children: [
      Icon(Icons.smartphone_rounded, size: 16, color: scheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Perception, orientation and voice run on-device. The map uses GPS '
          'and downloads map tiles when you turn on live location.',
          style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    ]);
  }
}
