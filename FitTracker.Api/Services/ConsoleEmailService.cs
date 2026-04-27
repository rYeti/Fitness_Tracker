using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class ConsoleEmailService : IEmailService
{
    public Task SendPasswordResetEmailAsync(string toEmail, string resetLink)
    {
        Console.WriteLine($"[PASSWORD RESET] To: {toEmail} | Link: {resetLink}");
        return Task.CompletedTask;
    }
}
