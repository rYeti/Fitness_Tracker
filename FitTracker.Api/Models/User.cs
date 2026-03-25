namespace FitTracker.Api.Models;

public class User
{
    /// <summary>
    /// The unique identifier for the user.
    /// </summary>
    public Guid Id { get; set; }
    /// <summary>
    /// The first name of the user.
    /// </summary>
    public string FirstName { get; set; } = string.Empty;
    /// <summary>
    /// The last name of the user.
    /// </summary>
    public string LastName { get; set; } = string.Empty;

    /// <summary>
    /// The email address of the user.
    /// </summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// The username of the user, which is used for authentication and identification purposes.
    /// </summary>
    public string UserName { get; set; } = string.Empty;

    /// <summary>
    /// The hashed password of the user, which is used for authentication purposes. It is important to store passwords securely by hashing them before saving to the database.
    /// </summary>
    public string PasswordHash { get; set; } = string.Empty;

    /// <summary>
    /// The date and time when the user account was created. This property is automatically set to
    /// the current UTC date and time when a new user is created, providing a timestamp for when the account was established.
    /// </summary>
    public DateTime Created { get; set; } = DateTime.UtcNow;

}