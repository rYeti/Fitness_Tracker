using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs.Validation;

/// <summary>
/// Validates that a string is either empty or an absolute "https" URL.
/// Rejects other schemes (http, javascript, data, file, content, etc.) and
/// link-local/loopback hosts to guard against SSRF and script-injection via
/// user-supplied image URLs.
/// </summary>
public class HttpsUrlAttribute : ValidationAttribute
{
    protected override ValidationResult? IsValid(object? value, ValidationContext validationContext)
    {
        if (value is not string url || string.IsNullOrWhiteSpace(url))
        {
            return ValidationResult.Success;
        }

        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps)
        {
            return new ValidationResult("URL must be an absolute https:// URL.");
        }

        if (Uri.CheckHostName(uri.Host) != UriHostNameType.Dns)
        {
            return new ValidationResult("URL host must be a domain name, not an IP address.");
        }

        return ValidationResult.Success;
    }
}
