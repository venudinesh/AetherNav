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

/// Root widget. Publishes the already-constructed controllers to the tree via
/// [provider] and drives light/dark theming from [SettingsController]. All
/// controllers are built and wired in `main()` so cross-controller callbacks
/// (hazards → haptics/voice/log, etc.) live in one place, not inside the app.
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
          home: const RootShell(),
        ),
      ),
    );
  }
}
