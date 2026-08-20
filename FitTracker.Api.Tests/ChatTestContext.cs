using System.Data.Common;
using FitTracker.Api.Data;
using FitTracker.Api.Models;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Tests;

/// <summary>
/// A throwaway database plus the minimum rows every chat test needs: a trainer,
/// a client, and an Active relationship between them.
/// </summary>
/// <remarks>
/// Backed by Sqlite over an <b>open</b> in-memory connection. Both halves of that
/// matter:
/// <list type="bullet">
/// <item>Sqlite (rather than EFCore.InMemory) enforces foreign keys, which is the
/// only reason a test can observe that <c>ChatMessage.TrainerClientId</c> was never
/// assigned — the InMemory provider would happily persist the orphan row.</item>
/// <item>The connection is held open for the lifetime of the context: an in-memory
/// Sqlite database is destroyed when its last connection closes, so letting EF open
/// and close per-command would drop the schema between calls.</item>
/// </list>
/// The schema comes from <see cref="DatabaseFacade.EnsureCreated"/> rather than the
/// real migrations, because those are Npgsql-specific ("uuid", "timestamp with time
/// zone") and won't run on Sqlite. That means this fixture tests the EF model, not
/// the migration history — migrations are verified by the deploy running them.
/// </remarks>
public sealed class ChatTestContext : IDisposable
{
    private readonly DbConnection _connection;

    public AppDbContext Db { get; }

    public User Trainer { get; }
    public User Client { get; }
    public TrainerClient Relationship { get; }

    public Guid TrainerId => Trainer.Id;
    public Guid ClientId => Client.Id;

    public ChatTestContext()
    {
        _connection = new SqliteConnection("Filename=:memory:");
        _connection.Open();

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;

        Db = new AppDbContext(options);
        Db.Database.EnsureCreated();

        Trainer = NewUser("Dana", "Ruiz");
        Client = NewUser("Robert", "Meyer");
        Db.Users.AddRange(Trainer, Client);

        Relationship = NewRelationship(Trainer.Id, Client.Id, TrainerClientStatus.Active);
        Db.TrainerClients.Add(Relationship);

        Db.SaveChanges();
    }

    /// <summary>Adds another user, for tests that need a second client or trainer.</summary>
    public User AddUser(string firstName, string lastName)
    {
        var user = NewUser(firstName, lastName);
        Db.Users.Add(user);
        Db.SaveChanges();
        return user;
    }

    /// <summary>Adds another relationship, e.g. a second client on the same trainer's roster.</summary>
    public TrainerClient AddRelationship(
        Guid trainerId,
        Guid clientId,
        TrainerClientStatus status = TrainerClientStatus.Active)
    {
        var relationship = NewRelationship(trainerId, clientId, status);
        Db.TrainerClients.Add(relationship);
        Db.SaveChanges();
        return relationship;
    }

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

    private static User NewUser(string firstName, string lastName) => new()
    {
        Id = Guid.NewGuid(),
        FirstName = firstName,
        LastName = lastName,
        UserName = $"{firstName.ToLowerInvariant()}{Guid.NewGuid():N}",
        Email = $"{firstName.ToLowerInvariant()}{Guid.NewGuid():N}@example.test",
        PasswordHash = "not-a-real-hash",
        DateOfBirth = new DateTime(1990, 1, 1, 0, 0, 0, DateTimeKind.Utc),
    };

    private static TrainerClient NewRelationship(Guid trainerId, Guid clientId, TrainerClientStatus status) => new()
    {
        Id = Guid.NewGuid(),
        TrainerId = trainerId,
        ClientId = clientId,
        Status = status,
        InviteCode = Guid.NewGuid().ToString("N")[..8],
        ExpiresAt = DateTime.UtcNow.AddDays(7),
        AcceptedAt = status == TrainerClientStatus.Active ? DateTime.UtcNow : null,
    };

    public void Dispose()
    {
        Db.Dispose();
        _connection.Dispose();
    }
}
