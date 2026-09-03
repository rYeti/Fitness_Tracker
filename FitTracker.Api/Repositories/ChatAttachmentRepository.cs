using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

public class ChatAttachmentRepository(AppDbContext context) : IChatAttachmentRepository
{
    private readonly AppDbContext _context = context;

    /// <inheritdoc/>
    public async Task<ChatAttachment> MintOrGetAsync(ChatAttachment attachment)
    {
        var existing = await _context.ChatAttachments.FirstOrDefaultAsync(a => a.Id == attachment.Id);
        if (existing != null)
        {
            if (existing.TrainerClientId != attachment.TrainerClientId || existing.UploaderId != attachment.UploaderId)
            {
                throw new InvalidOperationException(
                    "An attachment with this id already exists for a different trainer-client pair or uploader.");
            }
            return existing;
        }

        _context.ChatAttachments.Add(attachment);
        await _context.SaveChangesAsync();
        return attachment;
    }

    /// <inheritdoc/>
    public Task<ChatAttachment?> FindAsync(Guid id) =>
        // TrainerClient included so the caller can check membership/Active
        // status against the pair this attachment actually belongs to, without
        // the request having to state which party it's asking about — the
        // attachment id is self-sufficient.
        _context.ChatAttachments.Include(a => a.TrainerClient).FirstOrDefaultAsync(a => a.Id == id);

    /// <inheritdoc/>
    public async Task<IReadOnlyList<Guid>> CommitAsync(Guid trainerClientId, Guid uploaderId, Guid messageId, IReadOnlyList<Guid> attachmentIds)
    {
        if (attachmentIds.Count == 0) return [];

        var rows = await _context.ChatAttachments
            .Where(a => attachmentIds.Contains(a.Id)
                        && a.TrainerClientId == trainerClientId
                        && a.UploaderId == uploaderId
                        && a.CommittedAt == null)
            .ToListAsync();

        if (rows.Count == 0) return [];

        var committedAt = DateTime.UtcNow;
        foreach (var row in rows)
        {
            row.CommittedAt = committedAt;
            row.MessageId = messageId;
        }
        await _context.SaveChangesAsync();

        return [.. rows.Select(r => r.Id)];
    }

    /// <inheritdoc/>
    public Task<List<ChatAttachment>> FindOrphanedAsync(DateTime olderThan) =>
        _context.ChatAttachments
            .Where(a => a.CommittedAt == null && a.CreatedAt < olderThan)
            .ToListAsync();

    /// <inheritdoc/>
    public async Task DeleteRowsAsync(IReadOnlyList<Guid> ids, CancellationToken cancellationToken = default)
    {
        if (ids.Count == 0) return;
        await _context.ChatAttachments.Where(a => ids.Contains(a.Id)).ExecuteDeleteAsync(cancellationToken);
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<string>> FindKnownObjectKeysAsync(IReadOnlyList<string> objectKeys)
    {
        if (objectKeys.Count == 0) return [];
        return await _context.ChatAttachments
            .Where(a => objectKeys.Contains(a.ObjectKey))
            .Select(a => a.ObjectKey)
            .ToListAsync();
    }
}
