using System.Security.Claims;
using FitTracker.Api.DTOs;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>
/// Mints presigned URLs for chat attachment blobs. Never touches a byte of the
/// attachment itself outside the <c>local</c> dev provider — see
/// docs/chat-attachments.md.
/// </summary>
[ApiController]
[Route("api/chat")]
[Authorize]
public class ChatAttachmentController(IChatAttachmentService attachmentService, IServiceProvider services) : ControllerBase
{
    private readonly IChatAttachmentService _attachmentService = attachmentService;
    private readonly IServiceProvider _services = services;

    /// <summary>Whether a client should show the attach affordance at all.</summary>
    [HttpGet("attachments/capabilities")]
    public IActionResult Capabilities() => Ok(_attachmentService.GetCapabilities());

    /// <param name="otherPartyId">The other side of the thread this attachment is for.</param>
    [HttpPost("{otherPartyId}/attachments")]
    public async Task<IActionResult> MintUpload(Guid otherPartyId, [FromBody] MintUploadRequestDto request)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        var result = await _attachmentService.MintUploadAsync(
            userId.Value, otherPartyId, request.AttachmentId, request.ByteLength, request.Kind);

        return result.Outcome switch
        {
            MintUploadOutcome.Ok => Ok(result.Response),
            MintUploadOutcome.NotAuthorized => Unauthorized(),
            MintUploadOutcome.TooLarge => BadRequest(new { error = "attachment_too_large" }),
            MintUploadOutcome.IdBelongsElsewhere => Conflict(new { error = "attachment_id_in_use" }),
            _ => StatusCode(500),
        };
    }

    [HttpGet("attachments/{attachmentId}/url")]
    public async Task<IActionResult> MintDownload(Guid attachmentId)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        var result = await _attachmentService.MintDownloadAsync(userId.Value, attachmentId);

        return result.Outcome switch
        {
            MintDownloadOutcome.Ok => Ok(result.Response),
            MintDownloadOutcome.NotAuthorized => Unauthorized(),
            MintDownloadOutcome.Missing => NotFound(new { error = "attachment_missing" }),
            MintDownloadOutcome.Rejected => StatusCode(410, new { error = "attachment_rejected" }),
            _ => StatusCode(500),
        };
    }

    // ── Dev/E2E only, below this line ───────────────────────────────────────
    //
    // Only reachable when Attachments:Provider is "local" — LocalDiskChatAttachmentStore
    // is resolved from the service provider directly (rather than injected)
    // so an unregistered store 404s these two routes without breaking every
    // other action on this controller in production. See
    // LocalDiskChatAttachmentStore's own remarks for why "bytes never pass
    // through the API" is deliberately not true here.

    [HttpPut("attachments/local/{*objectKey}")]
    [AllowAnonymous] // authorized by the HMAC token in the URL, not the caller's session
    public async Task<IActionResult> PutLocal(string objectKey, [FromQuery] long exp, [FromQuery] string sig)
    {
        var localStore = _services.GetService<LocalDiskChatAttachmentStore>();
        if (localStore == null) return NotFound();

        if (!localStore.ValidateToken(objectKey, "PUT", exp, sig)) return Forbid();

        await localStore.WriteAsync(objectKey, Request.Body);
        return Ok();
    }

    [HttpGet("attachments/local/{*objectKey}")]
    [AllowAnonymous]
    public IActionResult GetLocal(string objectKey, [FromQuery] long exp, [FromQuery] string sig)
    {
        var localStore = _services.GetService<LocalDiskChatAttachmentStore>();
        if (localStore == null) return NotFound();

        if (!localStore.ValidateToken(objectKey, "GET", exp, sig)) return Forbid();

        var stream = localStore.OpenRead(objectKey);
        if (stream == null) return NotFound();

        return File(stream, "application/octet-stream");
    }

    private Guid? GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        return claim != null && Guid.TryParse(claim.Value, out var id) ? id : null;
    }
}
