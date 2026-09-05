import 'dart:typed_data';

/// The web stub — there is no filesystem to write to, so an interrupted
/// upload cannot resume from disk on this platform. See
/// docs/chat-attachments.md and `ChatAttachmentSender`'s own doc comment.
Future<void> writeAttachmentBytes(String path, Uint8List bytes) async {}

Future<Uint8List?> readAttachmentBytes(String path) async => null;

Future<void> deleteAttachmentFile(String path) async {}
