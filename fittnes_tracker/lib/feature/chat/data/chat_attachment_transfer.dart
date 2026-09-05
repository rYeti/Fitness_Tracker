import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Raw PUT/GET of attachment ciphertext against the presigned URLs
/// `ChatAttachmentApi` mints. Deliberately **not** the shared `ApiClient`,
/// for three separate reasons any one of which would be enough on its own:
///
/// 1. `ApiClient`'s `BaseOptions` hardcodes `contentType: 'application/json'`
///    — wrong for a raw ciphertext body.
/// 2. Its request interceptor attaches `Authorization: Bearer …` on every
///    call. R2 rejects a request carrying both a bearer header and SigV4
///    query auth, so that header has to simply not be there.
/// 3. Its 401-refresh-retry would fire on an R2 403 (a different kind of
///    "unauthorized" — an expired or malformed presigned URL, nothing to do
///    with this device's session) and burn a refresh token against a server
///    that has never heard of us.
///
/// A bare `Dio` sidesteps all three. See docs/chat-attachments.md §B.4.
class ChatAttachmentTransfer {
  final Dio _dio;

  ChatAttachmentTransfer({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              // 16 MB (the video cap) can genuinely take a while on a poor
              // connection; the shared ApiClient's 15s receive timeout is
              // tuned for ordinary JSON responses and is far too short here.
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(minutes: 5),
              receiveTimeout: const Duration(minutes: 5),
            ),
          );

  Future<void> upload(
    Uri url,
    Uint8List ciphertext, {
    void Function(int sent, int total)? onProgress,
  }) async {
    await _dio.putUri(
      url,
      data: Stream.fromIterable([ciphertext]),
      options: Options(
        contentType: 'application/octet-stream',
        // Content-Length is a forbidden header name under the Fetch API,
        // which dio_web_adapter uses on web — setting it explicitly there
        // throws before the request ever leaves the page, failing every
        // upload silently (caught by the caller, surfaced only as "upload
        // failed"). The browser computes it from the body itself; native
        // platforms still need it set explicitly because a bare Stream body
        // has no otherwise-known length.
        headers:
            kIsWeb
                ? null
                : {Headers.contentLengthHeader: ciphertext.length},
      ),
      onSendProgress: onProgress,
    );
  }

  Future<Uint8List> download(
    Uri url, {
    void Function(int received, int total)? onProgress,
  }) async {
    final response = await _dio.getUri<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onProgress,
    );
    return Uint8List.fromList(response.data!);
  }
}
