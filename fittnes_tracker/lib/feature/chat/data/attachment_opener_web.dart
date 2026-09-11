import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:ForgeForm/feature/chat/domain/attachment_filename.dart';
import 'package:ForgeForm/feature/chat/domain/attachment_open_outcome.dart';

/// Web has no filesystem and no OS-level "open with" — the closest
/// equivalent is a browser download, which is what this does: build a blob
/// URL from the decrypted bytes with the real MIME type, click a hidden
/// `<a download>` anchor, then revoke the URL.
///
/// This must never import `open_filex`: its own web implementation wraps
/// legacy `dart:html` and is a no-op there in any case (see
/// `attachment_opener_io.dart` for the platforms it's actually for).
///
/// [safeAttachmentFileName]'s output is not just a defensive filesystem
/// name here — on web it is literally what the browser saves the file as,
/// via the anchor's `download` attribute. A peer choosing the visible
/// save-as name is the whole reason it still has to be sanitised even
/// though nothing here ever touches a real path.
///
/// `<a download>`, not `target: '_blank'`: opening a new tab from an async
/// callback (after the `await` that decrypted these bytes) is outside the
/// synchronous span of the user's click, so a popup blocker eats it in
/// several browsers. A programmatic anchor click is not subject to that.
Future<AttachmentOpenOutcome> openAttachmentExternally({
  required Uint8List bytes,
  required String name,
  required String mime,
  required String id,
}) async {
  final safeName = safeAttachmentFileName(name, fallbackId: id, mime: mime);

  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);

  // Never actually painted: appended, clicked and removed within one
  // synchronous span, so there is no frame in which it could be visible —
  // nothing here needs `display: none`.
  final anchor =
      web.HTMLAnchorElement()
        ..href = url
        ..download = safeName;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // Revoked after a delay rather than immediately: some browsers start the
  // download asynchronously, and an immediate revoke can race it.
  Future.delayed(const Duration(seconds: 30), () {
    web.URL.revokeObjectURL(url);
  });

  // The browser gives no signal back for "the user's download manager
  // actually saved this" — there is no `noHandler`/`failed` distinction to
  // make here the way there is natively, so this reports success once the
  // download has been handed to the browser.
  return AttachmentOpenOutcome.opened;
}
