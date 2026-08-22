using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for user authentication and account management.</summary>
public interface IAuthService
{
    /// <summary>
    /// Registers a new user with the provided username, email, and password.
    /// </summary>
    /// <param name="accountType">
    /// Registering as <see cref="AccountType.Trainer"/> provisions a Free licence
    /// for the new user, which is what makes them a trainer. This is the only
    /// place a licence is ever created — there is no way to convert an account
    /// afterwards.
    /// </param>
    Task<AuthResponseDto?> RegisterAsync(string username, string email, string password, string firstName, string lastName, DateTime dateOfBirth, AccountType accountType = AccountType.Trainee);

    /// <summary>
    /// Authenticates a user with the provided username and password.
    /// </summary>
    /// <param name="username"></param>
    /// <param name="password"></param>
    /// <returns></returns>
    Task<AuthResponseDto?> LoginAsync(string username, string password);

    /// <summary>
    /// Updates the profile fields of an existing user.
    /// </summary>
    Task<AuthResponseDto?> UpdateProfileAsync(Guid userId, string firstName, string lastName, string email, DateTime dateOfBirth, string? profileImageUrl);

    /// <summary>
    /// Changes the password for the given user after verifying the current password.
    /// Returns true on success, false if the current password is wrong.
    /// </summary>
    Task<bool> ChangePasswordAsync(Guid userId, string currentPassword, string newPassword);

    /// <summary>
    /// Deletes the account after verifying the password.
    /// Returns true on success, false if the password is wrong or user not found.
    /// </summary>
    Task<bool> DeleteAccountAsync(Guid userId, string password);

    /// <summary>
    /// Generates a password reset token for the user with the given email and triggers
    /// the email send. Always returns true to avoid user enumeration.
    /// </summary>
    Task<bool> ForgotPasswordAsync(string email, string resetBaseUrl);

    /// <summary>
    /// Validates the reset token and updates the user's password.
    /// Returns true on success, false if the token is invalid, expired, or already used.
    /// </summary>
    Task<bool> ResetPasswordAsync(string token, string newPassword);

    /// <summary>
    /// Exchanges a valid, unexpired refresh token for a new access token + refresh token pair
    /// (rotation — the presented refresh token is revoked). Returns null if the token is
    /// invalid, expired, or already revoked (reuse of a revoked token also revokes the
    /// user's entire refresh-token chain as a compromise signal).
    /// </summary>
    Task<AuthResponseDto?> RefreshAsync(string refreshToken);

    /// <summary>
    /// Revokes the given refresh token so it can no longer be used to obtain new access tokens.
    /// Best-effort — a no-op if the token doesn't exist or is already revoked.
    /// </summary>
    Task LogoutAsync(string refreshToken);
}