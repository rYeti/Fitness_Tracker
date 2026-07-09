using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

public class ResetPasswordRequestDto
{
    [Required, MaxLength(512)]
    public string Token { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string NewPassword { get; set; } = string.Empty;
}
