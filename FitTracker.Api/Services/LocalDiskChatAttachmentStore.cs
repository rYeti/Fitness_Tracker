using System.Security.Cryptography;
using System.Text;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// A dev-only stand-in for R2, backed by the local filesystem. This is the one
/// place in the whole design where "bytes never pass through the API" is
/// deliberately untrue — there is no bucket to hand a client a direct URL to,
/// so this store's presigned URLs point back at this same process
/// (<c>ChatAttachmentController</c>'s <c>local</c> routes, only mapped when
/// <c>Attachments:Provider</c> is <c>local</c>). That is fine precisely because
/// this is not production: it is what lets a developer, and the Playwright
/// suite in <c>e2e/</c>, exercise a real upload/download round trip against a
/// local API with no Cloudflare account. See docs/e2e-playwright.md and
/// docs/chat-attachments.md.
/// </summary>
public class LocalDiskChatAttachmentStore : IChatAttachmentStore
{
    private readonly string _root;
    private readonly string _signingKey;
    private readonly string _baseUrl;

    /// <param name="root">Directory objects are written under. Created if missing.</param>
    /// <param name="signingKey">
    /// HMACs the local URLs this store hands out, so a URL is only usable for
    /// the key, verb and expiry it was minted for — the same shape of guarantee
    /// SigV4 gives a real presigned URL, done by hand because there is no S3
    /// service here to sign against.
    /// </param>
    /// <param name="baseUrl">This API's own base URL, e.g. <c>http://localhost:5000</c>.</param>
    public LocalDiskChatAttachmentStore(string root, string signingKey, string baseUrl)
    {
        _root = root;
        _signingKey = signingKey;
        _baseUrl = baseUrl.TrimEnd('/');
        Directory.CreateDirectory(_root);
    }

    public bool IsConfigured => true;

    public Uri CreateUploadUrl(string objectKey, TimeSpan ttl) => Sign(objectKey, ttl, "PUT");

    public Uri CreateDownloadUrl(string objectKey, TimeSpan ttl) => Sign(objectKey, ttl, "GET");

    private Uri Sign(string objectKey, TimeSpan ttl, string verb)
    {
        var expiresAt = DateTimeOffset.UtcNow.Add(ttl).ToUnixTimeSeconds();
        var signature = Hmac(verb, objectKey, expiresAt);
        return new Uri($"{_baseUrl}/api/chat/attachments/local/{Uri.EscapeDataString(objectKey)}?exp={expiresAt}&sig={signature}");
    }

    /// <summary>Verifies a token minted by <see cref="Sign"/>. The controller's
    /// local dev routes call this before touching the filesystem.</summary>
    public bool ValidateToken(string objectKey, string verb, long expiresAtUnixSeconds, string signature)
    {
        if (DateTimeOffset.UtcNow.ToUnixTimeSeconds() > expiresAtUnixSeconds) return false;

        var expected = Hmac(verb, objectKey, expiresAtUnixSeconds);
        var expectedBytes = Encoding.UTF8.GetBytes(expected);
        var actualBytes = Encoding.UTF8.GetBytes(signature);

        return expectedBytes.Length == actualBytes.Length &&
               CryptographicOperations.FixedTimeEquals(expectedBytes, actualBytes);
    }

    private string Hmac(string verb, string objectKey, long expiresAtUnixSeconds)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(_signingKey));
        var payload = Encoding.UTF8.GetBytes($"{verb}:{objectKey}:{expiresAtUnixSeconds}");
        return Convert.ToHexString(hmac.ComputeHash(payload));
    }

    /// <summary>Writes the request body to disk. Called only by the local dev
    /// PUT route, never by anything that thinks it's talking to R2.</summary>
    public async Task WriteAsync(string objectKey, Stream body, CancellationToken cancellationToken = default)
    {
        var path = PathFor(objectKey);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        await using var file = File.Create(path);
        await body.CopyToAsync(file, cancellationToken);
    }

    /// <summary>Opens the object for reading. Null if it doesn't exist — same
    /// contract as a 404 from a real download URL.</summary>
    public Stream? OpenRead(string objectKey)
    {
        var path = PathFor(objectKey);
        return File.Exists(path) ? File.OpenRead(path) : null;
    }

    public Task<long?> GetObjectLengthAsync(string objectKey, CancellationToken cancellationToken = default)
    {
        var path = PathFor(objectKey);
        return Task.FromResult<long?>(File.Exists(path) ? new FileInfo(path).Length : null);
    }

    public Task DeleteManyAsync(IReadOnlyList<string> objectKeys, CancellationToken cancellationToken = default)
    {
        foreach (var key in objectKeys)
        {
            var path = PathFor(key);
            if (File.Exists(path)) File.Delete(path);
        }
        return Task.CompletedTask;
    }

    public Task<IReadOnlyList<string>> ListKeysAsync(string prefix, CancellationToken cancellationToken = default)
    {
        var prefixPath = PathFor(prefix);
        var searchRoot = Directory.Exists(prefixPath) ? prefixPath : Path.GetDirectoryName(prefixPath) ?? _root;

        if (!Directory.Exists(searchRoot)) return Task.FromResult<IReadOnlyList<string>>([]);

        var keys = Directory.EnumerateFiles(searchRoot, "*", SearchOption.AllDirectories)
            .Select(p => Path.GetRelativePath(_root, p).Replace(Path.DirectorySeparatorChar, '/'))
            .Where(k => k.StartsWith(prefix, StringComparison.Ordinal))
            .ToList();

        return Task.FromResult<IReadOnlyList<string>>(keys);
    }

    // Every object key in this design is server-derived
    // (chat/{trainerClientId:N}/{id:N} — see ChatAttachmentService), so this
    // never resolves outside _root. Still normalized rather than trusted, since
    // a bug elsewhere handing this a client-supplied key would otherwise be a
    // path traversal onto the local filesystem.
    private string PathFor(string objectKey)
    {
        var combined = Path.GetFullPath(Path.Combine(_root, objectKey));
        if (!combined.StartsWith(Path.GetFullPath(_root), StringComparison.Ordinal))
            throw new InvalidOperationException($"Object key resolves outside the local attachment root: {objectKey}");
        return combined;
    }
}
