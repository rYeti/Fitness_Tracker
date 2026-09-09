import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_capabilities.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_draft.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_composer.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';

import 'fakes.dart';

/// The fix for the actual production bug: an attach affordance that was
/// offered on every deployment, including ones with no blob store configured,
/// where every upload failed with "upload failed, double tap to retry"
/// forever. This is what pins "disabled means disabled" at the widget level.
void main() {
  // The mic affordance also gates on the platform (hidden on Linux and web —
  // see ChatComposer._micAvailable), and `flutter test` reports whatever the
  // host actually is with no override applied by the test binding. Forcing
  // it here is what makes these tests assert the *capabilities* gate
  // specifically, rather than accidentally depending on which OS happens to
  // run this suite.
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> pump(
    WidgetTester tester, {
    required ChatAttachmentCapabilities capabilities,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatComposer(
            capabilities: capabilities,
            onSend: (ChatDraft _) {},
            attachmentSender: FakeChatAttachmentSender(),
            voiceRecorder: FakeVoiceRecorder(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the attach button is disabled when capabilities report disabled', (tester) async {
    await pump(tester, capabilities: ChatAttachmentCapabilities.disabled);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add_rounded),
    );

    expect(button.onPressed, isNull);
    expect(button.tooltip, l10n.chatAttachmentsUnavailable);
  });

  testWidgets('the attach button is enabled once capabilities report enabled', (tester) async {
    await pump(
      tester,
      capabilities: const ChatAttachmentCapabilities(
        enabled: true,
        maxImageBytes: 8 * 1024 * 1024,
        maxVideoBytes: 16 * 1024 * 1024,
        retentionDays: 45,
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add_rounded),
    );

    expect(button.onPressed, isNotNull);
    expect(button.tooltip, l10n.chatOpenAttachMenu);
  });

  testWidgets('the mic stays hidden when capabilities report disabled, even though the platform allows it', (
    tester,
  ) async {
    // A voice note is an attachment. Before this, the mic answered only to
    // the platform check, so it stayed offered on a deployment with no blob
    // store — a recording the user had already made was the thing that
    // discovered the feature didn't actually work.
    await pump(tester, capabilities: ChatAttachmentCapabilities.disabled);

    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    // The trailing button falls back to send with nothing typed, rather than
    // disappearing outright.
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('the mic appears once capabilities report enabled', (tester) async {
    await pump(
      tester,
      capabilities: const ChatAttachmentCapabilities(
        enabled: true,
        maxImageBytes: 8 * 1024 * 1024,
        maxVideoBytes: 16 * 1024 * 1024,
        retentionDays: 45,
      ),
    );

    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });
}
