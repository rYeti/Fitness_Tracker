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

/// Best-effort recursive delete of a whole directory — used to sweep the
/// temp directory documents are opened from (`forgeform_chat_docs`), which
/// is a directory of per-attachment subdirectories, not a single file.
/// Never throws: a directory that never existed, or one an external app
/// still has a file open in, is not worth surfacing as an error to a "clear
/// chat storage" action that's already best-effort.
Future<void> deleteAttachmentDirectory(String path) async {
  final dir = Directory(path);
  if (await dir.exists()) {
    try {
      await dir.delete(recursive: true);
    } catch (_) {
      // Left behind for the OS's own temp-directory reclamation.
    }
  }
}
