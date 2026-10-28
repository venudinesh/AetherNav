import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences, persisted to [SharedPreferences].
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
    introSeen = _prefs.getBool(_kIntroSeen) ?? false;
    largeText = _prefs.getBool(_kLargeText) ?? false;
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
  static const _kIntroSeen = 'introSeen';
  static const _kLargeText = 'largeText';
  static const _kModelPath = 'modelPath';

  ThemeMode themeMode = ThemeMode.system;
  bool voiceEnabled = true;
  bool hapticsEnabled = true;
  bool liquidGlass = false;

  /// Live GPS location on the map. Off by default.
  bool liveLocation = false;

  /// Keep the map centred on the current position.
  bool followLocation = true;

  /// Opt-in offline voice-assistant LLM. Off by default.
  bool useLocalLlm = false;

  /// Whether the model-download prompt has been shown.
  bool llmPromptSeen = false;

  /// Whether the first-run onboarding card has been dismissed.
  bool introSeen = false;

  /// Scales the app's text up for readability.
  bool largeText = false;

  /// Path to the active GGUF model, or null.
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

  void setIntroSeen(bool value) {
    introSeen = value;
    _prefs.setBool(_kIntroSeen, value);
    notifyListeners();
  }

  void setLargeText(bool value) {
    largeText = value;
    _prefs.setBool(_kLargeText, value);
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
