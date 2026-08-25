namespace FitTracker.Api.Services.Interfaces;

public interface IPushNotificationService
{
    /// <summary>
    /// Notifies every device <paramref name="recipientId"/> has registered that
    /// <paramref name="senderName"/> sent them a message.
    /// </summary>
    /// <param name="threadId">
    /// The other party's id from the recipient's point of view — i.e. the sender.
    /// Travels in the payload so a tap can open the right conversation.
    /// </param>
    Task SendChatMessageAsync(Guid recipientId, string senderName, string? body, Guid threadId);
}
