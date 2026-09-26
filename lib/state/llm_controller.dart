import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/permissions.dart';
import '../services/llm/llm_service.dart';
import 'settings_controller.dart';

/// Lifecycle of the optional offline model, so the Offline AI screen can show an
/// honest state and the right action instead of a silent dead button.
enum LlmStatus {
  disabled, // feature off — the deterministic matcher answers
  absent, // enabled, but no model downloaded or imported yet
  downloading, // model download in progress
  paused, // download paused by the user
  verifying, // download finished, settling the file into place
  present, // a model file is set but not loaded into memory
  loading, // loading the model into the native engine
  ready, // loaded and answering
  error, // download or load failed
}

/// Owns the optional offline voice-assistant model: the one-time background
/// download (resumable, with an OS progress notification), side-loading a
/// `.gguf` from storage, and injecting/ejecting it into [LlmService].
///
/// Inference stays an enhancement — [generate] returns null unless a model is
/// [LlmStatus.ready], so the deterministic matcher always answers otherwise.
/// The active model path is persisted through [SettingsController] so an
/// injected model reloads on the next launch.
class LlmController extends ChangeNotifier {
  LlmController(this._llm, this._settings) {
    status = _settings.useLocalLlm
        ? (_settings.modelPath != null ? LlmStatus.present : LlmStatus.absent)
        : LlmStatus.disabled;
  }

  final LlmService _llm;
  final SettingsController _settings;

  // Llama-3.2-1B-Instruct Q4_K_M (~0.8 GB). Filename/casing verified on Hugging
  // Face before hardcoding. CPU inference — see LlmService.load.
  static const _kModelUrl =
      'https://huggingface.co/unsloth/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf';
  static const _kModelFilename = 'Llama-3.2-1B-Instruct-Q4_K_M.gguf';
  static const _kModelDir = 'models';
  static const _kTaskId = 'aethernav-llm-model';

  LlmStatus status = LlmStatus.disabled;
  double progress = 0; // 0..1 while downloading
  String? modelName;
  String? error;

  /// True from the moment a download completes until the user dismisses the
  /// "model ready" card on the Home screen. In-memory only — a nicety, not state
  /// worth persisting.
  bool showReadyOnHome = false;

  bool _enabled = false;

  String? get modelPath => _settings.modelPath;

  /// One-time wiring: the OS notification config and the central task-update
  /// listener, then resume any download left running in the background. Call
  /// once after construction, before enabling.
  Future<void> init() async {
    FileDownloader().configureNotification(
      running: const TaskNotification(
          'Downloading voice model', '{filename}  {progress}'),
      complete: const TaskNotification(
          'Voice model ready', 'Open Settings → Offline AI to use it.'),
      error: const TaskNotification(
          'Voice model download failed', 'Open AetherNav to retry.'),
      paused:
          const TaskNotification('Voice model download paused', '{filename}'),
      progressBar: true,
    );
    FileDownloader().updates.listen(_onUpdate);
    await FileDownloader().start(); // track + resume background downloads
  }

  /// Enable/disable the feature. Idempotent (mirrors LocationController): a
  /// re-sent current value is ignored. Enabling loads a set model; disabling
  /// unloads it.
  Future<void> setEnabled(bool on) async {
    if (on == _enabled) return;
    _enabled = on;
    if (!on) {
      await _llm.unload();
      _set(LlmStatus.disabled);
      return;
    }
    if (_settings.modelPath != null) {
      await inject();
    } else {
      _set(LlmStatus.absent);
    }
  }

  /// Start the one-time background download of the recommended model.
  Future<void> downloadDefault() async {
    error = null;
    progress = 0;
    showReadyOnHome = false;
    // Ask for the Android 13+ notification permission so the progress + complete
    // notifications can show. Best-effort — the download proceeds either way.
    await AppPermissions.ensureNotifications();
    _set(LlmStatus.downloading);
    final task = DownloadTask(
      taskId: _kTaskId,
      url: _kModelUrl,
      filename: _kModelFilename,
      directory: _kModelDir,
      baseDirectory: BaseDirectory.applicationSupport,
      updates: Updates.statusAndProgress,
      allowPause: true,
      retries: 3,
    );
    final ok = await FileDownloader().enqueue(task);
    if (!ok) {
      error = 'Could not start the download.';
      _set(LlmStatus.error);
    }
  }
  Future<void> pause() async {
    final t = await FileDownloader().taskForId(_kTaskId);
    if (t is DownloadTask) await FileDownloader().pause(t);
  }

