using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

public class ChatRepository(AppDbContext context) : IChatRepository
{
    private readonly AppDbContext _context = context;

    /// <inheritdoc/>
    async Task<ChatMessage> IChatRepository.AddMessageAsync(ChatMessage chatMessage)
    {
        // Scoped to the pair, not to the id alone. A client that lost its
        // connection resends with the original id, and returning "the row with
        // this id" without checking whose thread it belongs to would hand one
        // pair's message body back to another as if they had just written it.
        //
        // Keys are loaded on the dupe check too: a replay carries a freshly
        // re-encrypted content key (a different one — see docs/chat-encryption.md
        // on why an IV, and here a whole content key, is never reused), and the
        // caller must get back whichever wraps were actually stored, not the
        // ones it just tried to send.
        var dupeMessage = await _context.ChatMessages
            .Include(x => x.Keys)
            .FirstOrDefaultAsync(x => x.Id == chatMessage.Id && x.TrainerClientId == chatMessage.TrainerClientId);
        if (dupeMessage != null) return dupeMessage;

        var idBelongsElsewhere = await _context.ChatMessages.AnyAsync(x => x.Id == chatMessage.Id);
        if (idBelongsElsewhere)
        {
            throw new InvalidOperationException(
                "A message with this id already exists for a different trainer-client pair.");
        }

        _context.ChatMessages.Add(chatMessage);
        await _context.SaveChangesAsync();
        return chatMessage;
    }

    /// <summary>
    /// Fetches the most recent <paramref name="range"/> messages for the
    /// trainer/client pair, then reverses them into oldest-first order for
    /// display. Each message's <see cref="ChatMessage.Keys"/> is filtered down
    /// to <paramref name="deviceId"/>'s own row — never another device's wrap,
    /// even though the row for other devices exists in the same table.
    /// </summary>
    async Task<List<ChatMessage>> IChatRepository.GetChatHistoryAsync(Guid trainerId, Guid client, int range, string? deviceId)
    {
        var query = _context.ChatMessages
            .Where(c => c.TrainerClient.TrainerId == trainerId && c.TrainerClient.ClientId == client)
            .AsQueryable();

        // Left as the default empty Keys list when the caller sent no device id
        // (an old client) rather than including everything — a device this
        // server has never heard of gets no wrapped keys, the same outcome as
        // one that has none.
        if (deviceId != null)
        {
            query = query.Include(m => m.Keys.Where(k => k.DeviceId == deviceId));
        }

        var chatHistory = await query.OrderByDescending(c => c.SentAt).Take(range).ToListAsync();

        chatHistory.Reverse();
        return chatHistory;
    }

