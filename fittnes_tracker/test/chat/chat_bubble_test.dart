import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_api.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_attachment_provider.dart';
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

  testWidgets('the day divider names the local day, padded and with the year', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatDateDivider(date: DateTime(2026, 8, 4, 9))),
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
    final expected =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
    expect(find.text(expected), findsOneWidget);
  });

  // ── Attachments ───────────────────────────────────────────────────────

  ChatAttachmentRef pictureRef({int? width, int? height}) => ChatAttachmentRef(
    id: 'att-1',
    kind: MediaType.picture,
    mime: 'image/jpeg',
    name: 'photo.jpg',
    size: 204800,
    key: 'a2V5',
    iv: 'aXY=',
    sha256: 'deadbeef',
    width: width,
    height: height,
  );

  ChatAttachmentRef documentRef() => const ChatAttachmentRef(
    id: 'att-2',
    kind: MediaType.document,
    mime: 'application/pdf',
    name: 'plan-week-3.pdf',
    size: 245760,
    key: 'a2V5',
    iv: 'aXY=',
    sha256: 'deadbeef',
  );

  ChatAttachmentRef videoRef({int? durationSeconds}) => ChatAttachmentRef(
    id: 'att-3',
    kind: MediaType.video,
    mime: 'video/mp4',
    name: 'form-check.mp4',
    size: 8388608,
    key: 'a2V5',
    iv: 'aXY=',
    sha256: 'deadbeef',
    width: 1280,
    height: 720,
    durationSeconds: durationSeconds,
  );

  Future<void> pumpAttachmentBubble(
    WidgetTester tester,
    ThreadMessage message, {
    String? threadId = 'thread-1',
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider(
          // Never actually reaches the network in these tests: threadId is
          // non-null only where a fetch is expected to be a genuine no-op
          // (an already-settled upload/download state), and every case here
          // is checked against that assumption via the semantics value.
          create:
              (_) => ChatAttachmentProvider(
                api: ChatAttachmentApi(
                  client: ApiClient(baseUrl: 'http://localhost'),
                ),
              ),
          child: Scaffold(
            body: ChatBubble(message: message, threadId: threadId),
          ),
        ),
      ),
    );
  }

  Semantics findBubbleSemantics(WidgetTester tester) {
    return tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.value != null);
  }

  testWidgets('an uploading photo is spelled out for a screen reader', (
    tester,
  ) async {
    final msg = ThreadMessage(
      messageId: 'm1',
      body: null,
      timestamp: DateTime(2026, 8, 26, 9, 7),
      isMine: true,
      status: ChatMessageStatus.pending,
      attachment: pictureRef(width: 800, height: 600),
      uploadStatus: AttachmentUploadStatus.uploading,
    );
    await pumpAttachmentBubble(tester, msg);
    await tester.pump();

    expect(findBubbleSemantics(tester).properties.value, contains('uploading'));
  });

  testWidgets('an upload failure is spelled out with the retry hint', (
    tester,
  ) async {
    final msg = ThreadMessage(
      messageId: 'm1',
      body: null,
      timestamp: DateTime(2026, 8, 26, 9, 7),
      isMine: true,
      status: ChatMessageStatus.pending,
      attachment: pictureRef(width: 800, height: 600),
      uploadStatus: AttachmentUploadStatus.failed,
    );
    await pumpAttachmentBubble(tester, msg);
    await tester.pump();

    final value = findBubbleSemantics(tester).properties.value!;
    expect(value, contains('upload failed'));
    expect(value, contains('double tap to retry'));
  });

  testWidgets('a document not yet downloaded names itself and invites a tap', (
    tester,
  ) async {
    final msg = ThreadMessage(
      messageId: 'm1',
      body: null,
      timestamp: DateTime(2026, 8, 26, 9, 7),
      isMine: false,
      status: ChatMessageStatus.sent,
      attachment: documentRef(),
      uploadStatus: AttachmentUploadStatus.uploaded,
    );
    // threadId null: a document waits for a tap, never auto-fetches, so this
    // also stands as evidence that rendering it costs no network call —
    // there is no attachment id the fake api could even be asked for.
    await pumpAttachmentBubble(tester, msg, threadId: null);
    await tester.pump();

    expect(find.text('plan-week-3.pdf'), findsOneWidget);
    expect(findBubbleSemantics(tester).properties.value, contains('Document'));
  });

  testWidgets(
    'an attachment past the retention window renders expired and never fetches',
    (tester) async {
      final msg = ThreadMessage(
        messageId: 'm1',
        body: null,
        timestamp: DateTime.now().subtract(const Duration(days: 90)),
        isMine: false,
        status: ChatMessageStatus.sent,
        attachment: pictureRef(width: 800, height: 600),
        uploadStatus: AttachmentUploadStatus.uploaded,
      );
      // threadId is non-null here specifically so the auto-download policy
      // (images fetch on first paint) gets a chance to run — the assertion is
      // that ChatAttachmentProvider.stateFor's expiry check stops it before it
      // does, not that nothing tried.
      await pumpAttachmentBubble(tester, msg);
      await tester.pumpAndSettle();

      expect(
        findBubbleSemantics(tester).properties.value,
        contains('No longer available'),
      );
    },
  );

  testWidgets(
    'a video not yet downloaded names itself, its duration, and invites a tap',
    (tester) async {
      final msg = ThreadMessage(
        messageId: 'm1',
        body: null,
        timestamp: DateTime(2026, 8, 26, 9, 7),
        isMine: false,
        status: ChatMessageStatus.sent,
        attachment: videoRef(durationSeconds: 42),
        uploadStatus: AttachmentUploadStatus.uploaded,
      );
      // threadId null for the same reason as the document case above: video
      // is never auto-fetched (only pictures are), so rendering it here
      // costs no network call at all — there is no api for a stray fetch to
      // even reach.
      await pumpAttachmentBubble(tester, msg, threadId: null);
      await tester.pump();

      expect(find.text('0:42'), findsOneWidget);
      final value = findBubbleSemantics(tester).properties.value!;
      expect(value, contains('Video'));
      expect(value, contains('tap to download'));
    },
  );

  testWidgets('a caption rides alongside the attachment in the spoken value', (
    tester,
  ) async {
    final msg = ThreadMessage(
      messageId: 'm1',
      body: 'great session today',
      timestamp: DateTime(2026, 8, 26, 9, 7),
      isMine: true,
      status: ChatMessageStatus.pending,
      attachment: pictureRef(width: 800, height: 600),
      uploadStatus: AttachmentUploadStatus.uploading,
    );
    await pumpAttachmentBubble(tester, msg);
    await tester.pump();

    final value = findBubbleSemantics(tester).properties.value!;
    expect(value, contains('great session today'));
    expect(find.text('great session today'), findsOneWidget);
  });
}
