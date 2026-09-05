import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record_pkg;
import 'package:uuid/uuid.dart';

/// What a finished recording produced: where the file landed and how long it
/// ran. Duration is tracked client-side by a stopwatch rather than asked of
/// the recorder — simpler, and correct on every platform this wraps.
class VoiceRecording {
  final String path;
  final int durationSeconds;

  const VoiceRecording({required this.path, required this.durationSeconds});
}

/// Records one voice note at a time — start/stop/cancel, with a live elapsed
/// counter. An interface, not a concrete class, so `ChatComposer`'s tests can
/// supply a fake that never touches a real microphone or platform channel.
abstract class VoiceRecorder {
  bool get isRecording;

  /// Seconds elapsed since [start], for a live "0:07" readout while
  /// recording. Zero once nothing is in progress.
  int get elapsedSeconds;

  /// Requests the mic and begins recording. Returns false (and records
  /// nothing) if permission is refused — the caller shows that as a plain
  /// message rather than a crash.
  Future<bool> start();

  /// Stops and returns the recording, or null if nothing was recording or
  /// the clip is too short to be a real voice note (below one second — a
  /// mis-tap, not a message).
  Future<VoiceRecording?> stop();

  /// Stops and discards — the user backed out mid-recording.
  Future<void> cancel();

  Future<void> dispose();
}

/// AAC/M4A — universally playable, unlike Chrome's `MediaRecorder`
/// opus/webm output (see docs/chat-attachments.md §C.1 for why web has no
/// recorder at all: an iPhone recipient could not play it back).
///
/// A thin wrapper over `package:record` rather than exposing that package's
/// API directly, so the composer deals in [start]/[stop]/[cancel] and never
/// touches permission plumbing or encoder configuration itself.
class PlatformVoiceRecorder implements VoiceRecorder {
  final record_pkg.AudioRecorder _recorder;
  static const _uuid = Uuid();

  String? _path;
  Stopwatch? _stopwatch;

  PlatformVoiceRecorder({record_pkg.AudioRecorder? recorder})
    : _recorder = recorder ?? record_pkg.AudioRecorder();

  @override
  bool get isRecording => _stopwatch != null;

  @override
  int get elapsedSeconds => _stopwatch?.elapsed.inSeconds ?? 0;

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_note_${_uuid.v4()}.m4a';
    await _recorder.start(
      const record_pkg.RecordConfig(
        encoder: record_pkg.AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      ),
      path: path,
    );
    _path = path;
    _stopwatch = Stopwatch()..start();
    return true;
  }

  @override
  Future<VoiceRecording?> stop() async {
    if (!isRecording) return null;
    final stopwatch = _stopwatch!;
    stopwatch.stop();
    final seconds = stopwatch.elapsed.inSeconds;
    final path = _path;
    _path = null;
    _stopwatch = null;

    await _recorder.stop();
    if (path == null || seconds < 1) return null;
    return VoiceRecording(path: path, durationSeconds: seconds);
  }

  @override
  Future<void> cancel() async {
    if (!isRecording) return;
    _stopwatch = null;
    _path = null;
    await _recorder.cancel();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
