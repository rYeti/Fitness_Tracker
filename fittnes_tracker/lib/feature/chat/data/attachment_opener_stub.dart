import 'dart:typed_data';

import 'package:ForgeForm/feature/chat/domain/attachment_open_outcome.dart';

/// The fallback used only if neither `dart:io` nor `dart:js_interop` is
/// available — not reachable on any platform this app ships to, required
/// only because the conditional export in `attachment_opener.dart` needs a
/// default.
Future<AttachmentOpenOutcome> openAttachmentExternally({
  required Uint8List bytes,
  required String name,
  required String mime,
  required String id,
}) async => AttachmentOpenOutcome.failed;
