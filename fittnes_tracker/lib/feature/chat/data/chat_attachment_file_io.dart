import 'dart:io';
import 'dart:typed_data';

/// The real, native implementation — only ever compiled in on platforms
/// where `dart:io` exists. See `chat_attachment_file.dart` for why this is
/// behind a conditional export rather than imported directly.
Future<void> writeAttachmentBytes(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<Uint8List?> readAttachmentBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> deleteAttachmentFile(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
