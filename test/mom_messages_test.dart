import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mom/core/theme/mom_mood.dart';
import 'package:ai_mom/core/utils/mom_messages.dart';

MomMood _moodFor(int done, int total) {
  final score = done / total * 100;
  if (score >= 80) return MomMood.proud;
  if (score >= 55) return MomMood.neutral;
  if (score >= 30) return MomMood.disappointed;
  return MomMood.veryDisappointed;
}

String _say(int done, int total, DateTime day) => momTaskMessage(mood: _moodFor(done, total), done: done, total: total, day: day);

void main() {
  final days = [DateTime(2026, 10, 6), DateTime(2026, 10, 7), DateTime(2026, 12, 31), DateTime(2027, 1, 1)];

  test('every mood has several different lines', () {
    for (final mood in MomMood.values) {
      final lines = momMessagesFor(mood, done: 2, total: 4);
      expect(lines.length, greaterThanOrEqualTo(5), reason: '$mood');
      expect(lines.toSet().length, lines.length, reason: '$mood has a repeated line');
    }
  });

  test('ticking off a task changes the message, even when the mood stays the same', () {
    for (final day in days) {
      for (var total = 1; total <= 12; total++) {
        for (var done = 0; done < total; done++) {
          if (_moodFor(done, total) != _moodFor(done + 1, total)) continue;
          expect(_say(done + 1, total, day), isNot(_say(done, total, day)), reason: '$done -> ${done + 1} of $total on $day');
        }
      }
    }
  });

  test('un-ticking a task changes the message too', () {
    for (var total = 2; total <= 10; total++) {
      for (var done = 1; done <= total; done++) {
        if (_moodFor(done, total) != _moodFor(done - 1, total)) continue;
        expect(_say(done - 1, total, days.first), isNot(_say(done, total, days.first)));
      }
    }
  });

  test('adding a task changes the message, even when the mood stays the same', () {
    for (final day in days) {
      for (var total = 1; total <= 12; total++) {
        for (var done = 0; done <= total; done++) {
          if (_moodFor(done, total) != _moodFor(done, total + 1)) continue;
          expect(_say(done, total + 1, day), isNot(_say(done, total, day)), reason: '$done of $total -> ${total + 1} on $day');
        }
      }
    }
  });

  test('the same situation always gives the same line (it does not flicker)', () {
    expect(_say(2, 5, days.first), _say(2, 5, days.first));
  });

  test('a new day starts on a different line', () {
    var differs = 0;
    for (var total = 1; total <= 8; total++) {
      for (var done = 0; done <= total; done++) {
        if (_say(done, total, days[0]) != _say(done, total, days[1])) differs++;
      }
    }
    expect(differs, greaterThan(30));
  });

  test('lines with counts read naturally', () {
    final lines = momMessagesFor(MomMood.neutral, done: 3, total: 5);
    expect(lines, contains('3 down, 2 to go. You\'re getting there.'));
    expect(momMessagesFor(MomMood.disappointed, done: 1, total: 4).any((l) => l.contains('3 things still waiting')), isTrue);
    expect(momMessagesFor(MomMood.disappointed, done: 3, total: 4).any((l) => l.contains('1 thing still waiting')), isTrue);
    expect(momMessagesFor(MomMood.proud, done: 4, total: 4).any((l) => l.contains('All 4 done')), isTrue);
  });
}
