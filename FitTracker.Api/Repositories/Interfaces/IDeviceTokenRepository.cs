using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface IDeviceTokenRepository
{
    /// <summary>
    /// Records <paramref name="token"/> as belonging to <paramref name="userId"/>,
    /// moving it if another user registered it previously.
    /// </summary>
    /// <remarks>
    /// Moving rather than inserting is the whole contract. A registration token
    /// identifies an app install, so a phone that has been signed into two
    /// accounts produces the same token twice — and a second row would leave the
    /// previous user's messages being delivered to whoever holds the phone now.
    /// </remarks>
    Task<DeviceToken> UpsertAsync(Guid userId, string token, DevicePlatform platform);

    /// <summary>Every device registered to one user. Empty is normal — not every user has the app installed.</summary>
    Task<List<DeviceToken>> GetForUserAsync(Guid userId);

    /// <summary>Removes one token. Returns false when it was already gone.</summary>
    Task<bool> DeleteAsync(string token);

    /// <summary>Removes tokens FCM has rejected as dead, in one round trip.</summary>
    Task DeleteManyAsync(IEnumerable<string> tokens);
}
