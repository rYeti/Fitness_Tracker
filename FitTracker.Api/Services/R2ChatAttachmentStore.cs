using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>
/// Cloudflare R2, spoken to entirely through its S3-compatible API. The SDK
/// never learns it isn't talking to AWS — R2's S3 endpoint, an "auto" region,
/// and SigV4 credentials are all it takes.
/// </summary>
/// <remarks>
/// Presigned URLs from this store are only valid on R2's S3 API host
/// (<c>&lt;accountId&gt;.r2.cloudflarestorage.com</c> or its <c>eu.</c>
/// jurisdiction-scoped form) — never on a custom domain, and R2 does not
/// support presigned POST, only PUT/GET/HEAD/DELETE. See
/// docs/chat-attachments.md.
/// </remarks>
public class R2ChatAttachmentStore : IChatAttachmentStore
{
    private readonly AmazonS3Client _client;
    private readonly string _bucket;

    public R2ChatAttachmentStore(string accountId, string bucket, string accessKeyId, string secretAccessKey, bool euJurisdiction)
    {
        _bucket = bucket;

        var config = new AmazonS3Config
        {
            ServiceURL = euJurisdiction
                ? $"https://{accountId}.eu.r2.cloudflarestorage.com"
                : $"https://{accountId}.r2.cloudflarestorage.com",
            ForcePathStyle = true,
            AuthenticationRegion = "auto",
        };

        _client = new AmazonS3Client(new BasicAWSCredentials(accessKeyId, secretAccessKey), config);
    }

    public bool IsConfigured => true;

    public Uri CreateUploadUrl(string objectKey, TimeSpan ttl) =>
        Presign(objectKey, ttl, HttpVerb.PUT);

    public Uri CreateDownloadUrl(string objectKey, TimeSpan ttl) =>
        Presign(objectKey, ttl, HttpVerb.GET);

    private Uri Presign(string objectKey, TimeSpan ttl, HttpVerb verb)
    {
        // GetPreSignedURL is a local SigV4 computation — no request leaves this
        // process. See IChatAttachmentStore.CreateUploadUrl for why that matters.
        var url = _client.GetPreSignedURL(new GetPreSignedUrlRequest
        {
            BucketName = _bucket,
            Key = objectKey,
            Verb = verb,
            Expires = DateTime.UtcNow.Add(ttl),
        });
        return new Uri(url);
    }

    public async Task<long?> GetObjectLengthAsync(string objectKey, CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await _client.GetObjectMetadataAsync(_bucket, objectKey, cancellationToken);
            return response.ContentLength;
        }
        catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task DeleteManyAsync(IReadOnlyList<string> objectKeys, CancellationToken cancellationToken = default)
    {
        if (objectKeys.Count == 0) return;

        // DeleteObjects takes up to 1000 keys per call; batch defensively even
        // though callers here (the reaper, retention sweeps) stay well under that.
        foreach (var batch in objectKeys.Chunk(1000))
        {
            await _client.DeleteObjectsAsync(new DeleteObjectsRequest
            {
                BucketName = _bucket,
                Objects = [.. batch.Select(k => new KeyVersion { Key = k })],
                // A key already gone (deleted by a previous pass, or never
                // existed) is not an error the reaper needs to see — deletes are
                // opportunistic by design.
                Quiet = true,
            }, cancellationToken);
        }
    }

    public async Task<IReadOnlyList<string>> ListKeysAsync(string prefix, CancellationToken cancellationToken = default)
    {
        var keys = new List<string>();
        string? continuationToken = null;

        do
        {
            var response = await _client.ListObjectsV2Async(new ListObjectsV2Request
            {
                BucketName = _bucket,
                Prefix = prefix,
                ContinuationToken = continuationToken,
            }, cancellationToken);

            keys.AddRange(response.S3Objects.Select(o => o.Key));
            continuationToken = response.IsTruncated == true ? response.NextContinuationToken : null;
        } while (continuationToken != null);

        return keys;
    }
}
