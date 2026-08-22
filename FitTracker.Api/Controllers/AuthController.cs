using System.Security.Claims;
using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FitTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
/// <summary>Handles authentication and user account endpoints.</summary>
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly IConfiguration _configuration;

    public AuthController(IAuthService authService, IConfiguration configuration)
    {
        _authService = authService;
        _configuration = configuration;
    }

    /// <summary>Authenticates a user and returns a JWT token.</summary>
    /// <param name="request">The login credentials.</param>
    /// <returns>An <see cref="AuthResponseDto"/> on success, or 401 Unauthorized if credentials are invalid.</returns>
    [EnableRateLimiting("auth")]
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
    [EnableRateLimiting("auth")]
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequestDto request)
    {
        // Absent means Trainee. An unrecognised value is refused rather than
        // defaulted, so a typo can't quietly produce the wrong kind of account.
        var accountType = AccountType.Trainee;
        if (!string.IsNullOrWhiteSpace(request.AccountType) &&
            !Enum.TryParse(request.AccountType, ignoreCase: true, out accountType))
        {
            return BadRequest(new
            {
                error = "unknown_account_type",
                message = $"Choose one of: {string.Join(", ", Enum.GetNames<AccountType>())}.",
            });
        }

        var result = await _authService.RegisterAsync(request.Username, request.Email, request.Password, request.FirstName, request.LastName, request.DateOfBirth, accountType);
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

    /// <summary>Requests a password reset email for the given address.</summary>
    [EnableRateLimiting("auth")]
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequestDto request)
    {
        var baseUrl = $"{Request.Scheme}://{Request.Host}";
        var resetBaseUrl = $"{baseUrl}/api/Auth/reset-password-redirect";
        await _authService.ForgotPasswordAsync(request.Email, resetBaseUrl);
        return Ok("If an account with that email exists, a reset link has been sent.");
    }

    /// <summary>
    /// Opens in the Gmail/browser Chrome Custom Tab and immediately redirects to the
    /// forgeform:// deep link so the app can handle the reset token.
    /// </summary>
    [HttpGet("reset-password-redirect")]
    [AllowAnonymous]
    public IActionResult ResetPasswordRedirect([FromQuery] string token)
    {
        var deepLink = $"forgeform://reset-password?token={Uri.EscapeDataString(token)}";
        return Redirect(deepLink);
    }

    /// <summary>Resets the user's password using a valid reset token.</summary>
    [EnableRateLimiting("auth")]
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequestDto request)
    {
        var success = await _authService.ResetPasswordAsync(request.Token, request.NewPassword);
        if (!success) return BadRequest("The reset link is invalid or has expired.");
        return Ok("Password updated successfully.");
    }

    /// <summary>Exchanges a valid refresh token for a new access token + refresh token pair.</summary>
    /// <param name="request">The refresh token to redeem.</param>
    /// <returns>An <see cref="AuthResponseDto"/> on success, or 401 Unauthorized if the refresh token is invalid, expired, or revoked.</returns>
    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh([FromBody] RefreshRequestDto request)
    {
        var result = await _authService.RefreshAsync(request.RefreshToken);
        if (result == null) return Unauthorized("The refresh token is invalid or has expired.");
        return Ok(result);
    }

    /// <summary>Revokes a refresh token so it can no longer be used to obtain new access tokens.</summary>
    /// <param name="request">The refresh token to revoke.</param>
    /// <returns>204 No Content — always succeeds even if the token was already invalid/revoked.</returns>
    [HttpPost("logout")]
    public async Task<IActionResult> Logout([FromBody] RefreshRequestDto request)
    {
        await _authService.LogoutAsync(request.RefreshToken);
        return NoContent();
    }
}