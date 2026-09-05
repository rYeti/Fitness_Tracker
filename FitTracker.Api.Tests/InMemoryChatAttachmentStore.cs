using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Tests;

/// <summary>
/// A fake <see cref="IChatAttachmentStore"/> for tests: a dictionary standing
/// in for the bucket, plus counters so a test can assert something as specific
/// as "replay did not re-upload" without a real network call anywhere.
/// </summary>
public class InMemoryChatAttachmentStore : IChatAttachmentStore
{
    public readonly Dictionary<string, long> Objects = [];
    public readonly List<string> DeletedKeys = [];
    public int PutCount { get; private set; }

    public bool IsConfigured => true;

    public Uri CreateUploadUrl(string objectKey, TimeSpan ttl)
    {
        PutCount++;
        return new Uri($"https://fake-r2.test/{objectKey}?upload");
    }

    public Uri CreateDownloadUrl(string objectKey, TimeSpan ttl) =>
        new($"https://fake-r2.test/{objectKey}?download");

    /// <summary>Test setup helper — simulates the client's PUT actually landing.</summary>
    public void SeedObject(string objectKey, long byteLength) => Objects[objectKey] = byteLength;

    public Task<long?> GetObjectLengthAsync(string objectKey, CancellationToken cancellationToken = default) =>
        Task.FromResult(Objects.TryGetValue(objectKey, out var length) ? (long?)length : null);

    public Task DeleteManyAsync(IReadOnlyList<string> objectKeys, CancellationToken cancellationToken = default)
    {
        foreach (var key in objectKeys)
        {
            Objects.Remove(key);
            DeletedKeys.Add(key);
        }
        return Task.CompletedTask;
    }

    public Task<IReadOnlyList<string>> ListKeysAsync(string prefix, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<string>>([.. Objects.Keys.Where(k => k.StartsWith(prefix, StringComparison.Ordinal))]);
}
