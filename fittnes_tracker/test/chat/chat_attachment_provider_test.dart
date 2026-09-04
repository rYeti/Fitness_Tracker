import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/network/api_client.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_api.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';
import 'package:ForgeForm/feature/chat/presentation/providers/chat_attachment_provider.dart';

/// Counts `mintDownload` calls rather than actually reaching a server — the
/// assertion this file exists for is that a call *never happens* for an
/// expired attachment, not what a real response would look like.
class _CountingChatAttachmentApi extends ChatAttachmentApi {
  int mintDownloadCalls = 0;

  _CountingChatAttachmentApi()
    : super(client: ApiClient(baseUrl: 'http://localhost'));

  @override
  Future<Map<String, dynamic>> mintDownload(String attachmentId) async {
    mintDownloadCalls++;
    return {'downloadUrl': 'http://localhost/attachments/$attachmentId'};
  }
}

ChatAttachmentRef _pictureRef({String id = 'att-1'}) {
  return ChatAttachmentRef(
    id: id,
    kind: MediaType.picture,
    mime: 'image/jpeg',
    name: 'photo.jpg',
    size: 1024,
    key: 'a2V5',
    iv: 'aXY=',
    sha256: 'deadbeef',
  );
}

ThreadMessage _message({
  required DateTime timestamp,
  required ChatAttachmentRef attachment,
}) {
  return ThreadMessage(
    messageId: 'm1',
    body: null,
    timestamp: timestamp,
    isMine: false,
    status: ChatMessageStatus.sent,
    attachment: attachment,
    uploadStatus: AttachmentUploadStatus.uploaded,
  );
}

void main() {
  group('retention', () {
    test('a message inside the retention window is not expired', () {
      final provider = ChatAttachmentProvider(
        api: _CountingChatAttachmentApi(),
      );
      final message = _message(
        timestamp: DateTime.now().toUtc().subtract(const Duration(days: 10)),
        attachment: _pictureRef(),
      );

      expect(provider.stateFor(message).phase, isNot(AttachmentPhase.expired));
    });

    test(
      'a message past the retention window is expired without a store lookup',
      () {
        final provider = ChatAttachmentProvider(
          api: _CountingChatAttachmentApi(),
        );
        final message = _message(
          timestamp: DateTime.now().toUtc().subtract(const Duration(days: 46)),
          attachment: _pictureRef(),
        );

        expect(provider.stateFor(message).phase, AttachmentPhase.expired);
      },
    );

    // The load-bearing assertion: whatever prompted a fetch on an expired
    // attachment — auto-download, a retry tap, a stale rebuild — must never
    // reach the network. R2 has already forgotten the blob; a request would
    // only cost a round trip to learn what stateFor already knew.
    test(
      'fetch never mints a download URL for an expired attachment',
      () async {
        final api = _CountingChatAttachmentApi();
        final provider = ChatAttachmentProvider(api: api);
        final message = _message(
          timestamp: DateTime.now().toUtc().subtract(const Duration(days: 90)),
          attachment: _pictureRef(),
        );

        await provider.fetch(message, threadId: 'thread-1');

        expect(api.mintDownloadCalls, 0);
        expect(provider.stateFor(message).phase, AttachmentPhase.expired);
      },
    );

    test(
      'ensureAutoFetched also never fetches an expired attachment',
      () async {
        final api = _CountingChatAttachmentApi();
        final provider = ChatAttachmentProvider(api: api);
        final message = _message(
          timestamp: DateTime.now().toUtc().subtract(const Duration(days: 90)),
          attachment: _pictureRef(),
        );

        provider.ensureAutoFetched(message, threadId: 'thread-1');
        await Future<void>.delayed(Duration.zero);

        expect(api.mintDownloadCalls, 0);
      },
    );
  });

  group('upload in flight', () {
    test(
      'fetch is a no-op while this device is still uploading the attachment',
      () async {
        final api = _CountingChatAttachmentApi();
        final provider = ChatAttachmentProvider(api: api);
        final message = ThreadMessage(
          messageId: 'm1',
          body: null,
          timestamp: DateTime.now().toUtc(),
          isMine: true,
          status: ChatMessageStatus.pending,
          attachment: _pictureRef(),
          uploadStatus: AttachmentUploadStatus.uploading,
        );

        expect(provider.stateFor(message).phase, AttachmentPhase.uploading);

        await provider.fetch(message, threadId: 'thread-1');

        expect(api.mintDownloadCalls, 0);
      },
    );
  });
}
