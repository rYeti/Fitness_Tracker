import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:ForgeForm/core/app_database.dart';
import 'package:ForgeForm/core/providers/enums.dart';
import 'package:ForgeForm/feature/chat/data/attachment_cache.dart';
import 'package:ForgeForm/feature/chat/data/attachment_store.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_api.dart';
import 'package:ForgeForm/feature/chat/data/chat_attachment_transfer.dart';
import 'package:ForgeForm/feature/chat/data/webcrypto_attachment_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/attachment_crypto.dart';
import 'package:ForgeForm/feature/chat/domain/models/thread_message.dart';

/// The four read-side states an attachment bubble can be in, plus the two
/// "nothing to fetch yet" states. Distinct from [AttachmentUploadStatus],
/// which is send-side and durable (survives an app kill) — this is read-side
/// and ephemeral, per-device, and never written to disk. See
/// docs/chat-attachments.md §C.7 for why the two ledgers are kept apart.
enum AttachmentPhase {
  /// No fetch has been attempted, and none is owed yet (a document, before
  /// the user taps it).
  notDownloaded,
  uploading,
  uploadFailed,
  downloading,
  downloadFailed,

  /// Bytes are available — either just downloaded or already in the device
  /// store — and safe to render.
  stored,

  /// Derived from the message's `sentAt` plus a store miss, or a 404/410
  /// from the download mint. Terminal: [fetch] never issues a request for an
  /// attachment already in this state.
  expired,
}

@immutable
class AttachmentState {
  final AttachmentPhase phase;
  final Uint8List? bytes;

  const AttachmentState(this.phase, {this.bytes});
}

/// Per CLAUDE.md's shared-state rule: registered at the app shell alongside
/// `ChatProvider`, not per screen — switching the active client must not
/// restart another thread's in-flight downloads.
///
/// Owns the read path for attachment bytes: the device media store (§C.4,
/// permanent, native only), the in-memory cache in front of it (all
/// platforms), and the auto-download policy (images on first paint,
/// everything else on tap).
class ChatAttachmentProvider extends ChangeNotifier {
  final ChatAttachmentApi _api;
  final ChatAttachmentTransfer _transfer;
  final AttachmentCrypto _crypto;
  final AttachmentStore _store;
  final AttachmentCache _cache;

  /// Mirrors `Attachments__RetentionDays` on the API. A blob past this many
  /// days old is gone from R2 whether or not a request would 404 — so a
  /// bubble this old must never issue one. See docs/chat-attachments.md §A.8.
  static const retentionDays = 45;

  ChatAttachmentProvider({
    ChatAttachmentApi? api,
    ChatAttachmentTransfer? transfer,
    AttachmentCrypto? crypto,
    AttachmentStore? store,
    AttachmentCache? cache,
  }) : _api = api ?? ChatAttachmentApi(),
       _transfer = transfer ?? ChatAttachmentTransfer(),
       _crypto = crypto ?? WebCryptoAttachmentCrypto(),
       _store = store ?? AttachmentStore(),
       _cache = cache ?? AttachmentCache();

  final Map<String, AttachmentState> _states = {};

  /// Attachment ids whose in-flight fetch turned out to be expired (a 404/410
  /// from the download mint), rather than merely failed.
  ///
  /// A field rather than a local captured by the fetch closure: `inFlight`
  /// de-duplicates concurrent callers behind one shared `Future` (`??=`
  /// below), but a plain local variable is only ever written by whichever
  /// caller happened to *create* that future. A second caller arriving while
  /// the first fetch is still running shares the same future and therefore
  /// the same outcome, but never sees the first caller's local — so it
  /// rendered `downloadFailed` (with a retry that can never succeed) where it
  /// should have rendered `expired`. Every caller checks this set once the
  /// shared future resolves, so the outcome no longer depends on who asked
  /// first.
  final Set<String> _expiredAttachmentIds = {};

  /// The state to render for [message]'s attachment right now. Never issues
  /// a fetch by itself — callers pair this with [ensureAutoFetched] or a
  /// tap-triggered [fetch].
  AttachmentState stateFor(ThreadMessage message) {
    final ref = message.attachment;
    if (ref == null) {
      return const AttachmentState(AttachmentPhase.notDownloaded);
    }

    // A message this device is still sending reports the send-side ledger,
    // not the read-side one — there is nothing to download yet, only
    // something still going up.
    if (message.isMine &&
        message.uploadStatus != AttachmentUploadStatus.uploaded &&
        message.uploadStatus != AttachmentUploadStatus.none) {
      return AttachmentState(
        message.uploadStatus == AttachmentUploadStatus.failed
            ? AttachmentPhase.uploadFailed
            : AttachmentPhase.uploading,
      );
    }

    final known = _states[ref.id];
    if (known != null) return known;

    if (_isExpired(message)) {
      return const AttachmentState(AttachmentPhase.expired);
    }

    return const AttachmentState(AttachmentPhase.notDownloaded);
  }

  bool _isExpired(ThreadMessage message) =>
      DateTime.now().toUtc().difference(message.timestamp.toUtc()).inDays >
      retentionDays;

