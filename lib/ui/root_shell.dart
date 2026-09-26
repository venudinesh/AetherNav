import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/llm_controller.dart';
import '../state/settings_controller.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/perception_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/trip_screen.dart';
import 'screens/voice_screen.dart';

/// The app frame: a bottom [NavigationBar] over a body that is swapped (not
/// stacked) so leaving the camera tab disposes [PerceptionScreen] and releases
/// the camera. When Liquid Glass is enabled the bar becomes a translucent,
/// blurred surface; otherwise it stays opaque for maximum legibility.
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // First launch only: offer the one-time offline-model download. Gated on a
    // persisted flag so it never nags. Post-frame so the dialog has a Navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<SettingsController>();
      if (!settings.llmPromptSeen) _offerModelDownload(settings);
    });
  }

  Future<void> _offerModelDownload(SettingsController settings) async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download the offline voice model?'),
        content: const Text(
            'A one-time ~0.8 GB download lets the voice assistant answer more '
            'naturally, fully offline. It downloads in the background — you can '
            'keep using the app. You can also do this later in Settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Download in background')),
        ],
      ),
    );
    settings.setLlmPromptSeen(true); // shown once, whatever the answer
    if (choice == true && mounted) {
      settings.setUseLocalLlm(true);
      await context.read<LlmController>().downloadDefault();
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Widget _screenFor(int i) {
    switch (i) {
      case 1:
        return const PerceptionScreen();
      case 2:
        return const MapScreen();
      case 3:
        return const TripScreen();
      case 4:
        return const VoiceScreen();
      default:
        return HomeScreen(
          onNavigate: (tab) => setState(() => _index = tab),
          onOpenSettings: _openSettings,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.watch<SettingsController>().liquidGlass;
    return Scaffold(
      body: _screenFor(_index),
      bottomNavigationBar: glass ? _glassBar(context) : _bar(context),
    );
  }

  NavigationBar _bar(BuildContext context, {Color? backgroundColor}) {
    return NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      backgroundColor: backgroundColor,
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home'),
        NavigationDestination(
            icon: Icon(Icons.center_focus_strong_outlined),
            selectedIcon: Icon(Icons.center_focus_strong),
            label: 'Camera'),
        NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map'),
        NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Trip'),
        NavigationDestination(
            icon: Icon(Icons.mic_none_outlined),
            selectedIcon: Icon(Icons.mic),
            label: 'Voice'),
      ],
    );
  }

  Widget _glassBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: _bar(context,
            backgroundColor: scheme.surfaceContainer.withValues(alpha: 0.72)),
      ),
    );
  }
}