  Future<void> resume() async {
    final t = await FileDownloader().taskForId(_kTaskId);
    if (t is DownloadTask) await FileDownloader().resume(t);
  }

  Future<void> cancel() => FileDownloader().cancelTaskWithId(_kTaskId);

  /// Side-load a `.gguf` the user already has in storage (SAF — no permission).
  Future<void> importFromStorage() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return; // user canceled
    final path = files.first.path;
    if (path == null) {
      error = 'Could not read that file.';
      _set(LlmStatus.error);
      return;
    }
    _settings.setModelPath(path);
    await inject();
  }

  /// Load the set model into the native engine.
  Future<void> inject() async {
    final path = _settings.modelPath;
    if (path == null) {
      _set(_enabled ? LlmStatus.absent : LlmStatus.disabled);
      return;
    }
    if (!await File(path).exists()) {
      error = 'Model file not found. Re-download or re-import it.';
      _set(LlmStatus.error);
      return;
    }
    error = null;
    _set(LlmStatus.loading);
    try {
      await _llm.load(path);
      modelName = path.split(RegExp(r'[\\/]')).last;
      _set(LlmStatus.ready);
    } catch (_) {
      error = 'Could not load the model.';
      _set(LlmStatus.error);
    }
  }

  /// Unload the model and forget the active path (the file is left on disk).
  Future<void> eject() async {
    await _llm.unload();
    _settings.setModelPath(null);
    modelName = null;
    progress = 0;
    _set(_enabled ? LlmStatus.absent : LlmStatus.disabled);
  }

  /// Retry after an error: re-download when no file is set, else re-load.
  Future<void> retry() async {
    if (_settings.modelPath != null) {
      await inject();
    } else {
      await downloadDefault();
    }
  }
  /// Grounded generation for the voice layer. Returns null unless a model is
  /// [LlmStatus.ready], so the deterministic matcher always answers otherwise.
  Future<String?> generate(String prompt) {
    if (status != LlmStatus.ready) return Future.value(null);
    return _llm.generate(prompt);
  }

  /// Central task-update listener (one per app). Filters to our model task and
  /// maps download lifecycle → [LlmStatus] + [progress].
  void _onUpdate(TaskUpdate update) {
    if (update.task.taskId != _kTaskId) return;
    if (update is TaskStatusUpdate) {
      switch (update.status) {
        case TaskStatus.enqueued:
        case TaskStatus.running:
        case TaskStatus.waitingToRetry:
          _set(LlmStatus.downloading);
        case TaskStatus.paused:
          _set(LlmStatus.paused);
        case TaskStatus.complete:
          _onComplete(update.task);
        case TaskStatus.canceled:
          progress = 0;
          _set(_settings.modelPath != null
              ? LlmStatus.present
              : LlmStatus.absent);
        case TaskStatus.failed:
        case TaskStatus.notFound:
          error = update.exception?.description ?? 'Download failed.';
          _set(LlmStatus.error);
      }
    } else if (update is TaskProgressUpdate) {
      if (update.progress >= 0 && update.progress <= 1) {
        progress = update.progress;
        notifyListeners();
      }
    }
  }

  /// Download finished: settle the file into place, persist its path, and load
  /// it if the feature is enabled (else leave it [present] for later).
  Future<void> _onComplete(Task task) async {
    progress = 1;
    showReadyOnHome = true; // surface the "model ready" card on Home
    _set(LlmStatus.verifying);
    final path = await task.filePath();
    _settings.setModelPath(path);
    if (_enabled) {
      await inject();
    } else {
      modelName = _kModelFilename;
      _set(LlmStatus.present);
    }
  }

  /// Dismiss the Home "model ready" card once the user has seen it.
  void dismissHomeReady() {
    showReadyOnHome = false;
    notifyListeners();
  }

  void _set(LlmStatus s) {
    status = s;
    notifyListeners();
  }
}
