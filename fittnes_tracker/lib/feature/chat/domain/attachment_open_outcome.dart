/// What happened when [openAttachmentExternally] handed a stored document to
/// the OS. Three cases rather than a bool: a phone with no PDF reader and a
/// genuinely broken write are different problems with different things the
/// user can do about them, and a tap that silently does nothing either way
/// is the state CLAUDE.md's "never a silent failure" rule exists to prevent.
enum AttachmentOpenOutcome {
  /// Handed off successfully — a viewer app opened (native) or a download
  /// started (web, which has no way to report success beyond that).
  opened,

  /// The device has no app registered to open this file's type.
  noHandler,

  /// Anything else: a write failure, a launch failure, a platform channel
  /// error.
  failed,
}
