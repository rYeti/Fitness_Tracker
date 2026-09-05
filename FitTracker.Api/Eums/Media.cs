namespace FitTracker.Api.Enums;

/// <summary>
/// What kind of attachment a message carries.
/// </summary>
/// <remarks>
/// <b>Append-only, never reorder or remove a value.</b> The Dart client
/// deserialises this by ordinal (<c>MediaType.values[media]</c>), so a value
/// inserted anywhere but the end reassigns every index after it and silently
/// relabels every attachment a client has ever stored. It is also why the
/// server never writes this enum onto <c>ChatMessage.MediaType</c> — an
/// unguarded index lookup on an old, already-shipped client throws on any
/// value it doesn't know about, and the throw happens inside the loop that
/// loads a whole thread. See docs/chat-attachments.md.
/// </remarks>
public enum Media
{
    Picture,
    Video,
    Audio,
    Document,
    VoiceNote,
}
