using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

public interface IPushNotificationService
{
    /// <summary>
    /// Notifies every device <paramref name="recipientId"/> has registered that
    /// <paramref name="senderName"/> sent them a message.
    /// </summary>
    /// <param name="messageId">
    /// Travels in the payload so a device that already received the message over
    /// SignalR can recognise the notification as a duplicate of a bubble it is
    /// already showing.
    /// </param>
    /// <param name="body">
    /// The encrypted body, passed through untouched. Nothing here reads it — the
    /// recipient's device decrypts it to draw the notification.
    /// </param>
    /// <param name="threadId">
    /// The other party's id from the recipient's point of view — i.e. the sender.
    /// Travels in the payload so a tap can open the right conversation.
    /// </param>
    Task SendChatMessageAsync(Guid recipientId, string senderName, Guid messageId, EncryptedChatBody body, Guid threadId);

    /// <summary>
    /// Asks every device <paramref name="userId"/> has registered to pull, because someone
    /// else — their trainer — changed their data.
    /// </summary>
    /// <remarks>
    /// Data only, <c>{ "type": "sync_requested" }</c> and nothing else, collapsed under one
    /// key, at normal priority. The app pulls if it is open and ignores it otherwise; it
    /// never shows a notification. See docs/sync-architecture.md, part four.
    /// </remarks>
    Task SendSyncRequestedAsync(Guid userId);
}
