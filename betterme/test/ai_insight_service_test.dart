import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:betterme/services/ai_insight_service.dart';

// Gemma 4 honours `responseSchema` less reliably than the Gemini models: in
// testing roughly 1 nested-schema call in 8 came back as a valid JSON object
// followed by a second object, which makes a plain jsonDecode throw
// "FormatException: Extra data". These cases pin down the shapes that reach
// firstJsonObject(), including the ones a naive first-'{'..last-'}' slice
// silently gets wrong.

/// Decodes via the extractor the way _decodeJson does, so a case only passes
/// if the slice is genuinely parseable — not merely non-null.
Object? decodeVia(String raw) {
  final slice = AIInsightService.firstJsonObject(raw);
  return slice == null ? null : jsonDecode(slice);
}

void main() {
  group('firstJsonObject', () {
    test('passes through a clean object', () {
      const raw = '{"intro":"hi","tips":[]}';
      expect(decodeVia(raw), {'intro': 'hi', 'tips': <dynamic>[]});
    });

    test('strips trailing prose', () {
      const raw = '{"intro":"hi","tips":[]}\nHope that helps!';
      expect(decodeVia(raw), {'intro': 'hi', 'tips': <dynamic>[]});
    });

    test('strips a markdown fence', () {
      const raw = '```json\n{"intro":"hi","tips":[]}\n```';
      expect(decodeVia(raw), {'intro': 'hi', 'tips': <dynamic>[]});
    });

    // The observed failure. A first-'{'..last-'}' slice spans BOTH objects and
    // throws the very same "Extra data" error it was meant to prevent.
    test('takes only the first of two objects', () {
      const raw = '{"intro":"hi","tips":[]}\n{"note":"extra"}';
      expect(decodeVia(raw), {'intro': 'hi', 'tips': <dynamic>[]});
    });

    test('keeps nested objects intact', () {
      const raw =
          '{"intro":"hi","tips":[{"title":"Rest","detail":"Sleep early."}]}'
          '\n{"note":"extra"}';
      expect(decodeVia(raw), {
        'intro': 'hi',
        'tips': [
          {'title': 'Rest', 'detail': 'Sleep early.'}
        ],
      });
    });

    // A brace inside a string literal must not be counted as nesting, or the
    // object closes early and the slice is invalid.
    test('ignores braces inside string values', () {
      const raw = '{"intro":"use {curly} braces","tips":[]}';
      expect(decodeVia(raw), {'intro': 'use {curly} braces', 'tips': <dynamic>[]});
    });

    test('ignores an escaped quote inside a string value', () {
      const raw = r'{"intro":"she said \"hi\" {then left}","tips":[]}';
      expect(decodeVia(raw), {
        'intro': r'she said "hi" {then left}',
        'tips': <dynamic>[],
      });
    });

    // Truncation at maxOutputTokens. Half an insight is worse than none, so
    // this must yield null rather than a partial object.
    test('returns null on an object truncated mid-string', () {
      const raw = '{"intro":"hi","tips":[{"title":"Rest","detail":"Try to sle';
      expect(AIInsightService.firstJsonObject(raw), isNull);
    });

    test('returns null when there is no object at all', () {
      expect(AIInsightService.firstJsonObject('I could not help with that.'),
          isNull);
      expect(AIInsightService.firstJsonObject(''), isNull);
    });
  });
}
