using System.Text;
using System.Threading.RateLimiting;
using FirebaseAdmin;
using FitTracker.Api.Data;
using FitTracker.Api.Repositories;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using FitTracker.Api.Hubs;


var builder = WebApplication.CreateBuilder(args);

// ── Services ────────────────────────────────────────────────
builder.Services.AddDbContext<AppDbContext>(options => options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Enter: Bearer {token}"
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// Browser origins allowed to call the API. Native mobile/desktop clients don't
// send an Origin header, so none of this applies to them — this exists for the
// Flutter web build (the Trainer Console) and SignalR.
//
// SignalR's browser clients send credentials on the negotiate request, and
// AllowCredentials cannot be combined with AllowAnyOrigin — ASP.NET Core throws
// at runtime if you try — so allowed origins have to be listed explicitly.
//
// Trailing slashes are trimmed because WithOrigins matches the serialised
// origin exactly: "https://app.example.com/" never matches a real request.
var corsOrigins = (builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [])
    .Where(origin => !string.IsNullOrWhiteSpace(origin))
    .Select(origin => origin.Trim().TrimEnd('/'))
    .Distinct(StringComparer.OrdinalIgnoreCase)
    .ToArray();

// Dev defaults live here rather than in appsettings.json on purpose:
// configuration providers override arrays *per index*, so a committed
// two-entry list plus a one-entry environment override would leave the
// second localhost entry trusted in production.
// `flutter run -d chrome` picks a random port unless you pass --web-port.
if (corsOrigins.Length == 0 && builder.Environment.IsDevelopment())
{
    corsOrigins = ["http://localhost:5000", "http://127.0.0.1:5000"];
}

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutter", policy =>
    {
        if (corsOrigins.Length > 0)
        {
            policy.WithOrigins(corsOrigins)
                  .AllowAnyMethod()
                  .AllowAnyHeader()
                  .AllowCredentials();
        }
        else
        {
            // No origins configured. Rather than take the API down over a
            // missing setting, fall back to the previous behaviour — which is
            // legal only without credentials. Browser SignalR will fail until
            // Cors:AllowedOrigins is set; everything else keeps working.
            // The warning is logged at startup below.
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        }
    });
});

// Throttles brute-force-able endpoints (login/register/password-reset/invite-join)
// by client IP. Fixed-window is sufficient here — these are abuse guards, not
// precision traffic shaping.
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.AddPolicy("auth", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));

    options.AddPolicy("invite", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));

    // The Stripe webhook is anonymous, so it needs a ceiling — but a generous
    // one, partitioned globally rather than by IP. Stripe retries in bursts
    // from its own address range, and throttling a legitimate retry means a
    // trainer's subscription change silently doesn't land.
    options.AddPolicy("webhook", _ =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: "stripe-webhook",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 300,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));
});

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(option =>
{
    option.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidAudience = builder.Configuration["Jwt:Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!)),
        ClockSkew = TimeSpan.Zero
    };

    option.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs/chat"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        }
    };
});

// Signal R
builder.Services.AddSignalR();

builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IWeightTrackingRepository, WeightTrackingRepository>();
builder.Services.AddScoped<IWeightTrackingService, WeightTrackingService>();
builder.Services.AddScoped<IExerciseRepository, ExerciseRepository>();
builder.Services.AddScoped<IExerciseService, ExerciseService>();
builder.Services.AddScoped<IWorkoutRepository, WorkoutRepository>();
builder.Services.AddScoped<IWorkoutPlanRepository, WorkoutPlanRepository>();
builder.Services.AddScoped<IScheduledWorkoutRepository, ScheduledWorkoutRepository>();
builder.Services.AddScoped<IWorkoutService, WorkoutService>();
builder.Services.AddScoped<IWorkoutPlanService, WorkoutPlanService>();
builder.Services.AddScoped<IScheduledWorkoutService, ScheduledWorkoutService>();
builder.Services.AddScoped<IFoodItemRepository, FoodItemRepository>();
builder.Services.AddScoped<IFoodItemService, FoodItemService>();
builder.Services.AddScoped<IMealRepository, MealRepository>();
builder.Services.AddScoped<IMealService, MealService>();
builder.Services.AddScoped<IUserSettingsRepository, UserSettingsRepository>();
builder.Services.AddScoped<IUserSettingsService, UserSettingsService>();
builder.Services.AddScoped<IMealTemplateRepository, MealTemplateRepository>();
builder.Services.AddScoped<IMealTemplateService, MealTemplateService>();
builder.Services.AddScoped<ITrainerClientRepository, TrainerClientRepository>();
builder.Services.AddScoped<ITrainerClientService, TrainerClientService>();
builder.Services.AddScoped<ITrainerLicenceRepository, TrainerLicenceRepository>();
builder.Services.AddScoped<ITrainerLicenceService, TrainerLicenceService>();
builder.Services.AddSingleton<LicencePlanCatalog>();
builder.Services.AddSingleton<LicenceStateMachine>();
builder.Services.AddScoped<FitTracker.Api.Filters.RequireEntitledLicenceFilter>();
builder.Services.AddScoped<ITrainerConsoleService, TrainerConsoleService>();
builder.Services.AddScoped<IWorkoutPlanTemplateRepository, WorkoutPlanTemplateRepository>();
builder.Services.AddScoped<IWorkoutPlanTemplateService, WorkoutPlanTemplateService>();
builder.Services.AddTransient<IEmailService, GmailApiEmailService>();
builder.Services.AddScoped<IChatRepository, ChatRepository>();
builder.Services.AddScoped<IChatService, ChatService>();
builder.Services.AddScoped<IDeviceTokenRepository, DeviceTokenRepository>();
builder.Services.AddScoped<IPushNotificationService, PushNotificationService>();

