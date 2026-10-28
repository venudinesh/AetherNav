import 'dart:async';

import 'package:llamadart/llamadart.dart';

/// llama.cpp (GGUF) wrapper for the voice assistant. never throws to the
/// caller — any failure returns null and the deterministic matcher answers.
class LlmService {
  LlamaEngine? _engine;
  bool _generating = false;

  bool get isLoaded => _engine?.isReady ?? false;

  /// loads a GGUF model; disposes the previous engine first (loadModel throws
  /// if one is already loaded).
  /// cpu-only: gpuLayers defaults to 999, which crashes on some drivers.
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
      await engine.dispose(); // don't leak the native engine
      rethrow; // caller shows the load-failed state
    }
    _engine = engine;
  }

  /// one-shot generation from a pre-built prompt.
  /// returns null on any failure/timeout/empty so the caller falls back.
  /// sanitises the prompt here: the voice query is embedded in it and goes
  /// straight to the native tokenizer.
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
      // any failure -> deterministic fallback. cancel so a stalled generation
      // stops burning cpu; guard the cancel to keep the never-throw contract.
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

  Future<void> unload() async {
    final engine = _engine;
    _engine = null;
    if (engine != null) await engine.dispose();
  }

  // NUL/control chars crash the native tokenizer; strip them (keep \t \n \r)
  // and cap length.
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
