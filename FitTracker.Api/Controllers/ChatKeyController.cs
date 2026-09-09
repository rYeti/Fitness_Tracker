using System.Security.Claims;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
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

    /// <summary>The caller's own id, and every device's published key.</summary>
    /// <remarks>
    /// The id is the load-bearing half of this response for a client that
    /// predates device ids. The Flutter client has no user id of its own — see
    /// docs/chat-architecture.md §5 — and the key store needs one to tell its
    /// own identity key from the one belonging to whoever was signed in on
    /// this device last. Asking is the only way to get it.
    /// <para>
    /// <see cref="ChatKeyDto.Devices"/> is what a client that knows about
    /// multi-device keys actually reads: it needs its own device's row to
    /// still be present with a matching key, or it must republish — see
    /// `ChatKeyStore.ensureRegistered`'s comparison, which the original,
    /// single-key version of this endpoint made impossible to write, because
    /// there was no way to tell "the server has no key" from "the server has
    /// someone else's."
    /// </para>
    /// </remarks>
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        var keys = await _chatKeys.GetAllAsync(userId.Value);

        return Ok(ToDto(userId.Value, keys));
    }

    /// <summary>
    /// Publishes the caller's public key for one device, replacing that
    /// device's own previous key if it had one.
    /// </summary>
    /// <remarks>
    /// Replacing rather than rejecting a same-device republish is deliberate,
    /// unchanged from this endpoint's original behaviour: a reinstall of that
    /// device cannot recover its own old private key, so refusing the new
    /// public key would leave it permanently unable to send anything the
    /// other side could read. The cost — that device's older messages stop
    /// being decryptable — is the documented price of having no key backup.
    /// <para>
    /// What changed is the blast radius: this used to replace the *user's*
    /// only key, so signing in on a second device silently discarded the
    /// first device's — the first device kept sending, unreadably, and the
    /// peer's own recovery path eventually discarded the first device's key
    /// from its own cache too, taking the conversation's history with it. A
    /// device with no <see cref="PublishChatKeyRequestDto.DeviceId"/> at all
    /// (a client built before this existed) publishes under
    /// <see cref="UserChatKey.LegacyDeviceId"/> instead, which
    /// reproduces the original single-row behaviour exactly for builds that
    /// predate this endpoint's change — see docs/chat-multi-device-keys.md.
    /// </para>
    /// </remarks>
    [HttpPut("me")]
    public async Task<IActionResult> Publish([FromBody] PublishChatKeyRequestDto request)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.PublicKeyJwk))
            return BadRequest("A public key is required.");

        var deviceId = string.IsNullOrWhiteSpace(request.DeviceId)
            ? UserChatKey.LegacyDeviceId
            : request.DeviceId.Trim();

        await _chatKeys.UpsertAsync(userId.Value, deviceId, request.PublicKeyJwk.Trim());

        return Ok(new ChatKeyDto { UserId = userId.Value });
    }

    /// <summary>The other party's published key(s).</summary>
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

        var keys = await _chatKeys.GetAllAsync(otherPartyId);
        if (keys.Count == 0) return NotFound();

        return Ok(ToDto(otherPartyId, keys));
    }

    /// <summary>
    /// <see cref="ChatKeyDto.PublicKeyJwk"/> carries the most-recently-seen
    /// device's key — the exact single value this endpoint always returned,
    /// before any device existed to distinguish — so a client built before
    /// multi-device keys behaves exactly as it always did.
    /// </summary>
    private static ChatKeyDto ToDto(Guid userId, IReadOnlyList<UserChatKey> keys) => new()
    {
        UserId = userId,
        PublicKeyJwk = keys.Count == 0 ? null : keys[0].PublicKeyJwk,
        Devices = [.. keys.Select(k => new ChatKeyDeviceDto
        {
            DeviceId = k.DeviceId,
            PublicKeyJwk = k.PublicKeyJwk,
        })],
    };

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
