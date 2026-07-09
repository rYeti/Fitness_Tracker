using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

public class ForgotPasswordRequestDto
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;
}
