import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-adjustable preferences, persisted to [SharedPreferences] so they survive
/// an app restart. Liquid Glass is an opt-in surface style, OFF by default in
/// favour of opaque Material surfaces (per DESIGN_RULES).
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    themeMode =
        ThemeMode.values[_prefs.getInt(_kThemeMode) ?? ThemeMode.system.index];
    voiceEnabled = _prefs.getBool(_kVoice) ?? true;
    hapticsEnabled = _prefs.getBool(_kHaptics) ?? true;
    liquidGlass = _prefs.getBool(_kLiquidGlass) ?? false;
    liveLocation = _prefs.getBool(_kLiveLocation) ?? false;
    followLocation = _prefs.getBool(_kFollowLocation) ?? true;
    useLocalLlm = _prefs.getBool(_kUseLocalLlm) ?? false;
    llmPromptSeen = _prefs.getBool(_kLlmPromptSeen) ?? false;
    modelPath = _prefs.getString(_kModelPath);
  }

  final SharedPreferences _prefs;

  static const _kThemeMode = 'themeMode';
  static const _kVoice = 'voiceEnabled';
  static const _kHaptics = 'hapticsEnabled';
  static const _kLiquidGlass = 'liquidGlass';
  static const _kLiveLocation = 'liveLocation';
  static const _kFollowLocation = 'followLocation';
  static const _kUseLocalLlm = 'useLocalLlm';
  static const _kLlmPromptSeen = 'llmPromptSeen';
  static const _kModelPath = 'modelPath';

  ThemeMode themeMode = ThemeMode.system;
  bool voiceEnabled = true;
  bool hapticsEnabled = true;
  bool liquidGlass = false;

  /// Live GPS location on the map. OFF by default: the app stays fully
  /// on-device until the user opts in to location + map tiles.
  bool liveLocation = false;

  /// Keep the map centred on the current position as it moves.
  bool followLocation = true;

  /// Opt-in offline voice-assistant LLM. OFF by default: the deterministic
  /// matcher answers unless the user downloads/side-loads a model and enables it.
  bool useLocalLlm = false;

  /// Whether the first-launch "download the model?" prompt has been shown, so it
  /// only appears once.
  bool llmPromptSeen = false;

  /// Filesystem path to the active GGUF model, or null if none is set. Persisted
  /// so an injected model reloads on the next launch.
  String? modelPath;

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  void setVoiceEnabled(bool value) {
    voiceEnabled = value;
    _prefs.setBool(_kVoice, value);
    notifyListeners();
  }

  void setHapticsEnabled(bool value) {
    hapticsEnabled = value;
    _prefs.setBool(_kHaptics, value);
    notifyListeners();
  }

  void setLiquidGlass(bool value) {
    liquidGlass = value;
    _prefs.setBool(_kLiquidGlass, value);
    notifyListeners();
  }

  void setLiveLocation(bool value) {
    liveLocation = value;
    _prefs.setBool(_kLiveLocation, value);
    notifyListeners();
  }

  void setFollowLocation(bool value) {
    followLocation = value;
    _prefs.setBool(_kFollowLocation, value);
    notifyListeners();
  }

  void setUseLocalLlm(bool value) {
    useLocalLlm = value;
    _prefs.setBool(_kUseLocalLlm, value);
    notifyListeners();
  }

  void setLlmPromptSeen(bool value) {
    llmPromptSeen = value;
    _prefs.setBool(_kLlmPromptSeen, value);
    notifyListeners();
  }

  void setModelPath(String? value) {
    modelPath = value;
    if (value == null) {
      _prefs.remove(_kModelPath);
    } else {
      _prefs.setString(_kModelPath, value);
    }
    notifyListeners();
  }
}
