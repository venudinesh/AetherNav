import '../../data/models/landmark.dart';

/// The result of answering a voice query.
class VoiceAnswer {
  final String spoken;
  const VoiceAnswer(this.spoken);
}

/// Resolves local navigation questions ("Where is Exit 4?") against the demo map
/// using the current heading. Entirely on-device string matching, no cloud NLU.
class VoiceInteraction {
  final DemoMap map;
  const VoiceInteraction(this.map);

  VoiceAnswer answer(String query, {double heading = 0}) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      return const VoiceAnswer("I didn't catch that. Please ask again.");
    }

    Landmark? best;
    var bestScore = 0;
    for (final lm in map.landmarks) {
      final score = _matchScore(q, lm);
      if (score > bestScore) {
        bestScore = score;
        best = lm;
      }
    }

    if (best == null || bestScore == 0) {
      if (q.contains('exit')) {
        final exits = map.landmarks
            .where((l) => l.kind == 'exit')
            .map((l) => l.name)
            .join(', ');
        if (exits.isNotEmpty) return VoiceAnswer('The exits are $exits.');
      }
      final chat = _smallTalk(q);
      if (chat != null) return VoiceAnswer(chat);
      return VoiceAnswer(
          "I can help you find places like ${_examples()}, or answer other "
          'questions once the offline voice model is on (Settings → Offline AI).');
    }

    final direction = _relative(best.bearing, heading);
    final dist = best.distanceMeters.round();
    final note = best.note != null ? ' ${best.note}.' : '';
    return VoiceAnswer(
        '${best.name} is $direction, about $dist metres away.$note');
  }

  int _matchScore(String q, Landmark lm) {
    var score = 0;
    for (final token in lm.name.toLowerCase().split(RegExp(r'\s+'))) {
      if (token.isNotEmpty && q.contains(token)) score++;
    }
    if (q.contains(lm.kind)) score++;
    return score;
  }

  String _examples() => map.landmarks.take(3).map((l) => l.name).join(', ');

  String _firstName() =>
      map.landmarks.isEmpty ? 'the exit' : map.landmarks.first.name;

  /// Light conversational replies for greetings and meta questions, so a plain
  /// "hello" isn't met with a navigation error. Returns null when the query
  /// isn't small talk, so the caller falls through to the honest fallback. Only
  /// reached when no landmark matched, so it can't shadow a real place.
  String? _smallTalk(String q) {
    final words = q.split(RegExp(r'[^a-z]+')).toSet();
    bool has(Set<String> s) => words.intersection(s).isNotEmpty;
    bool phrase(List<String> ps) => ps.any(q.contains);

    if (has({'thanks', 'thank', 'thx', 'ty'}) || phrase(['thank you'])) {
      return "You're welcome. Anything else?";
    }
    if (has({'bye', 'goodbye', 'cya'}) || phrase(['good bye', 'see you'])) {
      return 'Goodbye. Stay safe out there.';
    }
    if (phrase([
      'how are you',
      "how're you",
      'how r you',
      "how's it going",
      'how is it going',
      "what's up",
      'whats up',
    ])) {
      return "I'm running right here on your device and ready to help. "
          'Ask me where something is.';
    }
    if (phrase([
          'who are you',
          'what are you',
          'what can you do',
          'what do you do',
        ]) ||
        has({'help'})) {
      return "I'm AetherNav's offline assistant. I can tell you where nearby "
          "landmarks are and which way to head — try 'where is ${_firstName()}'.";
    }
    if (has({'hi', 'hello', 'hey', 'yo', 'howdy', 'hiya', 'hola'}) ||
        phrase(['good morning', 'good afternoon', 'good evening'])) {
      return 'Hello. I can help you find places nearby or tell you which way '
          "you're facing. What are you looking for?";
    }
    return null;
  }

  /// Builds the grounded prompt for the optional offline LLM. The whole prompt
  /// is sent as a single user message (the wrapper adds no system message), so
  /// the grounding rules lead the string. Directions and distances are computed
  /// here by the same deterministic code [answer] uses — the model only selects
  /// and phrases a fact, it never computes geometry or invents a place.
  String buildPrompt(String query, double heading) {
    final facts = StringBuffer();
    for (final lm in map.landmarks) {
      final direction = _relative(lm.bearing, heading);
      final dist = lm.distanceMeters.round();
      final note = lm.note != null ? ' ${lm.note}.' : '';
      facts.writeln(
          '- ${lm.name} (${lm.kind}): $direction, about $dist metres away.$note');
    }
    return 'You are AetherNav Edge\'s offline voice assistant for a mobility '
        'aid. Be friendly and conversational: you may greet, make small talk, '
        'and answer general questions briefly. BUT for anything about places, '
        'directions, or distances, use ONLY the FACTS below — never invent or '
        'guess a place, direction, or distance. If a location question is not '
        'covered by the facts, say you do not have it and mention what you do '
        'know. Reply in one or two short spoken sentences.\n\n'
        'FACTS (area: ${map.area}):\n'
        '${facts.toString()}\n'
        'QUESTION: $query\n'
        'ANSWER:';
  }

  /// Converts an absolute bearing + current heading into a spoken relative cue.
  String _relative(double bearing, double heading) {
    final delta = (((bearing - heading) + 540) % 360) - 180; // -180..180
    final a = delta.abs();
    if (a <= 20) return 'straight ahead';
    if (a >= 160) return 'behind you';
    final side = delta > 0 ? 'right' : 'left';
    if (a < 70) return 'ahead and to your $side';
    return 'to your $side';
  }
}