// Singleton: it holds a scope factory and a logger and nothing else. It has to
// outlive the hub invocation that queues work on it, which is the entire point.
builder.Services.AddSingleton<IChatPushDispatcher, ChatPushDispatcher>();

// Push transport. Configured or not, the API serves every request identically --
// the same posture as the Stripe and CORS blocks below: log loudly, keep serving.
// Without credentials chat still works end to end; it just doesn't notify.
var fcmCredentialsBase64 = builder.Configuration["Fcm:ServiceAccountJsonBase64"];
if (!string.IsNullOrWhiteSpace(fcmCredentialsBase64))
{
    // Base64 rather than raw JSON because deploy.yml passes every setting in one
    // comma-joined --set-env-vars string and gcloud splits it on commas. A
    // service-account JSON is full of them. Base64 has none.
    var fcmJson = Encoding.UTF8.GetString(Convert.FromBase64String(fcmCredentialsBase64));
    var firebaseApp = FirebaseApp.Create(new AppOptions
    {
        Credential = GoogleCredential.FromJson(fcmJson),
        ProjectId = builder.Configuration["Fcm:ProjectId"],
    });
    builder.Services.AddSingleton(firebaseApp);
    builder.Services.AddSingleton<IPushSender, FirebasePushSender>();
}
else
{
    builder.Services.AddSingleton<IPushSender, DisabledPushSender>();
}


// ── Build ────────────────────────────────────────────────────
var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.Migrate();
}

// Surface the CORS posture at startup — a missing origins list is otherwise
// invisible until a browser fails a preflight, which is a confusing place to
// discover it.
if (corsOrigins.Length > 0)
{
    app.Logger.LogInformation(
        "CORS: credentialed requests allowed from {Origins}", string.Join(", ", corsOrigins));
}
else
{
    app.Logger.LogWarning(
        "CORS: no Cors:AllowedOrigins configured — falling back to any-origin without credentials. " +
        "SignalR browser clients will fail their negotiate request until origins are set. " +
        "See docs/cors-and-signalr.md.");
}

if (string.IsNullOrWhiteSpace(fcmCredentialsBase64))
{
    app.Logger.LogWarning(
        "Push: no Fcm:ServiceAccountJsonBase64 configured — chat works, but nobody is " +
        "notified while their app is closed. Set FCM_SERVICE_ACCOUNT_BASE64 and " +
        "FCM_PROJECT_ID. See docs/chat-architecture.md.");
}

// Stripe. Configured once at startup rather than per request; the SDK reads
// this static for every call it makes.
var stripeKey = builder.Configuration["Stripe:SecretKey"];
if (!string.IsNullOrWhiteSpace(stripeKey))
{
    Stripe.StripeConfiguration.ApiKey = stripeKey;

    var unpricedTiers = LicencePlanCatalog.PurchasableTiers
        .Where(tier => string.IsNullOrWhiteSpace(builder.Configuration[$"Stripe:Prices:{tier}"]))
        .ToArray();
    if (unpricedTiers.Length > 0)
    {
        // A tier with no price id can't be bought, and a webhook carrying that
        // price can't be mapped back to a tier — so seats silently wouldn't
        // update. Better to say so at boot than to debug it from a support ticket.
        app.Logger.LogWarning(
            "Stripe: no price configured for {Tiers} — those plans cannot be purchased. " +
            "See docs/trainer-licensing.md.", string.Join(", ", unpricedTiers));
    }
}
else
{
    app.Logger.LogWarning(
        "Stripe: no Stripe:SecretKey configured — trainer licences will stay on the free tier " +
        "and no checkout or webhook handling will work. See docs/trainer-licensing.md.");
}

// ── Middleware pipeline ──────────────────────────────────────
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseRouting();
app.UseCors("AllowFlutter");
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapControllers();
app.MapHub<ChatHub>("/hubs/chat").RequireAuthorization();


app.Run();