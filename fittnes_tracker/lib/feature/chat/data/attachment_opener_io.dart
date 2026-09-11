import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ForgeForm/feature/chat/data/chat_attachment_file.dart';
import 'package:ForgeForm/feature/chat/domain/attachment_filename.dart';
import 'package:ForgeForm/feature/chat/domain/attachment_open_outcome.dart';

/// Writes the decrypted bytes to a real, named temp file and hands it to
/// another app.
///
/// Android/iOS use `open_filex`, which resolves a viewer via the platform's
/// own intent/UTI machinery. Windows/macOS/Linux deliberately do **not**
/// use `open_filex` there too — its desktop path shells out via
/// `Process.start('cmd', ['/c', 'start', '', filePath])` (Windows) and
/// equivalent `Process.start` calls elsewhere, and [name] is chosen by
/// whoever sent the message. `safeAttachmentFileName` already strips shell
/// metacharacters a peer could otherwise put in a *file name*, but a
/// `Process.start` argument list is not a shell string to begin with here —
/// `url_launcher`'s `launchUrl` goes through `ShellExecuteW` /
/// `NSWorkspace.open` / `g_app_info_launch_default_for_uri`, with no shell
/// interpreting the path at all. Belt and braces: the sanitiser guards the
/// name, the launch mechanism guards the mechanism.
///
/// The temp file is **not** deleted after opening. Ownership passes to
/// whatever app just opened it — a `FileProvider` content URI on Android, a
/// separate process with the file open on desktop — and deleting it out
/// from under that would be the same mistake the video/audio tiles'
/// dispose-time cleanup would make if applied here. The OS temp directory
/// is reclaimed on its own schedule; `AttachmentStore.clearAll()` and the
/// "clear chat storage" action also best-effort sweep this directory.
Future<AttachmentOpenOutcome> openAttachmentExternally({
  required Uint8List bytes,
  required String name,
  required String mime,
  required String id,
}) async {
  final safeId = safeAttachmentIdSegment(id);
  final safeName = safeAttachmentFileName(name, fallbackId: id, mime: mime);

  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$chatDocsOpenDirName/$safeId/$safeName';

  try {
    await writeAttachmentBytes(path, bytes);
  } catch (_) {
    return AttachmentOpenOutcome.failed;
  }

  if (Platform.isAndroid || Platform.isIOS) {
    final OpenResult result;
    try {
      result = await OpenFilex.open(path, type: mime);
    } catch (_) {
      return AttachmentOpenOutcome.failed;
    }
    switch (result.type) {
      case ResultType.done:
        return AttachmentOpenOutcome.opened;
      case ResultType.noAppToOpen:
        return AttachmentOpenOutcome.noHandler;
      case ResultType.fileNotFound:
      case ResultType.permissionDenied:
      case ResultType.error:
        return AttachmentOpenOutcome.failed;
    }
  }

  // Windows, macOS, Linux.
  try {
    final ok = await launchUrl(Uri.file(path));
    return ok ? AttachmentOpenOutcome.opened : AttachmentOpenOutcome.failed;
  } catch (_) {
    return AttachmentOpenOutcome.failed;
  }
}
