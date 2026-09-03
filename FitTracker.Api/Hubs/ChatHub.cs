using System.Security.Claims;
using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace FitTracker.Api.Hubs;

[Authorize]
public class ChatHub(
    ITrainerClientService trainerClientService,
    IChatService chatService,
    IChatPushDispatcher pushDispatcher,
    IChatAttachmentService attachmentService) : Hub
{
    private ITrainerClientService TrainerClientService { get; } = trainerClientService;
    private IChatService ChatService { get; } = chatService;
    private IChatPushDispatcher PushDispatcher { get; } = pushDispatcher;
    private IChatAttachmentService AttachmentService { get; } = attachmentService;
    private static string GroupName(Guid trainerId, Guid clientId) => $"chat:{trainerId}:{clientId}";

    /// <summary>
    /// Adds the caller's connection to the SignalR group for their chat with
    /// <paramref name="clientId"/>. Callable by either the trainer or the
    /// client side of the pair — <see cref="ITrainerClientService.ResolvePairAsync"/>
    /// figures out which one the caller is.
    /// </summary>
    public async Task JoinClientGroup(Guid clientId)
    {
        var userId = GetUserId();
        var (trainerId, actualClientId, ok) = await TrainerClientService.ResolvePairAsync(userId, clientId);

        if (!ok) throw new HubException("Not authorized for this chat.");

        await Groups.AddToGroupAsync(Context.ConnectionId, GroupName(trainerId, actualClientId));
    }

    /// <summary>
    /// Persists a message via <see cref="IChatService"/>, broadcasts it to every
    /// connection in the pair's group (including the sender), and returns it to
    /// the caller as the acknowledgement.
    /// </summary>
    /// <returns>
    /// The persisted message. **The return value is load-bearing, not a
    /// convenience.** The client generates the message id and keeps a local
    /// outbox row pending until an ack comes back; a `Task`-returning hub method
    /// completes the invocation with no result, which the client can only read as
    /// "no ack" — so it retries a message that was in fact delivered and
    /// eventually shows the sender a failure for it. Anything that changes this
    /// signature breaks sending outright. See docs/chat-architecture.md §12.
    /// </returns>
    /// <param name="body">
    /// The AES-256-GCM ciphertext, base64. This hub never sees the plaintext and
    /// has nothing it could do with it if it did — see docs/chat-encryption.md.
    /// </param>
    /// <param name="iv">The base64 IV <paramref name="body"/> was encrypted under.</param>
    /// <param name="encryptionVersion">
    /// 1 for anything a current client sends. Passed rather than inferred from
    /// "is there an IV?", so the day a second scheme exists nothing has to guess
    /// which one an old row used.
    /// </param>
    public Task<ChatMessageDto> SendMessage(
        Guid clientId,
        string body,
        Guid messageId,
        string? iv,
        int encryptionVersion) =>
        // SignalR binds hub method arguments by position AND by arity, and does
        // not fill a missing trailing argument with a default — so adding a
        // sixth parameter directly to SendMessage would not degrade for an
        // already-shipped five-argument caller, it would fail the invocation
        // outright. Nor can SendMessage be overloaded; SignalR hub methods
        // cannot be. SendMessageV2 is the only way to add attachmentIds without
        // breaking every existing client's ability to send at all. See
        // docs/chat-attachments.md §A.4.
        SendMessageV2(clientId, body, messageId, iv, encryptionVersion, attachmentIds: null);

    /// <param name="attachmentIds">
    /// Attachments this message references, each already uploaded via
    /// <c>ChatAttachmentController</c>'s mint endpoint. Committing them is
    /// best-effort and never allowed to fail the send — see
    /// <see cref="IChatAttachmentService.CommitAsync"/>.
    /// </param>
    public async Task<ChatMessageDto> SendMessageV2(
        Guid clientId,
        string body,
        Guid messageId,
        string? iv,
        int encryptionVersion,
        IReadOnlyList<Guid>? attachmentIds)
    {
        var userId = GetUserId();
        var (trainerId, actualClientId, ok) = await TrainerClientService.ResolvePairAsync(userId, clientId);
        if (!ok) throw new HubException("Not authorized for this chat.");

        var encrypted = new EncryptedChatBody(body, iv, encryptionVersion);

        var message = await ChatService.SendMessageAsync(trainerId, actualClientId, senderId: userId, messageId: messageId, encrypted);

        if (attachmentIds is { Count: > 0 })
        {
            var relationship = await TrainerClientService.GetActiveRelationshipAsync(trainerId, actualClientId);
            if (relationship != null)
            {
                await AttachmentService.CommitAsync(relationship.Id, uploaderId: userId, messageId: messageId, attachmentIds);
            }
        }

        await Clients.Group(GroupName(trainerId, actualClientId)).SendAsync("ReceiveMessage", message);

        // The pair is (trainerId, actualClientId) and the sender is userId, so
        // the recipient is simply the one that isn't. The hub has never needed to
        // name that party before — every other operation is symmetric.
        var recipientId = trainerId == userId ? actualClientId : trainerId;

        // Queued, never awaited: this returns before anything touches Google.
        // The return value below is what the client blocks on and what it reads
        // as proof of delivery, so nothing slow or third-party may sit in front
        // of it. See IChatPushDispatcher.
        //
        // The ciphertext goes out as-is. Google is handed a blob and the
        // recipient's own device decrypts it to draw the notification, which is
        // the only arrangement under which a lock-screen preview and an
        // unreadable database can both be true.
        PushDispatcher.Queue(recipientId, senderId: userId, messageId: messageId, body: encrypted);

        return message;
    }

    /// <summary>
    /// Removes the caller's connection from the SignalR group for their chat
    /// with <paramref name="clientId"/>.
    /// </summary>
    public async Task LeaveClientChat(Guid clientId)
    {
        var userId = GetUserId();
        var (trainerId, actualClientId, ok) = await TrainerClientService.ResolvePairAsync(userId, clientId);
        if (!ok) throw new HubException("Not authorized for this chat.");

        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GroupName(trainerId, actualClientId));
    }

    // Same claim handling as ChatController.GetUserId. Tokens minted by the OAuth
    // path carry the caller's id as a bare "sub" rather than as NameIdentifier, so
    // reading only the latter left the hub throwing NullReferenceException on a
    // token the controller accepted happily — one entry point working and the
    // other not, for the same signed-in user.
    private Guid GetUserId()
    {
        var claim = Context.User?.FindFirst(ClaimTypes.NameIdentifier)
                    ?? Context.User?.FindFirst("sub");

        // A HubException reaches the client as a readable message; the parse
        // failure it replaces surfaced as an opaque "an unexpected error occurred".
        if (claim == null || !Guid.TryParse(claim.Value, out var userId))
            throw new HubException("Not authorized for this chat.");

        return userId;
    }

}