import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/access_provider.dart';
import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/view/coach_chat_screen.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_composer.dart';
import 'package:ForgeForm/core/widgets/app_widgets.dart';

import 'fakes.dart';

const trainerId = FakeChatSignalRClient.trainerId;

void main() {
  late AppDatabase db;
  late FakeChatSignalRClient signalR;

  setUp(() {
    db = newTestDatabase();
    signalR = FakeChatSignalRClient();
  });

  tearDown(() async {
    await signalR.dispose();
    await db.close();
  });

  Future<ChatProvider> pump(
    WidgetTester tester, {
    FakeChatApi? api,
    String? coachId = trainerId,
    String? coachName = 'Dana Ruiz',
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = ChatProvider(
      repository: ChatRepository(
        db: db,
        api: api ?? FakeChatApi(),
        signalR: signalR,
        crypto: FakeChatCrypto(),
        attachmentSender: FakeChatAttachmentSender(),
      ),
    );
    final access = AccessProvider.withState(
      isTrainerClient: coachId != null,
      trainerId: coachId,
      trainerName: coachName,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccessProvider>.value(value: access),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CoachChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return chat;
  }

  testWidgets('a trainee with no coach is told so, not shown a dead composer',
      (tester) async {
    await pump(tester, coachId: null, coachName: null);

    expect(find.text('No coach yet'), findsOneWidget);
    expect(find.byType(ChatComposer), findsNothing);
  });

  testWidgets('names the coach in the header', (tester) async {
    await pump(tester);

    expect(find.text('Dana Ruiz'), findsWidgets);
  });

  testWidgets('shows skeletons while history loads', (tester) async {
    final gate = Completer<void>();
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = ChatProvider(
      repository: ChatRepository(
        db: db,
        api: FakeChatApi(gate: gate),
        signalR: signalR,
        crypto: FakeChatCrypto(),
        attachmentSender: FakeChatAttachmentSender(),
      ),
    );
    final access = AccessProvider.withState(
      isTrainerClient: true,
      trainerId: trainerId,
      trainerName: 'Dana Ruiz',
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccessProvider>.value(value: access),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CoachChatScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoadingSkeleton), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('an empty thread invites the first message', (tester) async {
    await pump(tester);

    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
  });

  testWidgets('renders history with the trainee\'s own messages on their side',
      (tester) async {
    // From the trainee's seat the "other party" is the trainer, so a message
    // whose sender is the trainer is *theirs* and one from the trainee is mine —
    // the mirror image of the console, from the same code.
    await pump(
      tester,
      api: FakeChatApi(history: {
        trainerId: [
          messageJson(
            id: 'from-coach',
            body: 'how did it go?',
            senderId: trainerId,
            clientId: 'trainee-1',
            sentAt: DateTime.utc(2026, 8, 1, 9),
          ),
          messageJson(
            id: 'from-me',
            body: 'felt strong',
            senderId: 'trainee-1',
            clientId: 'trainee-1',
            sentAt: DateTime.utc(2026, 8, 1, 10),
          ),
        ],
      }),
    );

    expect(find.text('how did it go?'), findsOneWidget);
    expect(find.text('felt strong'), findsOneWidget);
  });

  testWidgets('sending goes to the trainer\'s thread', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'ready for thursday');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(signalR.sent.single.otherPartyId, trainerId);
    // The wire carries ciphertext, not what was typed. Asserting the plaintext
    // here would be asserting the absence of encryption.
    expect(signalR.sent.single.body, FakeChatCrypto.sealed('ready for thursday'));
  });

  testWidgets('a dropped connection is explained here too', (tester) async {
    await pump(tester);

    signalR.emitStatus(ChatConnectionStatus.reconnecting);
    await tester.pumpAndSettle();

    expect(find.text('Reconnecting…'), findsOneWidget);
  });

  testWidgets('a failed history load offers a retry', (tester) async {
    await pump(tester, api: FakeChatApi(throwOnHistory: true));

    expect(find.byType(ErrorStateView), findsOneWidget);
  });
}
