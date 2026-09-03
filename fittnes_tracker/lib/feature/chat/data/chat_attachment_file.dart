// Conditional export: the real `dart:io`-backed implementation everywhere
// except web, the no-op stub there. `dart:io` cannot be imported at all in
// code compiled for web — not merely unsupported at runtime — so this
// indirection is required, not a style choice. See
// `ChatAttachmentSender`'s own doc comment for what this trades away on web.
export 'chat_attachment_file_stub.dart'
    if (dart.library.io) 'chat_attachment_file_io.dart';
