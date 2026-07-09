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

        return await IssueTokensAsync(user);
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

        return await IssueTokensAsync(newUser);
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

        return await IssueTokensAsync(user);
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

    /// <inheritdoc/>
    public async Task<AuthResponseDto?> RefreshAsync(string refreshToken)
    {
        if (string.IsNullOrEmpty(refreshToken)) return null;

        var tokenHash = HashToken(refreshToken);
        var existing = await _db.RefreshTokens
            .Include(t => t.User)
            .FirstOrDefaultAsync(t => t.TokenHash == tokenHash);

        if (existing == null) return null;

        if (existing.RevokedAt != null)
        {
            // A previously-rotated-out token was presented again — treat as a
            // compromise signal and revoke the whole chain for this user.
            var active = await _db.RefreshTokens
                .Where(t => t.UserId == existing.UserId && t.RevokedAt == null)
                .ToListAsync();
            foreach (var t in active) t.RevokedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
            return null;
        }

        if (existing.ExpiresAt <= DateTime.UtcNow) return null;

        var (response, newToken) = await IssueTokensInternalAsync(existing.User);

        existing.RevokedAt = DateTime.UtcNow;
        existing.ReplacedByTokenId = newToken.Id;
        await _db.SaveChangesAsync();

        return response;
    }

    /// <inheritdoc/>
    public async Task LogoutAsync(string refreshToken)
    {
        if (string.IsNullOrEmpty(refreshToken)) return;

        var tokenHash = HashToken(refreshToken);
        var existing = await _db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == tokenHash);
        if (existing == null || existing.RevokedAt != null) return;

        existing.RevokedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
    }

    /// <summary>Mints a fresh access token + refresh token pair for the given user and persists the refresh token.</summary>
    private async Task<AuthResponseDto> IssueTokensAsync(User user)
    {
        var (response, _) = await IssueTokensInternalAsync(user);
        return response;
    }

    /// <summary>Same as <see cref="IssueTokensAsync"/> but also returns the persisted <see cref="RefreshToken"/> entity, needed by <see cref="RefreshAsync"/> to link the rotation chain.</summary>
    private async Task<(AuthResponseDto Response, RefreshToken Token)> IssueTokensInternalAsync(User user)
    {
        var accessMinutes = int.TryParse(_configuration["Jwt:AccessTokenMinutes"], out var m) ? m : 60;
        var refreshDays = int.TryParse(_configuration["Jwt:RefreshTokenDays"], out var d) ? d : 30;

        var accessToken = GenerateJwtToken(user, accessMinutes);
        var rawRefreshToken = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));

        var newToken = new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            TokenHash = HashToken(rawRefreshToken),
            ExpiresAt = DateTime.UtcNow.AddDays(refreshDays),
        };
        _db.RefreshTokens.Add(newToken);
        await _db.SaveChangesAsync();

        var response = new AuthResponseDto
        {
            Token = accessToken,
            Expiration = DateTime.UtcNow.AddMinutes(accessMinutes),
            RefreshToken = rawRefreshToken,
            Username = user.UserName,
            Email = user.Email,
            FirstName = user.FirstName,
            LastName = user.LastName,
            DateOfBirth = user.DateOfBirth,
            ProfileImageUrl = user.ProfileImageUrl,
        };

        return (response, newToken);
    }

    private static string HashToken(string raw) =>
        Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(raw)));

    private string GenerateJwtToken(User user, int expireMinutes = 60)
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
            expires: DateTime.UtcNow.AddMinutes(expireMinutes),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}