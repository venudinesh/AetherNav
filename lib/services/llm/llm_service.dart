import 'dart:async';

import 'package:llamadart/llamadart.dart';

/// Thin wrapper over llamadart (llama.cpp / GGUF) for the offline voice
/// assistant. One model, one context; the caller serialises requests.
///
/// Inference is an *enhancement*, never a hard dependency: every failure path
/// returns null so the deterministic voice matcher answers instead. This class
/// never throws to its caller.
class LlmService {
  LlamaEngine? _engine;
  bool _generating = false;

  bool get isLoaded => _engine?.isReady ?? false;

  /// Load a GGUF model from a filesystem [path]. Disposes any previous engine
  /// first — llamadart's [LlamaEngine.loadModel] throws if a model is already
  /// loaded.
  ///
  /// CPU-only: llamadart's [ModelParams.gpuLayers] defaults to 999 (offload
  /// everything to the GPU), which crashes on devices with a driver llama.cpp
  /// dislikes, so 0 is passed explicitly — reliable on every device.
  Future<void> load(String path, {int contextSize = 2048}) async {
    await unload();
    final engine = LlamaEngine(LlamaBackend());
    try {
      await engine.setLogLevel(LlamaLogLevel.warn);
      await engine.loadModel(
        path,
        modelParams: ModelParams(gpuLayers: 0, contextSize: contextSize),
      );
    } catch (_) {
      await engine.dispose(); // don't leak the native engine on a failed load
      rethrow; // inject() catches this and shows the load-failed state
    }
    _engine = engine;
  }

  /// One-shot grounded generation. [prompt] is the fully-built grounded prompt
  /// (rules + facts + question) from the voice layer.
  ///
  /// Returns the model's answer, or null on any failure / timeout / empty
  /// output / not-loaded / busy — the caller then falls back to the
  /// deterministic matcher. [prompt] is sanitised here (NUL/control strip +
  /// length cap): the trust boundary before external text (the recognised
  /// voice query is embedded in it) reaches the native tokenizer.
  Future<String?> generate(
    String prompt, {
    Duration timeout = const Duration(seconds: 20),
    int maxTokens = 160,
    double temp = 0.3,
    double topP = 0.9,
  }) async {
    final engine = _engine;
    if (engine == null || !engine.isReady || _generating) return null;
    final clean = _sanitize(prompt);
    if (clean.isEmpty) return null;

    _generating = true;
    final buffer = StringBuffer();
    try {
      final stream = engine.create(
        [LlamaChatMessage.fromText(role: LlamaChatRole.user, text: clean)],
        params: GenerationParams(maxTokens: maxTokens, temp: temp, topP: topP),
      );
      await for (final chunk in stream.timeout(timeout)) {
        if (chunk.choices.isEmpty) continue; // keepalive chunk
        final text = chunk.choices.first.delta.content;
        if (text != null) buffer.write(text);
      }
    } catch (_) {
      // LlamaException family, TimeoutException, anything: the deterministic
      // fallback handles it. Cancel so a stalled/timed-out generation stops
      // burning CPU in the background — guarded so a throwing cancel can't
      // break this method's "never throw to the caller" contract.
      try {
        engine.cancelGeneration();
      } catch (_) {}
      return null;
    } finally {
      _generating = false;
    }
    final out = buffer.toString().trim();
    return out.isEmpty ? null : out;
  }

  /// Free the model + native context. Safe to call when nothing is loaded.
  Future<void> unload() async {
    final engine = _engine;
    _engine = null;
    if (engine != null) await engine.dispose();
  }

  // Real-world text (voice recognition output, junk) can carry NUL bytes and
  // control chars that crash the native tokenizer, and unbounded length. Strip
  // and cap before anything reaches llama.cpp. Keeps \t \n \r.
  static const int _maxPromptChars = 8192;

  static String _sanitize(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    var count = 0;
    for (var i = 0; i < input.length && count < _maxPromptChars; i++) {
      final code = input.codeUnitAt(i);
      final bad = code == 0 ||
          code < 9 ||
          (code > 10 && code < 32 && code != 13) ||
          code == 127;
      if (bad) continue;
      buffer.writeCharCode(code);
      count++;
    }
    return buffer.toString().trim();
  }
}
