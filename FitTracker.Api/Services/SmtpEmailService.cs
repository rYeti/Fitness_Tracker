using FitTracker.Api.Services.Interfaces;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace FitTracker.Api.Services;

public class SmtpEmailService : IEmailService
{
    private readonly IConfiguration _config;
    private readonly ILogger<SmtpEmailService> _logger;

    /// <inheritdoc/>
    public SmtpEmailService(IConfiguration config, ILogger<SmtpEmailService> logger)
    {
        _config = config;
        _logger = logger;
    }

    /// <inheritdoc/>
    public async Task SendPasswordResetEmailAsync(string toEmail, string resetLink)
    {
        var host     = _config["Smtp:Host"]     ?? throw new InvalidOperationException("Smtp:Host is not configured.");
        var port     = int.Parse(_config["Smtp:Port"] ?? "587");
        var user     = _config["Smtp:Username"] ?? throw new InvalidOperationException("Smtp:Username is not configured.");
        var password = _config["Smtp:Password"] ?? throw new InvalidOperationException("Smtp:Password is not configured.");
        var from     = _config["Smtp:From"]     ?? user;
        var fromName = _config["Smtp:FromName"] ?? "ForgeForm";

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(fromName, from));
        message.To.Add(MailboxAddress.Parse(toEmail));
        message.Subject = "Reset your ForgeForm password";

        message.Body = new TextPart("html")
        {
            Text = $"""
                <div style="font-family:sans-serif;max-width:480px;margin:auto">
                  <h2 style="color:#FF6B3E">Reset your password</h2>
                  <p>We received a request to reset the password for your ForgeForm account.</p>
                  <p>Click the button below within <strong>15 minutes</strong> to choose a new password:</p>
                  <p style="text-align:center;margin:32px 0">
                    <a href="{resetLink}"
                       style="background:#FF6B3E;color:#fff;padding:14px 28px;border-radius:8px;
                              text-decoration:none;font-weight:bold;font-size:15px">
                      Reset password
                    </a>
                  </p>
                  <p style="color:#888;font-size:13px">
                    If you didn't request this, you can safely ignore this email.
                    The link expires after 15 minutes.
                  </p>
                </div>
                """
        };

        using var client = new SmtpClient();
        await client.ConnectAsync(host, port, SecureSocketOptions.StartTls);
        await client.AuthenticateAsync(user, password);
        await client.SendAsync(message);
        await client.DisconnectAsync(true);

        _logger.LogInformation("Password reset email sent to {Email}", toEmail);
    }
}
