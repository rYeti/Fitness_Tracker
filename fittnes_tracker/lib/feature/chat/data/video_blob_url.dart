// Conditional export: the real web implementation only where `dart:js_interop`
// exists (web builds), a no-op stub everywhere else. See
// `chat_attachment_file.dart` for the same pattern used for `dart:io`.
export 'video_blob_url_stub.dart'
    if (dart.library.js_interop) 'video_blob_url_web.dart';
