import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// `media_kit` falls back to an HTML5 `<video>` element on web, which needs
/// a URL — not the ciphertext-derived bytes we actually have. A blob URL is
/// the bridge: it never leaves this tab, and is revoked the moment the
/// player is disposed. See docs/chat-attachments.md §C.1.
String? createVideoBlobUrl(Uint8List bytes, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  return web.URL.createObjectURL(blob);
}

void revokeVideoBlobUrl(String url) => web.URL.revokeObjectURL(url);
