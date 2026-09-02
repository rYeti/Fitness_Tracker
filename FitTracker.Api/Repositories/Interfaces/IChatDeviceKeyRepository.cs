using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface IChatDeviceKeyRepository
{
    /// <summary>
    /// Publishes one device's public key, and refreshes its <c>LastSeenAt</c> if
    /// it was already registered. Additive: a second device never touches
    /// another device's row. Also prunes the caller's own devices down to the
    /// most-recently-seen <see cref="MaxDevicesPerUser"/>, so an account that
    /// keeps reinstalling on the same phone cannot grow this table forever.
    /// </summary>
    Task<UserChatDeviceKey> UpsertAsync(Guid userId, string deviceId, string publicKeyJwk);

    /// <summary>Every device <paramref name="userId"/> currently has registered, most recently seen first.</summary>
    Task<List<UserChatDeviceKey>> GetForUserAsync(Guid userId);

    /// <summary>One (user, device) row, or null if that device was never registered or has since been pruned.</summary>
    Task<UserChatDeviceKey?> GetAsync(Guid userId, string deviceId);
}
