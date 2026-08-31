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
        var dupeMessage = await _context.ChatMessages.FirstOrDefaultAsync(
            x => x.Id == chatMessage.Id && x.TrainerClientId == chatMessage.TrainerClientId);
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

    /// <summary>Fetches the most recent <paramref name="range"/> messages for the trainer/client pair, then reverses them into oldest-first order for display.</summary>
    async Task<List<ChatMessage>> IChatRepository.GetChatHistoryAsync(Guid trainerId, Guid client, int range)
    {
        var chatHistory = await _context.ChatMessages.Where(c => c.TrainerClient.TrainerId == trainerId && c.TrainerClient.ClientId == client).OrderByDescending(c => c.SentAt).Take(range).ToListAsync();

        chatHistory.Reverse();
        return chatHistory;
    }

    /// <inheritdoc/>
    async Task<List<ChatConversationDto>> IChatRepository.GetConversationsAsync(Guid userId)
    {
        // One query for the whole list. The last message and the unread count are
        // correlated subqueries rather than a second round trip per row, so a
        // trainer with thirty clients still costs one database call.
        //
        // Body, IV, version and timestamp are fetched as separate scalar
        // subqueries instead of one projected row: scalar subqueries translate
        // identically on Npgsql and Sqlite, which keeps the tests running
        // against the same SQL shape.
        //
        // Note what is *not* here any more: a preview. The body is ciphertext
        // from EncryptionVersion 1 onward, so there is nothing to truncate and
        // nothing to read. This query moves it; the client decrypts it.
        var rows = await _context.TrainerClients
            .Where(t => t.Status == TrainerClientStatus.Active
                        && (t.TrainerId == userId || t.ClientId == userId))
            .Select(t => new
            {
                OtherPartyId = t.TrainerId == userId ? t.ClientId!.Value : t.TrainerId,
                OtherPartyName = t.TrainerId == userId
                    ? t.Client!.FirstName + " " + t.Client.LastName
                    : t.Trainer.FirstName + " " + t.Trainer.LastName,
                LastMessagePreview = _context.ChatMessages
                    .Where(m => m.TrainerClientId == t.Id)
                    .OrderByDescending(m => m.SentAt)
                    .Select(m => m.Body)
                    .FirstOrDefault(),
                // The IV and version ride along as two more scalar subqueries
                // for the same reason the body does. They are useless apart: the
                // client cannot decrypt the preview without the IV, and cannot
                // know whether to try without the version.
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

        return rows
            .OrderByDescending(r => r.LastMessageAt ?? DateTime.MinValue)
            .ThenBy(r => r.OtherPartyName)
            .Select(r => new ChatConversationDto
            {
                OtherPartyId = r.OtherPartyId,
                OtherPartyName = r.OtherPartyName.Trim(),
                LastMessagePreview = r.LastMessagePreview,
                LastMessageIv = r.LastMessageIv,
                LastMessageEncryptionVersion = r.LastMessageEncryptionVersion,
                LastMessageAt = r.LastMessageAt,
                UnreadCount = r.UnreadCount,
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