  /// Images fetch the moment their bubble paints; every other kind waits for
  /// a tap ([fetch]) — a data-plan courtesy first, a Class B cost control
  /// second. See docs/chat-attachments.md §A.9 and §C.4.
  void ensureAutoFetched(ThreadMessage message, {required String threadId}) {
    final ref = message.attachment;
    if (ref == null || ref.kind != MediaType.picture) return;
    unawaited(fetch(message, threadId: threadId));
  }

  Future<void> fetch(ThreadMessage message, {required String threadId}) async {
    final ref = message.attachment;
    if (ref == null) return;

    final current = stateFor(message);
    // Expired is derived and terminal: whatever prompted this call, an
    // attachment past the retention window must never issue a request.
    // Uploading/uploadFailed means this device is still the sender and the
    // object may not exist server-side yet — nothing to download.
    if (current.phase == AttachmentPhase.stored ||
        current.phase == AttachmentPhase.downloading ||
        current.phase == AttachmentPhase.expired ||
        current.phase == AttachmentPhase.uploading ||
        current.phase == AttachmentPhase.uploadFailed) {
      return;
    }

    _states[ref.id] = const AttachmentState(AttachmentPhase.downloading);
    notifyListeners();

    // A fresh attempt (nothing already in flight for this id) starts with a
    // clean slate: a previous attempt may have marked this id expired, and if
    // this attempt fails for a different reason, that stale marking must not
    // leak into this attempt's outcome below.
    final isFreshAttempt = !_cache.inFlight.containsKey(ref.id);
    if (isFreshAttempt) _expiredAttachmentIds.remove(ref.id);

    final pending =
        _cache.inFlight[ref.id] ??= () async {
          // Guarded like every other step below it: this class's own doc
          // comment on `AttachmentStore.read` already says a miss (this
          // device never stored it, or this is web) returns null rather than
          // throwing — but a *failed* read (corrupt platform state, an I/O
          // error) previously wasn't caught at all, and sat outside every
          // other guard in this closure. Unlike a network failure, it would
          // have crashed this future before `_cache.inFlight.remove` or the
          // state update below ever ran, poisoning the id exactly the way
          // the unguarded `DioException`-only catch used to.
          Uint8List? fromStore;
          try {
            fromStore = await _store.read(ref.id);
          } catch (_) {
            fromStore = null;
          }
          if (fromStore != null) {
            _cache.put(ref.id, fromStore);
            return fromStore;
          }
          final fromCache = _cache.get(ref.id);
          if (fromCache != null) return fromCache;

          try {
            final mint = await _api.mintDownload(ref.id);
            final url = Uri.parse(mint['downloadUrl'] as String);
            final ciphertext = await _transfer.download(url);

            // Detects a swapped or truncated object before spending time
            // decrypting it — the check the manifest's `sha256` field exists
            // for and, until now, was never actually run. A mismatch is
            // treated the same as any other download failure: recoverable,
            // one retry away, not a security event worth a distinct state —
            // the realistic cause is a partial transfer, and a genuinely
            // tampered object fails the GCM tag check moments later anyway.
            final actualDigest = crypto.sha256.convert(ciphertext).toString();
            if (actualDigest != ref.sha256) return null;

            final plaintext = await _crypto.open(
              ciphertext,
              key: base64Decode(ref.key),
              iv: base64Decode(ref.iv),
            );
            if (plaintext == null) return null;

            _cache.put(ref.id, plaintext);
            unawaited(
              _store.write(
                id: ref.id,
                messageId: message.messageId,
                threadId: threadId,
                kind: ref.kind,
                bytes: plaintext,
              ),
            );
            return plaintext;
          } on DioException catch (e) {
            final code = e.response?.statusCode;
            if (code == 404 || code == 410) {
              _expiredAttachmentIds.add(ref.id);
            }
            return null;
          } catch (_) {
            // Anything else — a malformed `key`/`iv` from `base64Decode`, a
            // non-string `downloadUrl` from the mint response, a store I/O
            // error. Left uncaught, any of these escaped this closure
            // entirely: `_cache.inFlight.remove` and the state update below
            // never ran, so the bubble stuck at `downloading` forever and the
            // same rejected future was rethrown to every later caller for
            // this id. One bad attachment must cost one failed fetch, not a
            // permanently poisoned id — the same principle
            // `ChatCrypto.decrypt` already applies to a single message.
            return null;
          }
        }();
    _cache.inFlight[ref.id] = pending;

    final bytes = await pending;
    _cache.inFlight.remove(ref.id);

    // Checked here, after the shared future resolves, rather than via a local
    // the closure above captured — a second caller arriving while the first
    // fetch is still in flight shares that same future via `inFlight`'s
    // `??=`, but never saw the first caller's local variable. `contains`
    // rather than `remove`: every caller sharing this future must see the
    // same answer, and removing on the first read would make the second
    // reader miss it. The entry is cleared instead at the start of the next
    // fresh attempt, above.
    final expired = _expiredAttachmentIds.contains(ref.id);

    _states[ref.id] =
        bytes == null
            ? AttachmentState(
              expired ? AttachmentPhase.expired : AttachmentPhase.downloadFailed,
            )
            : AttachmentState(AttachmentPhase.stored, bytes: bytes);
    notifyListeners();
  }
}
