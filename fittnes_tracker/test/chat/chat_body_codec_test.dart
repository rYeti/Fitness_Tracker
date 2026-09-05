import 'package:flutter_test/flutter_test.dart';

import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/domain/chat_body_codec.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';

ChatAttachmentRef _photo({String id = 'a1'}) => ChatAttachmentRef(
  id: id,
  kind: MediaType.picture,
  mime: 'image/jpeg',
  name: 'IMG_0421.jpg',
  size: 812344,
  key: 'a2V5',
  iv: 'aXY=',
  sha256: 'c2hh',
  width: 1600,
  height: 1200,
  avgColor: '#8a7f6e',
);

void main() {
  group('ChatBodyCodec.encode', () {
    test('a plain caption with no attachments is returned unchanged', () {
      expect(ChatBodyCodec.encode(caption: 'how did the last set feel?'), 'how did the last set feel?');
    });

    test('null caption with no attachments encodes to an empty string', () {
      expect(ChatBodyCodec.encode(), '');
    });

    test('an attachment produces an envelope whose first key is note', () {
      final encoded = ChatBodyCodec.encode(caption: 'great session', attachments: [_photo()]);
      expect(encoded, startsWith('{"note"'));
      expect(encoded, contains('"ff":1'));
    });
  });

  group('ChatBodyCodec.decode round trip', () {
    test('a plain message decodes back to its own caption with no attachments', () {
      final decoded = ChatBodyCodec.decode('did you see my form?');
      expect(decoded.caption, 'did you see my form?');
      expect(decoded.attachments, isEmpty);
    });

    test('null decodes to an empty body', () {
      final decoded = ChatBodyCodec.decode(null);
      expect(decoded.caption, isNull);
      expect(decoded.attachments, isEmpty);
    });

    test('an encoded attachment round-trips with its caption', () {
      final encoded = ChatBodyCodec.encode(caption: 'great session today', attachments: [_photo()]);
      final decoded = ChatBodyCodec.decode(encoded);

      expect(decoded.caption, 'great session today');
      expect(decoded.attachments, hasLength(1));
      expect(decoded.attachments.single.id, 'a1');
      expect(decoded.attachments.single.mime, 'image/jpeg');
      expect(decoded.attachments.single.width, 1600);
    });

    test('an attachment with no caption round-trips with a null caption', () {
      final encoded = ChatBodyCodec.encode(attachments: [_photo()]);
      final decoded = ChatBodyCodec.decode(encoded);

      expect(decoded.caption, isNull);
      expect(decoded.hasAttachment, isTrue);
    });
  });

  group('detection does not misread plain text as a manifest', () {
    test('a message that happens to start with the manifest prefix but has no ff key stays text', () {
      const trap = '{"note": "just a coincidence, not JSON"}';
      final decoded = ChatBodyCodec.decode(trap);

      expect(decoded.caption, trap);
      expect(decoded.attachments, isEmpty);
    });

    test('a message that is valid JSON shaped like an envelope but has no att list falls back to note', () {
      const noAttachments = '{"note":"hi","ff":1}';
      final decoded = ChatBodyCodec.decode(noAttachments);

      expect(decoded.caption, 'hi');
      expect(decoded.attachments, isEmpty);
    });

    test('malformed JSON that starts with the prefix falls back to the raw string', () {
      const broken = '{"note": "unterminated, "ff":1, "att":[';
      final decoded = ChatBodyCodec.decode(broken);

      expect(decoded.caption, broken);
      expect(decoded.attachments, isEmpty);
    });
  });

  group('resilience to an appended enum value', () {
    test('an attachment with an unrecognised kind index renders as a generic document rather than throwing', () {
      // §0.1's lesson, applied where it can actually reach a client for
      // real: a manifest's `kind` is sent by a real sender, unlike
      // ChatMessage.mediaType, which the server never writes.
      const withUnknownKind = '{"note":"hi","ff":1,"att":['
          '{"id":"a1","kind":99,"mime":"x","name":"n","size":1,"key":"a","iv":"b","sha256":"c"}'
          ']}';

      expect(
        () => ChatBodyCodec.decode(withUnknownKind),
        returnsNormally,
      );
      final decoded = ChatBodyCodec.decode(withUnknownKind);
      expect(decoded.attachments.single.kind, MediaType.document);
    });

    test('one malformed attachment in a list costs one entry, not the message', () {
      const oneBadOneGood = '{"note":"hi","ff":1,"att":['
          '{"id":"bad"},' // missing required fields
          '{"id":"a1","kind":0,"mime":"image/jpeg","name":"n","size":1,"key":"a","iv":"b","sha256":"c"}'
          ']}';

      final decoded = ChatBodyCodec.decode(oneBadOneGood);
      expect(decoded.attachments, hasLength(1));
      expect(decoded.attachments.single.id, 'a1');
    });
  });
}
