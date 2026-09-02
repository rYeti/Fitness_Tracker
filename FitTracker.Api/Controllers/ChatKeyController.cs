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
/// One row per (user, device) rather than per user — a user signed in on more
/// than one device (a phone and the Trainer Console's web/desktop build, most
/// commonly) has one key per install, and registering a new one is additive:
/// it never touches another device's row. See docs/chat-encryption.md for why
/// that used not to be true and what it cost.
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
    IChatDeviceKeyRepository chatKeys,
    ITrainerClientService trainerClientService) : ControllerBase
{
    private readonly IChatDeviceKeyRepository _chatKeys = chatKeys;
    private readonly ITrainerClientService _trainerClientService = trainerClientService;

    /// <summary>The caller's own id, and every device they have published a key from.</summary>
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

        var devices = await _chatKeys.GetForUserAsync(userId.Value);

        return Ok(new ChatKeyDto
        {
            UserId = userId.Value,
            Devices = devices
                .Select(d => new ChatDeviceKeyDto { DeviceId = d.DeviceId, PublicKeyJwk = d.PublicKeyJwk })
                .ToList(),
        });
    }

    /// <summary>Publishes one device's public key.</summary>
    /// <remarks>
    /// Additive, not a replacement: registering a new device leaves every other
    /// device's row untouched, so nothing this account has already sent or
    /// received becomes unreadable anywhere else. That is the entire point —
    /// see docs/chat-encryption.md for what the single-key-per-user version of
    /// this endpoint used to cost.
    /// </remarks>
    [HttpPut("me")]
    public async Task<IActionResult> Publish([FromBody] PublishChatKeyRequestDto request)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        if (string.IsNullOrWhiteSpace(request.DeviceId))
            return BadRequest("A device id is required.");

        if (string.IsNullOrWhiteSpace(request.PublicKeyJwk))
            return BadRequest("A public key is required.");

        await _chatKeys.UpsertAsync(userId.Value, request.DeviceId.Trim(), request.PublicKeyJwk.Trim());

        return Ok(new ChatKeyDto { UserId = userId.Value });
    }

    /// <summary>The other party's registered devices and their published keys.</summary>
    /// <returns>
    /// An empty device list when they have none. The client treats that as "they
    /// have not opened the app since this shipped" and says so, rather than
    /// failing the thread.
    /// </returns>
    [HttpGet("{otherPartyId}")]
    public async Task<IActionResult> Peer(Guid otherPartyId)
    {
        var userId = GetUserId();
        if (userId is null) return Unauthorized();

        if (!await IsActivePairAsync(userId.Value, otherPartyId)) return Unauthorized();

        var devices = await _chatKeys.GetForUserAsync(otherPartyId);
        if (devices.Count == 0) return NotFound();

        return Ok(new ChatKeyDto
        {
            UserId = otherPartyId,
            Devices = devices
                .Select(d => new ChatDeviceKeyDto { DeviceId = d.DeviceId, PublicKeyJwk = d.PublicKeyJwk })
                .ToList(),
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
