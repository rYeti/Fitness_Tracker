using FitTracker.Api.Models;
using FitTracker.Api.Data;

namespace FitTracker.Api.Tests;

/// <summary>
/// A trainer, a client, and an Active relationship between them — the minimum
/// every chat test needs — over the shared <see cref="DbFixture"/>.
/// </summary>
/// <remarks>
/// Composed onto <see cref="DbFixture"/> rather than standing up its own SQLite
/// connection, so there is one answer in this project to "how do tests get a
/// database". The provider choice matters especially here: the chat suite
/// asserts that a message is persisted, and on the InMemory provider that
/// assertion passes even when <see cref="ChatMessage.TrainerClientId"/> is never
/// assigned, because InMemory does not enforce foreign keys.
/// </remarks>
public sealed class ChatScenario : IDisposable
{
    private readonly DbFixture _fixture = new();

    public AppDbContext Db => _fixture.Db;

    public User Trainer { get; }
    public User Client { get; }
    public TrainerClient Relationship { get; }

    public Guid TrainerId => Trainer.Id;
    public Guid ClientId => Client.Id;

    public ChatScenario()
    {
        Trainer = _fixture.AddUser("Dana", "Ruiz");
        Client = _fixture.AddUser("Robert", "Meyer");
        Relationship = _fixture.AddRelationship(
            Trainer.Id, Client.Id, TrainerClientStatus.Active);
    }

    public User AddUser(string firstName, string lastName) =>
        _fixture.AddUser(firstName, lastName);

    public TrainerClient AddRelationship(
        Guid trainerId,
        Guid clientId,
        TrainerClientStatus status = TrainerClientStatus.Active) =>
        _fixture.AddRelationship(trainerId, clientId, status);

    /// <summary>Writes a message straight to the table, bypassing the service under test.</summary>
    public ChatMessage AddMessage(Guid trainerClientId, Guid senderId, string body, DateTime sentAt)
    {
        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            TrainerClientId = trainerClientId,
            SenderId = senderId,
            Body = body,
            SentAt = sentAt,
        };
        Db.ChatMessages.Add(message);
        Db.SaveChanges();
        return message;
    }

    /// <summary>Writes an attachment row straight to the table, bypassing the service under test.</summary>
    public ChatAttachment AddAttachment(
        Guid trainerClientId,
        Guid uploaderId,
        long declaredByteLength = 1024,
        DateTime? createdAt = null,
        DateTime? committedAt = null,
        Guid? messageId = null)
    {
        var attachment = new ChatAttachment
        {
            Id = Guid.NewGuid(),
            TrainerClientId = trainerClientId,
            UploaderId = uploaderId,
            ObjectKey = $"chat/{trainerClientId:N}/{Guid.NewGuid():N}",
            DeclaredByteLength = declaredByteLength,
            CreatedAt = createdAt ?? DateTime.UtcNow,
            CommittedAt = committedAt,
            MessageId = messageId,
        };
        Db.ChatAttachments.Add(attachment);
        Db.SaveChanges();
        return attachment;
    }

    public void Dispose() => _fixture.Dispose();
}
