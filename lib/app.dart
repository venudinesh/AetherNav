import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/location_controller.dart';
import 'state/llm_controller.dart';
import 'state/log_controller.dart';
import 'state/navigation_controller.dart';
import 'state/perception_controller.dart';
import 'state/settings_controller.dart';
import 'state/trips_controller.dart';
import 'state/voice_controller.dart';
import 'theme/app_theme.dart';
import 'ui/root_shell.dart';

/// Root widget. Publishes the controllers built in main() to the tree and
/// drives light/dark theming from [SettingsController].
class AetherNavApp extends StatelessWidget {
  final SettingsController settings;
  final PerceptionController perception;
  final NavigationController navigation;
  final VoiceController voice;
  final LogController log;
  final LocationController location;
  final LlmController llm;
  final TripsController trips;

  const AetherNavApp({
    super.key,
    required this.settings,
    required this.perception,
    required this.navigation,
    required this.voice,
    required this.log,
    required this.location,
    required this.llm,
    required this.trips,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: perception),
        ChangeNotifierProvider.value(value: navigation),
        ChangeNotifierProvider.value(value: voice),
        ChangeNotifierProvider.value(value: log),
        ChangeNotifierProvider.value(value: location),
        ChangeNotifierProvider.value(value: llm),
        ChangeNotifierProvider.value(value: trips),
      ],
      child: Consumer<SettingsController>(
        builder: (context, s, _) => MaterialApp(
          title: 'AetherNav Edge',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: s.themeMode,
          // Large text multiplies the platform scale (so we honour the OS
          // setting too, then bump it) rather than pinning a fixed size.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final base = mq.textScaler.scale(14) / 14;
            final factor =
                (s.largeText ? base * 1.3 : base).clamp(0.5, 3.4).toDouble();
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(factor)),
              child: child!,
            );
          },
          home: const RootShell(),
        ),
      ),
    );
  }
}
