import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/chat/domain/chat_timestamps.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_message.dart';
import 'package:ForgeForm/feature/chat/domain/models/conversation_summary.dart';

/// Label assertions are built from *local* DateTimes on purpose. The formatters
/// convert to the reader's timezone, so a fixture written as UTC would pass or
/// fail depending on where the test machine is.
void main() {
  group('parseInstant', () {
    test('reads a UTC string as the instant it names', () {
      final parsed = ChatTimestamps.parseInstant('2026-08-01T09:30:00.000Z');

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      expect(parsed.isAtSameMomentAs(DateTime.utc(2026, 8, 1, 9, 30)), isTrue);
    });

    test('reads an offset string as the instant it names', () {
      final parsed = ChatTimestamps.parseInstant('2026-08-01T11:30:00+02:00');

      expect(parsed!.isAtSameMomentAs(DateTime.utc(2026, 8, 1, 9, 30)), isTrue);
    });

    test('treats a string with no zone designator as UTC, not local', () {
      // The regression: `DateTime.parse` calls this local, so a reader two hours
      // east of UTC saw every message stamped two hours late.
      final parsed = ChatTimestamps.parseInstant('2026-08-01T09:30:00');

      expect(parsed!.isAtSameMomentAs(DateTime.utc(2026, 8, 1, 9, 30)), isTrue);
    });

    test('rejects the .NET default date rather than passing it on', () {
      expect(ChatTimestamps.parseInstant('0001-01-01T00:00:00'), isNull);
      expect(ChatTimestamps.parseInstant('0001-01-01T00:00:00Z'), isNull);
    });

    test('rejects null, empty and unparseable input', () {
      expect(ChatTimestamps.parseInstant(null), isNull);
      expect(ChatTimestamps.parseInstant(''), isNull);
      expect(ChatTimestamps.parseInstant('not a date'), isNull);
      expect(ChatTimestamps.parseInstant(42), isNull);
    });
  });

  group('dayLabel', () {
    final now = DateTime(2026, 8, 26, 14, 5);

    test('names today and yesterday relatively', () {
      expect(ChatTimestamps.dayLabel(DateTime(2026, 8, 26, 0, 1), now: now),
          'Today');
      expect(ChatTimestamps.dayLabel(DateTime(2026, 8, 25, 23, 59), now: now),
          'Yesterday');
    });

    test('pads the day and month and always carries the year', () {
      expect(
        ChatTimestamps.dayLabel(DateTime(2026, 8, 4, 9), now: now),
        '04/08/2026',
      );
    });
  });

  group('listLabel', () {
    final now = DateTime(2026, 8, 26, 14, 5);

    test('shows the time for today', () {
      expect(ChatTimestamps.listLabel(DateTime(2026, 8, 26, 9, 7), now: now),
          '09:07');
    });

    test('shows the weekday inside the last week', () {
      // 2026-08-24 is a Monday.
      expect(ChatTimestamps.listLabel(DateTime(2026, 8, 24, 9), now: now),
          'Mon');
    });

    test('shows a date beyond a week, with the year only when it differs', () {
      expect(ChatTimestamps.listLabel(DateTime(2026, 8, 4, 9), now: now),
          '04/08');
      expect(ChatTimestamps.listLabel(DateTime(2025, 8, 4, 9), now: now),
          '04/08/2025');
    });
  });

  test('timeOfDay pads both halves', () {
    expect(ChatTimestamps.timeOfDay(DateTime(2026, 8, 26, 9, 7)), '09:07');
  });

  group('crossesDay', () {
    test('is true for the first message and across a local midnight', () {
      expect(ChatTimestamps.crossesDay(null, DateTime(2026, 8, 26)), isTrue);
      expect(
        ChatTimestamps.crossesDay(
            DateTime(2026, 8, 25, 23, 59), DateTime(2026, 8, 26, 0, 1)),
        isTrue,
      );
    });

    test('is false inside one local day', () {
      expect(
        ChatTimestamps.crossesDay(
            DateTime(2026, 8, 26, 0, 1), DateTime(2026, 8, 26, 23, 59)),
        isFalse,
      );
    });
  });

  group('model parsing', () {
    Map<String, dynamic> messagePayload(Object? sentAt) => {
          'id': 'm1',
          'body': 'hello',
          'sentAt': sentAt,
          'senderId': 's',
          'trainerId': 't',
          'clientId': 'c',
          'mediaType': null,
          'url': null,
          'thumbnailUrl': null,
        };

    test('a message with an unusable sentAt is dated to now, never year 1', () {
      final before = DateTime.now().toUtc();
      final message = ChatMessage.fromJson(messagePayload('0001-01-01T00:00:00'));

      expect(message.sentAt.year, greaterThan(2000));
      expect(message.sentAt.isBefore(before), isFalse);
    });

    test('a message with a missing sentAt parses rather than throwing', () {
      expect(() => ChatMessage.fromJson(messagePayload(null)), returnsNormally);
    });

    test('a conversation with an unusable lastMessageAt shows no time', () {
      final summary = ConversationSummary.fromJson({
        'otherPartyId': 'c',
        'otherPartyName': 'Robert Meyer',
        'lastMessagePreview': null,
        'lastMessageAt': '0001-01-01T00:00:00',
        'unreadCount': 0,
      });

      expect(summary.lastMessageAt, isNull);
    });
  });
}
