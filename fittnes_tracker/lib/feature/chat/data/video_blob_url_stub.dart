import 'dart:typed_data';

// The stub for every platform but web. Native platforms play video from a
// decrypted temp file instead — see chat_video_player.dart — so this is
// never called there.
String? createVideoBlobUrl(Uint8List bytes, String mime) => null;

void revokeVideoBlobUrl(String url) {}
