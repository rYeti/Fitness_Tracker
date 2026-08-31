using System.Security.Claims;
using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>
/// Where devices publish the public half of their chat identity, and look up
/// each other's.
/// </summary>
/// <remarks>
/// <para>
/// Only public keys pass through here. The private half is generated on the
/// device and never sent, which is what makes the bodies in
/// <c>ChatMessages</c> unreadable to this server rather than merely
/// inconvenient to read. See docs/chat-encryption.md.
/// </para>
/// <para>
/// The lookup is gated on an Active trainer-client relationship, exactly like
/// every other endpoint that exposes one user to another. A public key is not
/// secret, but "who is this user and do they exist" is still an answer this API
/// does not hand to strangers.
/// </para>
/// </remarks>
[ApiController]
[Route("api/chat/keys")]
[Authorize]
public class ChatKeyController(
    IUserChatKeyRepository chatKeys,
    ITrainerClientService trainerClientService) : ControllerBase
{
    private readonly IUserChatKeyRepository _chatKeys = chatKeys;
    private readonly ITrainerClientService _trainerClientService = trainerClientService;

    /// <summary>The caller's own id, and their published key if they have one.</summary>
    /// <remarks>
    /// The id is the load-bearing half of this response. The Flutter client has
    /// no user id of its own — see docs/chat-architecture.md §5 — and the key
    /// store needs one to tell its own identity key from the one belonging to
    /// whoever was signed in on this device last. Asking is the only way to get
    /// it.
    /// </remarks>
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        var key = await _chatKeys.GetAsync(userId.Value);

        return Ok(new ChatKeyDto
        {
            UserId = userId.Value,
            PublicKeyJwk = key?.PublicKeyJwk,
        });
    }

    /// <summary>Publishes the caller's public key, replacing any previous one.</summary>
    /// <remarks>
    /// Replacing rather than rejecting a second registration is deliberate. A
    /// reinstall cannot recover the old private key, so refusing the new public
    /// key would leave that user permanently unable to send anything the other
    /// side could read. The cost — that their older messages stop being
    /// decryptable — is the documented price of having no key backup.
    /// </remarks>
    [HttpPut("me")]
    public async Task<IActionResult> Publish([FromBody] PublishChatKeyRequestDto request)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.PublicKeyJwk))
            return BadRequest("A public key is required.");

        await _chatKeys.UpsertAsync(userId.Value, request.PublicKeyJwk.Trim());

        return Ok(new ChatKeyDto { UserId = userId.Value });
    }

    /// <summary>The other party's published key.</summary>
    /// <returns>
    /// 404 when they have never published one. The client treats that as "they
    /// have not opened the app since this shipped" and says so, rather than
    /// failing the thread.
    /// </returns>
    [HttpGet("{otherPartyId}")]
    public async Task<IActionResult> Peer(Guid otherPartyId)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        if (!await IsActivePairAsync(userId.Value, otherPartyId)) return Unauthorized();

        var key = await _chatKeys.GetAsync(otherPartyId);
        if (key == null) return NotFound();

        return Ok(new ChatKeyDto
        {
            UserId = otherPartyId,
            PublicKeyJwk = key.PublicKeyJwk,
        });
    }

    private Guid? GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        return claim != null && Guid.TryParse(claim.Value, out var id) ? id : null;
    }

    // Same two-probe resolution ChatController and ChatHub use: the caller may
    // be either side of the pair, and one code path has to serve both.
    private async Task<bool> IsActivePairAsync(Guid userId, Guid otherPartyId) =>
        await _trainerClientService.IsActiveTrainerOfAsync(userId, otherPartyId)
        || await _trainerClientService.IsActiveTrainerOfAsync(otherPartyId, userId);
}
