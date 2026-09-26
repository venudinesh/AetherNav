import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/llm_controller.dart';
import '../../state/settings_controller.dart';
import 'local_llm_screen.dart';
import 'logs_screen.dart';

/// User preferences: theme, the opt-in Liquid Glass surface style (off by
/// default), spoken/haptic feedback, live location & map, and the trip log.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          _SectionLabel('Appearance'),
          _AppearanceSection(),
          SizedBox(height: 20),
          _SectionLabel('Feedback'),
          _FeedbackSection(),
          SizedBox(height: 20),
          _SectionLabel('Location & map'),
          _LocationSection(),
          SizedBox(height: 20),
          _SectionLabel('Offline AI'),
          _LocalAiSection(),
          SizedBox(height: 20),
          _SectionLabel('Activity'),
          _ActivitySection(),
          SizedBox(height: 20),
          _SectionLabel('About'),
          _AboutCard(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final read = context.read<SettingsController>();
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Theme', style: t.titleSmall),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto)),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => read.setThemeMode(s.first),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: SwitchListTile.adaptive(
          value: settings.liquidGlass,
          onChanged: read.setLiquidGlass,
          secondary: const Icon(Icons.blur_on),
          title: const Text('Liquid Glass surfaces'),
          subtitle: const Text(
              'Translucent, blurred panels. Off by default — plain surfaces '
              'stay easiest to read.'),
        ),
      ),
    ]);
  }
}

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection();
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final read = context.read<SettingsController>();
    return Card(
      child: Column(children: [
        SwitchListTile.adaptive(
          value: settings.voiceEnabled,
          onChanged: read.setVoiceEnabled,
          secondary: const Icon(Icons.volume_up_outlined),
          title: const Text('Spoken announcements'),
          subtitle: const Text('Read hazards and answers aloud.'),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        SwitchListTile.adaptive(
          value: settings.hapticsEnabled,
          onChanged: read.setHapticsEnabled,
          secondary: const Icon(Icons.vibration),
          title: const Text('Haptic alerts'),
          subtitle: const Text('Vibrate on warnings and dangers.'),
        ),
      ]),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection();
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final read = context.read<SettingsController>();
    return Card(
      child: Column(children: [
        SwitchListTile.adaptive(
          value: settings.liveLocation,
          onChanged: read.setLiveLocation,
          secondary: const Icon(Icons.my_location),
          title: const Text('Live location'),
          subtitle: const Text(
              'Uses GPS and downloads OpenStreetMap tiles — the only feature '
              'that needs network. Off by default.'),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        SwitchListTile.adaptive(
          value: settings.followLocation,
          // Only meaningful while live location is on.
          onChanged: settings.liveLocation ? read.setFollowLocation : null,
          secondary: const Icon(Icons.center_focus_strong_outlined),
          title: const Text('Keep map centred'),
          subtitle: const Text('Recenter the map on each new fix.'),
        ),
      ]),
    );
  }
}

class _LocalAiSection extends StatelessWidget {
  const _LocalAiSection();
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final read = context.read<SettingsController>();
    final llm = context.watch<LlmController>();
    return Card(
      child: Column(children: [
        SwitchListTile.adaptive(
          value: settings.useLocalLlm,
          onChanged: read.setUseLocalLlm,
          secondary: const Icon(Icons.auto_awesome_outlined),
          title: const Text('Offline voice model'),
          subtitle: const Text(
              'An optional on-device model rephrases answers more naturally. '
              'Off by default — the built-in matcher always works without it.'),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.memory),
          title: const Text('Manage model'),
          subtitle: Text(_statusText(llm)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LocalLlmScreen()),
          ),
        ),
      ]),
    );
  }

  String _statusText(LlmController llm) => switch (llm.status) {
        LlmStatus.disabled => 'Turned off',
        LlmStatus.absent => 'No model — download or import one',
        LlmStatus.downloading =>
          'Downloading… ${(llm.progress * 100).round()}%',
        LlmStatus.paused => 'Download paused',
        LlmStatus.verifying => 'Finishing up…',
        LlmStatus.present => 'Ready to load',
        LlmStatus.loading => 'Loading…',
        LlmStatus.ready => 'Loaded and answering',
        LlmStatus.error => llm.error ?? 'Error — tap to retry',
      };
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: const Text('Trip log'),
        subtitle: const Text('Recorded trips, hazards and answers.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LogsScreen()),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.hub_outlined, color: scheme.primary),
            const SizedBox(width: 10),
            Text('AetherNav Edge', style: t.titleMedium),
          ]),
          const SizedBox(height: 10),
          Text(
            'An offline-first mobility aid. Camera perception, navigation and '
            'the voice assistant all run on this device — no account. Only the '
            'optional live map uses GPS and the network.',
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.wifi_off_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Works fully offline unless you turn on the live map',
                  style:
                      t.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ]),
        ]),
      ),
    );
  }
}



