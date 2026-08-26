import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/feature/chat/data/chat_repository.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_provider.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/chat_composer.dart';
import 'package:ForgeForm/feature/chat/presentation/widgets/conversation_row.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/active_client_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/trainer_console_home.dart';
import 'package:ForgeForm/core/widgets/app_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/messages_screen.dart';

import '../trainer_console/fakes.dart';
import '../trainer_console/licence_fakes.dart';
import 'fakes.dart';

const otherParty = '22222222-2222-2222-2222-222222222222';

/// Wide enough for the desktop 3-pane layout; narrow enough for the mobile one.
const desktopSize = Size(1400, 1000);
const mobileSize = Size(420, 900);

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

  Map<String, dynamic> conversationJson({
    String id = otherParty,
    String name = 'Robert Meyer',
    String? preview = 'see you thursday',
    int unread = 0,
  }) =>
      {
        'otherPartyId': id,
        'otherPartyName': name,
        'lastMessagePreview': preview,
        'lastMessageAt': DateTime.utc(2026, 8, 1, 9).toIso8601String(),
        'unreadCount': unread,
      };

  Future<ChatProvider> pump(
    WidgetTester tester, {
    FakeChatApi? api,
    Size size = desktopSize,
    bool openThread = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chat = ChatProvider(
      repository: ChatRepository(
        db: db,
        api: api ?? FakeChatApi(),
        signalR: signalR,
      ),
    );
    final activeClient = ActiveClientProvider(
      repository: FakeTrainerConsoleRepository(rosterWithStats: [fakeRosterEntry()]),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveClientProvider>.value(value: activeClient),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MessagesScreen(),
        ),
      ),
    );
    if (openThread) {
      await tester.pumpAndSettle();
      await chat.openThread(otherParty);
      await tester.pumpAndSettle();
    }
    return chat;
  }

  group('conversation list states', () {
    testWidgets('shows skeleton placeholders while loading, not a bare spinner',
        (tester) async {
      final gate = Completer<void>();
      await pump(tester, api: FakeChatApi(conversations: [conversationJson()], gate: gate));
      await tester.pump();

      expect(find.byType(LoadingSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('shows a real empty state when there are no conversations',
        (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('No conversations yet'), findsOneWidget);
    });

    testWidgets('shows an inline error with a working retry', (tester) async {
      final api = FakeChatApi(conversations: [conversationJson()])
        ..failConversationsTimes = 1;
      await pump(tester, api: api);
      await tester.pumpAndSettle();

      expect(find.byType(ErrorStateView), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorStateView), findsNothing);
      expect(find.text('Robert Meyer'), findsWidgets);
    });

    testWidgets('lists conversations with their preview', (tester) async {
      await pump(tester, api: FakeChatApi(conversations: [conversationJson()]));
      await tester.pumpAndSettle();

      expect(find.text('Robert Meyer'), findsWidgets);
      expect(find.text('see you thursday'), findsOneWidget);
    });

    testWidgets('an unread conversation is marked by more than colour',
        (tester) async {
      await pump(
        tester,
        api: FakeChatApi(conversations: [conversationJson(unread: 3)]),
      );
      await tester.pumpAndSettle();

      // Colour alone fails for a colourblind trainer, so the count is text.
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('thread', () {
    testWidgets('renders messages from both sides', (tester) async {
      await pump(
        tester,
        api: FakeChatApi(
          conversations: [conversationJson()],
          history: {
            otherParty: [
              messageJson(
                id: 'theirs',
                body: 'how did it go?',
                senderId: otherParty,
                clientId: otherParty,
                sentAt: DateTime.utc(2026, 8, 1, 9),
              ),
              messageJson(
                id: 'mine',
                body: 'strong session',
                senderId: FakeChatSignalRClient.trainerId,
                clientId: otherParty,
                sentAt: DateTime.utc(2026, 8, 1, 10),
              ),
            ],
          },
        ),
        openThread: true,
      );

      expect(find.text('how did it go?'), findsOneWidget);
      expect(find.text('strong session'), findsOneWidget);
    });

    testWidgets('an empty thread says so rather than showing a blank pane',
        (tester) async {
      await pump(
        tester,
        api: FakeChatApi(conversations: [conversationJson()]),
        openThread: true,
      );

      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets('a message being sent is marked as sending', (tester) async {
      final hold = Completer<void>();
      signalR.holdSend = hold;
      final chat = await pump(
        tester,
        api: FakeChatApi(conversations: [conversationJson()]),
        openThread: true,
      );

      unawaited(chat.sendMessage(otherParty, 'great set today'));
      // pumpAndSettle rather than a single pump: the outbox write is async, so
      // whether the optimistic rebuild has landed after exactly one frame is a
      // race. The send itself stays held, so this settles with the bubble
      // still pending, which is the state under test.
      await tester.pumpAndSettle();

      expect(find.text('great set today'), findsOneWidget);
      expect(find.byTooltip('Sending'), findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a failed message offers a retry that re-sends it',
        (tester) async {
      await seedOutboxRow(
        db,
        messageId: 'gave-up',
        otherPartyId: otherParty,
        body: 'never made it',
        createdAt: DateTime.utc(2026, 8, 1),
        status: ChatMessageStatus.failed,
      );
      await pump(
        tester,
        api: FakeChatApi(conversations: [conversationJson()]),
        openThread: true,
      );

      expect(find.text('Failed to send — tap to retry'), findsOneWidget);

      await tester.tap(find.text('Failed to send — tap to retry'));
      await tester.pumpAndSettle();

      expect(signalR.sent.single.messageId, 'gave-up');
    });

    testWidgets('sending from the composer clears it', (tester) async {
      await pump(
        tester,
        api: FakeChatApi(conversations: [conversationJson()]),
        openThread: true,
      );

      await tester.enterText(find.byType(TextField), 'great set today');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      expect(signalR.sent.single.body, 'great set today');
      expect(find.widgetWithText(TextField, 'great set today'), findsNothing);
    });
  });

  group('connection status', () {
    testWidgets('a dropped connection is explained, not left silent',
        (tester) async {
      await pump(
        tester,
        api: FakeChatApi(conversations: [conversationJson()]),
        openThread: true,
      );

      signalR.emitStatus(ChatConnectionStatus.reconnecting);
      await tester.pumpAndSettle();

      expect(find.text('Reconnecting…'), findsOneWidget);
    });

    testWidgets('no banner while connected', (tester) async {
      await pump(
        tester,
        api: FakeChatApi(conversations: [conversationJson()]),
        openThread: true,
      );

      signalR.emitStatus(ChatConnectionStatus.connected);
      await tester.pumpAndSettle();

      expect(find.text('Reconnecting…'), findsNothing);
    });
  });

  group('responsive layout', () {
    testWidgets('desktop shows the list and the thread at once', (tester) async {
      await pump(
        tester,
        api: FakeChatApi(conversations: [conversationJson()]),
        size: desktopSize,
        openThread: true,
      );

      // Both panes visible: the trainer switches client without losing context.
      expect(find.byType(ConversationRow), findsOneWidget);
      expect(find.byType(ChatComposer), findsOneWidget);
    });

    testWidgets('mobile starts on the list with no thread pane', (tester) async {
      await pump(
        tester,
        api: FakeChatApi(conversations: [conversationJson()]),
        size: mobileSize,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConversationRow), findsOneWidget);
      expect(find.byType(ChatComposer), findsNothing);
    });

    testWidgets('mobile drills into a thread and the back arrow returns',
        (tester) async {
      await pump(
        tester,
        api: FakeChatApi(conversations: [conversationJson()]),
        size: mobileSize,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ConversationRow));
      await tester.pumpAndSettle();

      expect(find.byType(ChatComposer), findsOneWidget);
      expect(find.byType(ConversationRow), findsNothing);

      await tester.tap(find.byTooltip('Back to conversations'));
      await tester.pumpAndSettle();

      expect(find.byType(ConversationRow), findsOneWidget);
      expect(find.byType(ChatComposer), findsNothing);
    });
  });

  group('chat unavailable', () {
    testWidgets('the console still opens when the chat stack cannot be built',
        (tester) async {
      tester.view.physicalSize = desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // No AppDatabase registered and no injected repository — exactly the
      // situation that used to throw out of initState and take the whole
      // console down with it, four sections of which have nothing to do with
      // chat.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrainerConsoleHome(
            repository: FakeTrainerConsoleRepository(rosterWithStats: [fakeRosterEntry()]),
            licenceProvider: TrainerLicenceProvider(
              repository: FakeTrainerLicenceRepository(current: licence()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ForgeForm'), findsOneWidget);
    });
  });
}
