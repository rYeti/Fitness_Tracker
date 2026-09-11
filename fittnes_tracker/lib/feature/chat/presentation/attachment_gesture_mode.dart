import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Which gesture opens a stored photo or video full screen, and hands a
/// stored document to the OS's "Open" affordance implicitly (documents have
/// no competing single-tap action, so they never branch on this).
///
/// [pointer] (web and the three desktop targets) reserves a single
/// tap/click for whatever the tile already does there — nothing for a
/// photo, starting inline playback for a video — and uses a double
/// click/tap to expand. [touch] (Android/iOS) has no competing action once
/// an attachment is downloaded, so a single tap expands.
///
/// A platform split, not a live input-device split: sniffing
/// `PointerDeviceKind` from a mouse plugged into a tablet would change the
/// affordance mid-session with nothing on screen announcing it, and there
/// would be no way to spell that into a screen-reader semantics value the
/// way [attachmentGestureMode] not mattering to semantics does (see
/// `ChatBubble`'s `Semantics.onTap`, which is gesture-mode-independent by
/// design).
enum AttachmentGestureMode { touch, pointer }

/// Same `kIsWeb` + `defaultTargetPlatform` shape as
/// `ChatComposer._cameraAvailable`/`_micAvailable` — this repo has exactly
/// one way of asking "which kind of device is this," and a second one is
/// what would drift from it. A free function, not an injected dependency:
/// widget tests drive it with `debugDefaultTargetPlatformOverride`.
///
/// `kIsWeb` alone routes a phone's mobile browser into [pointer], matching
/// this feature's decision literally ("on web/desktop a double-click
/// expands") rather than trying to also detect touch-on-web, which Flutter
/// has no reliable static signal for.
AttachmentGestureMode attachmentGestureMode() =>
    kIsWeb ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux
        ? AttachmentGestureMode.pointer
        : AttachmentGestureMode.touch;
