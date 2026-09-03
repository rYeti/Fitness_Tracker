import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_api.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_file.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_transfer.dart';
import 'package:ForgeForm/feature/chat/data/webcrypto_attachment_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/attachment_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/models/chat_attachment_ref.dart';

/// What sealing one attachment produces: the manifest entry, and — native
/// platforms only — where its ciphertext was written so an interrupted
/// upload can resume from disk instead of from memory that a killed app no
/// longer has. See docs/chat-attachments.md §B.4.
class SealedAttachmentResult {
  final ChatAttachmentRef ref;
  final Uint8List ciphertext;
  final String? localPath;

  const SealedAttachmentResult({required this.ref, required this.ciphertext, this.localPath});
}

/// Prepares an attachment for sending and drives its upload.
///
/// Two separate operations, deliberately: [seal] is fast, local, and pure —
/// it never touches the network, so it can run the instant a file is picked,
/// before the outbox row that references it even exists. [upload] is the
/// slow, network-bound half, meant to run *after* the caller has durably
/// recorded the attachment in the outbox — see docs/chat-attachments.md §B.4
/// for why that ordering is what makes a kill mid-upload recoverable.
class ChatAttachmentSender {
  final AttachmentCrypto _crypto;
  final ChatAttachmentApi _api;
  final ChatAttachmentTransfer _transfer;

  static const _uuid = Uuid();

  ChatAttachmentSender({
    AttachmentCrypto? crypto,
    ChatAttachmentApi? api,
    ChatAttachmentTransfer? transfer,
  }) : _crypto = crypto ?? WebCryptoAttachmentCrypto(),
       _api = api ?? ChatAttachmentApi(),
       _transfer = transfer ?? ChatAttachmentTransfer();

  /// Encrypts [plaintext] under a fresh random key, hashes the ciphertext,
  /// and — on every platform but web — writes it to a temp file so it
  /// survives an app restart before the upload finishes.
  Future<SealedAttachmentResult> seal({
    required Uint8List plaintext,
    required MediaType kind,
    required String mime,
    required String name,
    int? width,
    int? height,
    String? avgColor,
    int? durationSeconds,
    ChatAttachmentThumbRef? thumb,
  }) async {
    final id = _uuid.v4();
    final sealed = await _crypto.seal(plaintext);
    final digest = crypto.sha256.convert(sealed.ciphertext).toString();

    final ref = ChatAttachmentRef(
      id: id,
      kind: kind,
      mime: mime,
      name: name,
      size: plaintext.length,
      key: base64Encode(sealed.key),
      iv: base64Encode(sealed.iv),
      sha256: digest,
      width: width,
      height: height,
      avgColor: avgColor,
      durationSeconds: durationSeconds,
      thumb: thumb,
    );

    final localPath = await _writeToTempFile(id, sealed.ciphertext);
    return SealedAttachmentResult(ref: ref, ciphertext: sealed.ciphertext, localPath: localPath);
  }

  /// Mints a presigned URL for [ref] against the thread with [otherPartyId]
  /// and PUTs [ciphertext] to it. Idempotent on [ref.id] — a retry (manual,
  /// or [ChatRepository.resumeAttachmentUploads] after a restart) mints
  /// against the same object key and simply overwrites it.
  Future<void> upload({
    required String otherPartyId,
    required ChatAttachmentRef ref,
    required Uint8List ciphertext,
    void Function(int sent, int total)? onProgress,
  }) async {
    final mint = await _api.mintUpload(
      otherPartyId: otherPartyId,
      attachmentId: ref.id,
      byteLength: ciphertext.length,
      kind: ref.kind,
    );
    final uploadUrl = Uri.parse(mint['uploadUrl'] as String);
    await _transfer.upload(uploadUrl, ciphertext, onProgress: onProgress);
  }

  /// Re-reads a previously-sealed attachment's ciphertext from its temp file
  /// — the resume path after an app restart. Null on web (nothing was ever
  /// written) or if the file has since been cleaned up.
  Future<Uint8List?> readSealedBytes(String localPath) => readAttachmentBytes(localPath);

  Future<void> deleteSealedBytes(String localPath) => deleteAttachmentFile(localPath);

  Future<String?> _writeToTempFile(String id, Uint8List bytes) async {
    if (kIsWeb) return null;
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/chat_attachment_$id.bin';
      await writeAttachmentBytes(path, bytes);
      return path;
    } catch (_) {
      // A file we can't write is a resume opportunity lost, not a reason to
      // fail the send — the upload still proceeds from the bytes in memory.
      return null;
    }
  }
}
