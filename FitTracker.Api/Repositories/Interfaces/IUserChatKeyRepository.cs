using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface IUserChatKeyRepository
{
    /// <summary>
    /// Publishes <paramref name="deviceId"/>'s public key for <paramref name="userId"/>,
    /// replacing that device's own previous key if it had one. Never touches
    /// another device's row.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Replacing rather than rejecting a same-device republish is deliberate,
    /// unchanged from the original one-row design: a reinstall of *this*
    /// device has no way to recover its own old private key, so refusing the
    /// new public key would leave it permanently unable to send anything
    /// readable.
    /// </para>
    /// <para>
    /// When this is a genuinely new device for a user already at the device
    /// cap, the least-recently-seen existing device is evicted first — see
    /// docs/chat-multi-device-keys.md for why a cap and LRU eviction rather
    /// than an unbounded list.
    /// </para>
    /// </remarks>
    Task<UserChatKey> UpsertAsync(Guid userId, string deviceId, string publicKeyJwk);

    /// <summary>
    /// Every key this user has currently published, most-recently-seen first.
    /// Empty if they have never published one.
    /// </summary>
    Task<IReadOnlyList<UserChatKey>> GetAllAsync(Guid userId);
}
