import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_bubble.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_date_divider.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

/// Local DateTimes throughout: the widgets format in the reader's timezone, so a
/// UTC fixture would make these assertions depend on where the test runs.
void main() {
  Future<void> pumpBubble(WidgetTester tester, ThreadMessage message) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ChatBubble(message: message)),
      ),
    );
  }

  ThreadMessage message({
    required DateTime timestamp,
    ChatMessageStatus status = ChatMessageStatus.sent,
  }) {
    return ThreadMessage(
      messageId: 'm1',
      body: 'Squats felt heavy today.',
      timestamp: timestamp,
      isMine: false,
      status: status,
    );
  }

  testWidgets('a sent message shows the time it was sent', (tester) async {
    await pumpBubble(tester, message(timestamp: DateTime(2026, 8, 26, 9, 7)));

    expect(find.text('09:07'), findsOneWidget);
  });

  testWidgets('a pending message shows no time', (tester) async {
    await pumpBubble(
      tester,
      message(
        timestamp: DateTime(2026, 8, 26, 9, 7),
        status: ChatMessageStatus.pending,
      ),
    );

    // The moment the user pressed send is not a sent time, so it is not shown.
    expect(find.text('09:07'), findsNothing);
  });

  testWidgets('a failed message shows no time', (tester) async {
    await pumpBubble(
      tester,
      message(
        timestamp: DateTime(2026, 8, 26, 9, 7),
        status: ChatMessageStatus.failed,
      ),
    );

    expect(find.text('09:07'), findsNothing);
  });

  testWidgets('the day divider names the local day, padded and with the year',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatDateDivider(date: DateTime(2026, 8, 4, 9)),
        ),
      ),
    );

    expect(find.text('04/08/2026'), findsOneWidget);
  });

  testWidgets('the divider reads a UTC instant in local time', (tester) async {
    // Whatever the reader's timezone, the pill and the messages under it agree
    // on which day this instant falls on, because both convert the same way.
    final instant = DateTime.utc(2026, 8, 4, 9);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ChatDateDivider(date: instant))),
    );

    final local = instant.toLocal();
    final expected = '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
    expect(find.text(expected), findsOneWidget);
  });
}
