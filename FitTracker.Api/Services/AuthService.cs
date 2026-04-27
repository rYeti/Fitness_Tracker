using FitTracker.Api.Data;
using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories.Interfaces;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using FitTracker.Api.Models;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

/// <summary>JWT-based implementation of <see cref="IAuthService"/>.</summary>
public class AuthService : IAuthService
{

    private readonly IUserRepository _userRepository;
    private readonly IConfiguration _configuration;
    private readonly AppDbContext _db;
    private readonly IEmailService _emailService;

    public AuthService(IUserRepository userRepository, IConfiguration configuration, AppDbContext db, IEmailService emailService)
    {
        _userRepository = userRepository;
        _configuration = configuration;
        _db = db;
        _emailService = emailService;
    }

    /// <inheritdoc/>
    public async Task<AuthResponseDto?> LoginAsync(string username, string password)
    {
        var user = await _userRepository.GetUserByUsernameAsync(username);
        if (user == null)
        {
            return null; // Return null if user is not found
        }

        var passwordValid = BCrypt.Net.BCrypt.Verify(password, user.PasswordHash);
        if (!passwordValid)
        {
            return null; // Return null if password is invalid
        }

        var expireDays = 7;
        var tokenString = GenerateJwtToken(user, expireDays);

        return new AuthResponseDto
        {
            Token = tokenString,
            Expiration = DateTime.UtcNow.AddDays(expireDays),
            Username = user.UserName,
            Email = user.Email,
            FirstName = user.FirstName,
            LastName = user.LastName,
            DateOfBirth = user.DateOfBirth,
            ProfileImageUrl = user.ProfileImageUrl,
        };
    }

    /// <inheritdoc/>
    public async Task<AuthResponseDto?> RegisterAsync(string username, string email, string password, string firstName, string lastName, DateTime dateOfBirth)
    {
        if (string.IsNullOrEmpty(username) || string.IsNullOrEmpty(email) || string.IsNullOrEmpty(password))
        {
            return null; // Return null if any of the required fields are missing
        }

        var existingUser = await _userRepository.GetUserByUsernameAsync(username);
        if (existingUser != null)
        {
            return null; // Return null if a user with the same username already exists
        }

        var userPassword = await _userRepository.GetUserByEmailAsync(email);
        if (userPassword != null)
        {
            return null; // Return null if a user with the same email already exists
        }

        var hashedPassword = BCrypt.Net.BCrypt.HashPassword(password);

        var newUser = new User
        {
            Id = Guid.NewGuid(),
            UserName = username,
            Email = email,
            PasswordHash = hashedPassword,
            FirstName = firstName,
            LastName = lastName,
            DateOfBirth = DateTime.SpecifyKind(dateOfBirth, DateTimeKind.Utc)
        };

        await _userRepository.CreateUserAsync(newUser);
        var expireDays = 7;
        var tokenString = GenerateJwtToken(newUser, expireDays);

        return new AuthResponseDto
        {
            Token = tokenString,
            Expiration = DateTime.UtcNow.AddDays(expireDays),
            Username = newUser.UserName,
            Email = newUser.Email,
            FirstName = newUser.FirstName,
            LastName = newUser.LastName,
            DateOfBirth = newUser.DateOfBirth,
            ProfileImageUrl = newUser.ProfileImageUrl,
        };
    }

    /// <inheritdoc/>
    public async Task<AuthResponseDto?> UpdateProfileAsync(Guid userId, string firstName, string lastName, string email, DateTime dateOfBirth, string? profileImageUrl)
    {
        var user = await _userRepository.GetUserByIdAsync(userId);
        if (user == null) return null;

        user.FirstName = firstName;
        user.LastName = lastName;
        user.Email = email;
        user.DateOfBirth = DateTime.SpecifyKind(dateOfBirth, DateTimeKind.Utc);
        user.ProfileImageUrl = profileImageUrl;

        await _userRepository.UpdateUserAsync(user);

        var tokenString = GenerateJwtToken(user);
        return new AuthResponseDto
        {
            Token = tokenString,
            Expiration = DateTime.UtcNow.AddDays(7),
            Username = user.UserName,
            Email = user.Email,
            FirstName = user.FirstName,
            LastName = user.LastName,
            DateOfBirth = user.DateOfBirth,
            ProfileImageUrl = user.ProfileImageUrl,
        };
    }

    /// <inheritdoc/>
    public async Task<bool> ChangePasswordAsync(Guid userId, string currentPassword, string newPassword)
    {
        var user = await _userRepository.GetUserByIdAsync(userId);
        if (user == null) return false;

        if (!BCrypt.Net.BCrypt.Verify(currentPassword, user.PasswordHash)) return false;

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(newPassword);
        await _userRepository.UpdateUserAsync(user);
        return true;
    }

    /// <inheritdoc/>
    public async Task<bool> DeleteAccountAsync(Guid userId, string password)
    {
        var user = await _userRepository.GetUserByIdAsync(userId);
        if (user == null) return false;

        if (!BCrypt.Net.BCrypt.Verify(password, user.PasswordHash)) return false;

        await _userRepository.DeleteUserAsync(userId);
        return true;
    }

    /// <inheritdoc/>
    public async Task<bool> ForgotPasswordAsync(string email, string resetBaseUrl)
    {
        var user = await _userRepository.GetUserByEmailAsync(email);
        if (user == null) return true; // return true to avoid user enumeration

        // Invalidate any existing unused tokens for this user
        var existing = await _db.PasswordResetTokens
            .Where(t => t.UserId == user.Id && t.UsedAt == null && t.ExpiresAt > DateTime.UtcNow)
            .ToListAsync();
        _db.PasswordResetTokens.RemoveRange(existing);

        var rawToken = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
        var resetToken = new PasswordResetToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Token = rawToken,
            ExpiresAt = DateTime.UtcNow.AddMinutes(15),
        };

        _db.PasswordResetTokens.Add(resetToken);
        await _db.SaveChangesAsync();

        var resetLink = $"{resetBaseUrl}?token={Uri.EscapeDataString(rawToken)}";
        await _emailService.SendPasswordResetEmailAsync(user.Email, resetLink);
        return true;
    }

    /// <inheritdoc/>
    public async Task<bool> ResetPasswordAsync(string token, string newPassword)
    {
        var resetToken = await _db.PasswordResetTokens
            .Include(t => t.User)
            .FirstOrDefaultAsync(t => t.Token == token);

        if (resetToken == null) return false;
        if (resetToken.UsedAt != null) return false;
        if (resetToken.ExpiresAt <= DateTime.UtcNow) return false;

        resetToken.User.PasswordHash = BCrypt.Net.BCrypt.HashPassword(newPassword);
        resetToken.UsedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return true;
    }

    private string GenerateJwtToken(User user, int expireDays = 7)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_configuration["Jwt:Key"]));
        var credentials = new SigningCredentials(key!, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.UniqueName, user.UserName),
            new Claim(JwtRegisteredClaimNames.Email, user.Email)
        };

        var token = new JwtSecurityToken(
            issuer: _configuration["Jwt:Issuer"],
            audience: _configuration["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddDays(expireDays),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}