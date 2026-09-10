import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// A downscaled, re-encoded photo ready to seal and upload.
class DownscaledImage {
  final Uint8List bytes;
  final int width;
  final int height;

  /// A single average colour ("#8a7f6e") — the manifest's inline placeholder,
  /// rendered at the right aspect ratio while the real bytes are still
  /// downloading. See docs/chat-attachments.md §B.1.
  final String avgColor;

  const DownscaledImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.avgColor,
  });
}

/// Resizes and re-encodes a picked photo before it is sealed and uploaded.
///
/// `dart:ui` does the expensive half — decoding a 12 MP JPEG — natively, and
/// on web off the main thread; `package:image` only ever sees the
/// already-downsampled RGBA buffer and re-encodes it as JPEG. Encoding
/// straight to PNG would make a "downscale to fit the cap" step *increase*
/// the file size: `ui.Image.toByteData` supports only rawRgba and png, and a
/// 1600x1200 PNG of a photograph runs 3-5 MB against a source JPEG a fraction
/// of that. See docs/chat-attachments.md §C.2.
class ImageDownscale {
  ImageDownscale._();

  static const targetWidth = 1600;
  static const jpegQuality = 82;

  /// Null when the result is still over [maxPlaintextBytes] after downscaling —
  /// the caller shows "file too large" naming the cap rather than sending it.
  ///
  /// [maxPlaintextBytes] is the *plaintext* cap, which is the server's
  /// ciphertext cap minus AES-GCM's 16-byte tag — see
  /// `ChatAttachmentCapabilities.plaintextCapFor`. It is a parameter rather
  /// than a constant because the server reports its own caps and is the only
  /// thing that actually enforces them; a second copy of the number here is a
  /// second thing to keep in step.
  static Future<DownscaledImage?> forChat(
    Uint8List original, {
    required int maxPlaintextBytes,
  }) async {
    // Never upscale. `instantiateImageCodec` with a targetWidth larger than
    // the source resamples *up*, and re-encoding a 600px screenshot at 1600px
    // JPEG q82 produces a file several times larger than the original — for a
    // picture with no more detail in it, and one that much closer to the cap.
    final probe = await ui.instantiateImageCodec(original);
    final probeFrame = await probe.getNextFrame();
    final sourceWidth = probeFrame.image.width;
    probeFrame.image.dispose();

    final codec = await ui.instantiateImageCodec(
      original,
      targetWidth: sourceWidth > targetWidth ? targetWidth : null,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      final decoded = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: byteData.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      final encoded = Uint8List.fromList(
        img.encodeJpg(decoded, quality: jpegQuality),
      );
      if (encoded.length > maxPlaintextBytes) return null;

      return DownscaledImage(
        bytes: encoded,
        width: image.width,
        height: image.height,
        avgColor: _averageColorHex(decoded),
      );
    } finally {
      image.dispose();
    }
  }

  /// Sampled on a coarse grid rather than every pixel — a placeholder colour
  /// doesn't need per-pixel precision, and this keeps the cost negligible
  /// even against a full-resolution decode.
  static String _averageColorHex(img.Image image) {
    const step = 17;
    var r = 0, g = 0, b = 0, count = 0;
    for (var y = 0; y < image.height; y += step) {
      for (var x = 0; x < image.width; x += step) {
        final pixel = image.getPixel(x, y);
        r += pixel.r.toInt();
        g += pixel.g.toInt();
        b += pixel.b.toInt();
        count++;
      }
    }
    if (count == 0) return '#808080';
    r ~/= count;
    g ~/= count;
    b ~/= count;
    final hex = ((r << 16) | (g << 8) | b).toRadixString(16).padLeft(6, '0');
    return '#$hex';
  }
}
