using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

/// <summary>Business-logic contract for user authentication and account management.</summary>
public interface IAuthService
{
    /// <summary>
    /// Registers a new user with the provided username, email, and password. 
    /// </summary>
    /// <param name="username"></param>
    /// <param name="email"></param>
    /// <param name="password"></param>
    /// <returns></returns>
    Task<AuthResponseDto?> RegisterAsync(string username, string email, string password, string firstName, string lastName, DateTime dateOfBirth);

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
}