using System.Text;
using FitTracker.Api.Data;
using FitTracker.Api.Repositories;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;


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

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutter", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
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
});

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

// ── Build ────────────────────────────────────────────────────
var app = builder.Build();

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
app.MapControllers();


app.Run();