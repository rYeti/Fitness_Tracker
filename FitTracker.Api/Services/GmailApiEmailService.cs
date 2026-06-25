using FitTracker.Api.Services.Interfaces;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Auth.OAuth2.Flows;
using Google.Apis.Auth.OAuth2.Responses;
using Google.Apis.Gmail.v1;
using Google.Apis.Gmail.v1.Data;
using Google.Apis.Services;
using MimeKit;

namespace FitTracker.Api.Services;

public class GmailApiEmailService : IEmailService
{
    private readonly IConfiguration _config;
    private readonly ILogger<GmailApiEmailService> _logger;

    public GmailApiEmailService(IConfiguration config, ILogger<GmailApiEmailService> logger)
    {
        _config = config;
        _logger = logger;
    }

    public async Task SendPasswordResetEmailAsync(string toEmail, string resetLink)
    {
        var clientId     = _config["Gmail:ClientId"]     ?? throw new InvalidOperationException("Gmail:ClientId is not configured.");
        var clientSecret = _config["Gmail:ClientSecret"] ?? throw new InvalidOperationException("Gmail:ClientSecret is not configured.");
        var refreshToken = _config["Gmail:RefreshToken"] ?? throw new InvalidOperationException("Gmail:RefreshToken is not configured.");
        var from         = _config["Gmail:From"]         ?? throw new InvalidOperationException("Gmail:From is not configured.");
        var fromName     = _config["Gmail:FromName"]     ?? "ForgeForm";

        var credential = new UserCredential(
            new GoogleAuthorizationCodeFlow(new GoogleAuthorizationCodeFlow.Initializer
            {
                ClientSecrets = new ClientSecrets { ClientId = clientId, ClientSecret = clientSecret },
                Scopes = [GmailService.Scope.GmailSend]
            }),
            "user",
            new TokenResponse { RefreshToken = refreshToken }
        );

        var gmailService = new GmailService(new BaseClientService.Initializer
        {
            HttpClientInitializer = credential,
            ApplicationName = "ForgeForm"
        });

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

        using var ms = new MemoryStream();
        await message.WriteToAsync(ms);
        var raw = Convert.ToBase64String(ms.ToArray())
            .Replace('+', '-')
            .Replace('/', '_')
            .TrimEnd('=');

        await gmailService.Users.Messages.Send(new Message { Raw = raw }, "me").ExecuteAsync();

        _logger.LogInformation("Password reset email sent to {Email}", toEmail);
    }
}
