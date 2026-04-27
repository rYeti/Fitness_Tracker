using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

/// <summary>Data-access contract for user records.</summary>
public interface IUserRepository
{
    /// <summary>
    /// Retrieves a user by their unique identifier (ID). 
    /// </summary>
    /// <param name="id"></param>
    /// <returns></returns>
    Task<User?> GetUserByIdAsync(Guid id);

    /// <summary>
    /// Retrieves a user by their email address.
    /// </summary>
    /// <param name="email"></param>
    /// <returns></returns>
    Task<User?> GetUserByEmailAsync(string email);

    /// <summary>
    /// Retrieves a user by their username.
    /// </summary>
    /// <param name="username"></param>
    /// <returns></returns>
    Task<User?> GetUserByUsernameAsync(string username);

    /// <summary>
    /// Creates a new user in the database.
    /// </summary>
    /// <param name="user"></param>
    /// <returns></returns>
    Task CreateUserAsync(User user);

    /// <summary>
    /// Updates an existing user's profile fields.
    /// </summary>
    Task UpdateUserAsync(User user);

    /// <summary>
    /// Deletes the user and all their data. Trainer-client relationships are removed first.
    /// </summary>
    Task DeleteUserAsync(Guid id);
}