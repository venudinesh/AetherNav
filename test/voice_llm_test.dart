// Offline LLM voice seam. buildPrompt is pure and must carry the facts, the
// grounding rules (use only the facts, never invent) and the question.
// VoiceController must fall back to the deterministic matcher whenever the LLM
// callback returns null, empty or throws: inference is optional, never required.

import 'package:flutter_test/flutter_test.dart';

import 'package:aethernav_edge/data/models/landmark.dart';
import 'package:aethernav_edge/services/voice/speech_service.dart';
import 'package:aethernav_edge/services/voice/tts_service.dart';
import 'package:aethernav_edge/services/voice/voice_interaction.dart';
import 'package:aethernav_edge/state/voice_controller.dart';

const _map = DemoMap(area: 'Test area', landmarks: [
  Landmark(
      id: 'e4',
      name: 'Exit 4',
      kind: 'exit',
      bearing: 0,
      distanceMeters: 12,
      note: 'By the ramp'),
  Landmark(
      id: 'st', name: 'Stairs', kind: 'stairs', bearing: 90, distanceMeters: 30),
]);

/// Doubles that touch no plugin or platform channel.
class _FakeSpeech extends SpeechService {
  @override
  Future<bool> init() async => true;
}

class _FakeTts extends TtsService {
  final spoken = <String>[];
  @override
  Future<void> init() async {}
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceInteraction.buildPrompt', () {
    test('carries the grounding rules, every fact, and the question', () {
      final prompt = VoiceInteraction(_map).buildPrompt('where is exit 4', 0);
      expect(prompt, contains('use ONLY the FACTS'));
      expect(prompt, contains('never invent'));
      expect(prompt, contains('area: Test area'));
      expect(prompt, contains('Exit 4'));
      expect(prompt, contains('By the ramp'));
      expect(prompt, contains('Stairs'));
      expect(prompt, contains('QUESTION: where is exit 4'));
    });
  });

  group('VoiceController LLM fallback', () {
    late VoiceController voice;
    late String deterministic;

    setUp(() async {
      voice = VoiceController(speech: _FakeSpeech(), tts: _FakeTts());
      await voice.init(_map);
      deterministic =
          VoiceInteraction(_map).answer('where is exit 4', heading: 0).spoken;
    });

    test('uses the deterministic answer when the LLM returns null', () async {
      voice.llmGenerate = (_) async => null;
      await voice.ask('where is exit 4');
      expect(voice.answer, deterministic);
    });

    test('uses the deterministic answer when the LLM returns empty', () async {
      voice.llmGenerate = (_) async => '   ';
      await voice.ask('where is exit 4');
      expect(voice.answer, deterministic);
    });

    test('uses the deterministic answer when the LLM throws', () async {
      voice.llmGenerate = (_) async => throw Exception('boom');
      await voice.ask('where is exit 4');
      expect(voice.answer, deterministic);
    });

    test('speaks the LLM answer when it returns text', () async {
      voice.llmGenerate = (_) async => 'Exit 4 is straight ahead.';
      await voice.ask('where is exit 4');
      expect(voice.answer, 'Exit 4 is straight ahead.');
    });
  });
}
