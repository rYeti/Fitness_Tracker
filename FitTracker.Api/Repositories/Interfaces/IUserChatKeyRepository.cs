using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface IUserChatKeyRepository
{
    /// <summary>
    /// Publishes <paramref name="userId"/>'s public key, replacing any previous one.
    /// </summary>
    /// <remarks>
    /// Replacing rather than rejecting is deliberate. A reinstall has no way to
    /// recover the old private key, so refusing the new public key would leave
    /// that user permanently unable to send anything readable.
    /// </remarks>
    Task<UserChatKey> UpsertAsync(Guid userId, string publicKeyJwk);

    /// <summary>The user's current public key, or null if they have never published one.</summary>
    Task<UserChatKey?> GetAsync(Guid userId);
}