    /// <inheritdoc/>
    async Task<List<ChatConversationDto>> IChatRepository.GetConversationsAsync(Guid userId, string? deviceId)
    {
        // One query for the whole list. The last message and the unread count are
        // correlated subqueries rather than a second round trip per row, so a
        // trainer with thirty clients still costs one database call.
        //
        // Body, IV, version, epk and timestamp are fetched as separate scalar
        // subqueries instead of one projected row: scalar subqueries translate
        // identically on Npgsql and Sqlite, which keeps the tests running
        // against the same SQL shape. LastMessageId rides along too, purely so a
        // second query can resolve this device's own wrapped key without a
        // sixth correlated subquery per row.
        var rows = await _context.TrainerClients
            .Where(t => t.Status == TrainerClientStatus.Active
                        && (t.TrainerId == userId || t.ClientId == userId))
            .Select(t => new
            {
                OtherPartyId = t.TrainerId == userId ? t.ClientId!.Value : t.TrainerId,
                OtherPartyName = t.TrainerId == userId
                    ? t.Client!.FirstName + " " + t.Client.LastName
                    : t.Trainer.FirstName + " " + t.Trainer.LastName,
                LastMessageId = _context.ChatMessages
                    .Where(m => m.TrainerClientId == t.Id)
                    .OrderByDescending(m => m.SentAt)
                    .Select(m => (Guid?)m.Id)
                    .FirstOrDefault(),
                LastMessagePreview = _context.ChatMessages
                    .Where(m => m.TrainerClientId == t.Id)
                    .OrderByDescending(m => m.SentAt)
                    .Select(m => m.Body)
                    .FirstOrDefault(),
                LastMessageIv = _context.ChatMessages
                    .Where(m => m.TrainerClientId == t.Id)
                    .OrderByDescending(m => m.SentAt)
                    .Select(m => m.Iv)
                    .FirstOrDefault(),
                LastMessageEncryptionVersion = _context.ChatMessages
                    .Where(m => m.TrainerClientId == t.Id)
                    .OrderByDescending(m => m.SentAt)
                    .Select(m => m.EncryptionVersion)
                    .FirstOrDefault(),
                LastMessageEphemeralPublicKeyJwk = _context.ChatMessages
                    .Where(m => m.TrainerClientId == t.Id)
                    .OrderByDescending(m => m.SentAt)
                    .Select(m => m.EphemeralPublicKeyJwk)
                    .FirstOrDefault(),
                LastMessageAt = _context.ChatMessages
                    .Where(m => m.TrainerClientId == t.Id)
                    .OrderByDescending(m => m.SentAt)
                    .Select(m => (DateTime?)m.SentAt)
                    .FirstOrDefault(),
                // Excluding the caller's own messages matters: they were all sent
                // after the caller last read the thread, so a plain timestamp
                // comparison would report your own replies back to you as unread.
                // Written as boolean algebra rather than a conditional so it
                // becomes plain AND/OR in SQL — a CASE inside a correlated
                // aggregate is the kind of expression providers translate
                // inconsistently.
                UnreadCount = _context.ChatMessages.Count(m =>
                    m.TrainerClientId == t.Id
                    && m.SenderId != userId
                    && ((t.TrainerId == userId
                            && (t.TrainerLastReadAt == null || m.SentAt > t.TrainerLastReadAt))
                        || (t.TrainerId != userId
                            && (t.ClientLastReadAt == null || m.SentAt > t.ClientLastReadAt)))),
            })
            .ToListAsync();

        // A second round trip, not a sixth correlated subquery: this device's
        // own wrapped key for whichever message ended up as "last" in each row.
        var messageIds = rows
            .Where(r => r.LastMessageId != null)
            .Select(r => r.LastMessageId!.Value)
            .ToList();

        var keysByMessage = deviceId == null || messageIds.Count == 0
            ? new Dictionary<Guid, ChatMessageKey>()
            : await _context.ChatMessageKeys
                .Where(k => messageIds.Contains(k.MessageId) && k.DeviceId == deviceId)
                .ToDictionaryAsync(k => k.MessageId);

        return rows
            .OrderByDescending(r => r.LastMessageAt ?? DateTime.MinValue)
            .ThenBy(r => r.OtherPartyName)
            .Select(r =>
            {
                var key = r.LastMessageId != null && keysByMessage.TryGetValue(r.LastMessageId.Value, out var found)
                    ? found
                    : null;

                return new ChatConversationDto
                {
                    OtherPartyId = r.OtherPartyId,
                    OtherPartyName = r.OtherPartyName.Trim(),
                    LastMessagePreview = r.LastMessagePreview,
                    LastMessageIv = r.LastMessageIv,
                    LastMessageEncryptionVersion = r.LastMessageEncryptionVersion,
                    LastMessageEphemeralPublicKeyJwk = r.LastMessageEphemeralPublicKeyJwk,
                    LastMessageWrappedKey = key?.WrappedKey,
                    LastMessageWrappedIv = key?.WrappedIv,
                    LastMessageAt = r.LastMessageAt,
                    UnreadCount = r.UnreadCount,
                };
            })
            .ToList();
    }

    /// <inheritdoc/>
    async Task<bool> IChatRepository.MarkReadAsync(Guid userId, Guid otherPartyId, DateTime readAt)
    {
        var relationship = await _context.TrainerClients.FirstOrDefaultAsync(t =>
            t.Status == TrainerClientStatus.Active
            && ((t.TrainerId == userId && t.ClientId == otherPartyId)
                || (t.TrainerId == otherPartyId && t.ClientId == userId)));

        if (relationship == null) return false;

        // The pair shares this row, so only the caller's own column moves.
        if (relationship.TrainerId == userId)
        {
            relationship.TrainerLastReadAt = readAt;
        }
        else
        {
            relationship.ClientLastReadAt = readAt;
        }

        await _context.SaveChangesAsync();
        return true;
    }
}
