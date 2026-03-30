using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

public interface IAuthService
{
    /// <summary>
    /// Registers a new user with the provided username, email, and password. 
    /// </summary>
    /// <param name="username"></param>
    /// <param name="email"></param>
    /// <param name="password"></param>
    /// <returns></returns>
    Task<AuthResponseDto?> RegisterAsync(string username, string email, string password, string firstName, string lastName);

    /// <summary>
    /// Authenticates a user with the provided username and password. 
    /// </summary>
    /// <param name="username"></param>
    /// <param name="password"></param>
    /// <returns></returns>
    Task<AuthResponseDto?> LoginAsync(string username, string password);
}