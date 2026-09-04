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

  /// The cap this feature enforces for a picture attachment. A presigned PUT
  /// cannot enforce this on its own — see docs/chat-attachments.md §0.2 — so
  /// this is a client-side refusal, not the only guard.
  static const maxImageBytes = 8 * 1024 * 1024;

  /// Same cap, for a document picked as-is (no re-encode possible).
  static const maxDocumentBytes = 8 * 1024 * 1024;

  /// Null when the result is still over [maxImageBytes] after downscaling —
  /// the caller shows "file too large" naming the cap rather than sending it.
  static Future<DownscaledImage?> forChat(Uint8List original) async {
    final codec = await ui.instantiateImageCodec(
      original,
      targetWidth: targetWidth,
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
      if (encoded.length > maxImageBytes) return null;

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
