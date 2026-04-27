using System.Security.Claims;
using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
/// <summary>Handles authentication and user account endpoints.</summary>
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    /// <summary>Initialises a new instance of <see cref="AuthController"/>.</summary>
    /// <param name="authService">The authentication service.</param>
    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    /// <summary>Authenticates a user and returns a JWT token.</summary>
    /// <param name="request">The login credentials.</param>
    /// <returns>An <see cref="AuthResponseDto"/> on success, or 401 Unauthorized if credentials are invalid.</returns>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequestDto request)
    {
        var result = await _authService.LoginAsync(request.Username, request.Password);
        if (result == null)
        {
            return Unauthorized("Invalid username or password.");
        }

        return Ok(result);
    }


    /// <summary>Registers a new user account.</summary>
    /// <param name="request">The registration details.</param>
    /// <returns>An <see cref="AuthResponseDto"/> on success, or 400 Bad Request if registration fails.</returns>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequestDto request)
    {
        var result = await _authService.RegisterAsync(request.Username, request.Email, request.Password, request.FirstName, request.LastName, request.DateOfBirth);
        if (result == null)
        {
            return BadRequest("Registration failed. Please check the provided information.");
        }

        return Ok(result);
    }

    /// <summary>Updates the authenticated user's profile information.</summary>
    /// <param name="request">The updated profile fields.</param>
    /// <returns>An updated <see cref="AuthResponseDto"/> on success, or 404 Not Found if the user does not exist.</returns>
    [Authorize]
    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequestDto request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        if (userIdClaim == null || !Guid.TryParse(userIdClaim.Value, out var userId))
            return Unauthorized();

        var result = await _authService.UpdateProfileAsync(userId, request.FirstName, request.LastName, request.Email, request.DateOfBirth, request.ProfileImageUrl);
        if (result == null) return NotFound("User not found.");

        return Ok(result);
    }

    /// <summary>Changes the authenticated user's password.</summary>
    /// <param name="request">The current and new passwords.</param>
    /// <returns>204 No Content on success, or 400 Bad Request if the current password is incorrect.</returns>
    [Authorize]
    [HttpPut("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequestDto request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        if (userIdClaim == null || !Guid.TryParse(userIdClaim.Value, out var userId))
            return Unauthorized();

        var success = await _authService.ChangePasswordAsync(userId, request.CurrentPassword, request.NewPassword);
        if (!success) return BadRequest("Current password is incorrect.");

        return NoContent();
    }

    /// <summary>Permanently deletes the authenticated user's account and all associated data.</summary>
    /// <param name="request">The user's current password for confirmation.</param>
    /// <returns>204 No Content on success, or 400 Bad Request if the password is incorrect.</returns>
    [Authorize]
    [HttpDelete("account")]
    public async Task<IActionResult> DeleteAccount([FromBody] DeleteAccountRequestDto request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub");
        if (userIdClaim == null || !Guid.TryParse(userIdClaim.Value, out var userId))
            return Unauthorized();

        var success = await _authService.DeleteAccountAsync(userId, request.Password);
        if (!success) return BadRequest("Password is incorrect.");

        return NoContent();
    }
}