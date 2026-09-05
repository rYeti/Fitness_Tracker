using FitTracker.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Data;

/// <summary>Entity Framework Core database context for the FitTracker application.</summary>
public class AppDbContext : DbContext
{
    /// <summary>Initialises a new instance of <see cref="AppDbContext"/> with the given options.</summary>
    /// <param name="options">The options used to configure the context.</param>
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    /// <summary>The users table.</summary>
    public DbSet<User> Users { get; set; }

    /// <summary>The weight tracking entries table.</summary>
    public DbSet<WeightTracking> WeightTrackings { get; set; }

    /// <summary>The exercises table.</summary>
    public DbSet<Exercise> Exercise { get; set; }

    /// <summary>The workout templates table.</summary>
    public DbSet<Workout> Workouts { get; set; }

    /// <summary>The workout exercise entries table.</summary>
    public DbSet<WorkoutExercise> WorkoutExercises { get; set; }

    /// <summary>The workout set templates table.</summary>
    public DbSet<WorkoutSetTemplate> WorkoutSetTemplates { get; set; }

    /// <summary>The workout plans table.</summary>
    public DbSet<WorkoutPlan> WorkoutPlans { get; set; }

    /// <summary>The workout plan membership join table.</summary>
    public DbSet<WorkoutPlanWorkout> WorkoutPlanWorkouts { get; set; }

    /// <summary>The scheduled workout occurrences table.</summary>
    public DbSet<ScheduledWorkout> ScheduledWorkouts { get; set; }

    /// <summary>The scheduled workout exercise entries table.</summary>
    public DbSet<ScheduledWorkoutExercise> ScheduledWorkoutExercises { get; set; }

    /// <summary>The performed workout sets table.</summary>
    public DbSet<WorkoutSet> WorkoutSets { get; set; }

    /// <summary>The food item library table.</summary>
    public DbSet<FoodItem> FoodItems { get; set; }

    /// <summary>The meal log entries table.</summary>
    public DbSet<Meal> Meals { get; set; }

    /// <summary>The meal-to-food-item join table.</summary>
    public DbSet<MealFoodEntry> MealFoodEntries { get; set; }

    /// <summary>The per-user app settings table.</summary>
    public DbSet<UserSettings> UserSettings { get; set; }

    /// <summary>The meal templates table.</summary>
    public DbSet<MealTemplate> MealTemplates { get; set; }

    /// <summary>The meal template items table.</summary>
    public DbSet<MealTemplateItem> MealTemplateItems { get; set; }

    // TODO: needs an EF migration + seed data (5 rows matching the design's
    // template list) before this is usable.
    public DbSet<WorkoutPlanTemplate> WorkoutPlanTemplates { get; set; }

    /// <summary>Trainer–client relationships.</summary>
    public DbSet<TrainerClient> TrainerClients { get; set; }

    /// <summary>Trainer plans: seat limits and Pro entitlement.</summary>
    public DbSet<TrainerLicence> TrainerLicences { get; set; }

    /// <summary>Password reset tokens table.</summary>
    public DbSet<PasswordResetToken> PasswordResetTokens { get; set; }

    /// <summary>Refresh tokens table.</summary>
    public DbSet<RefreshToken> RefreshTokens { get; set; }

    public DbSet<ChatMessage> ChatMessages { get; set; }

    public DbSet<ChatAttachment> ChatAttachments { get; set; }

    public DbSet<UserChatKey> UserChatKeys { get; set; }

    /// <summary>Push registration tokens, one row per signed-in device.</summary>
    public DbSet<DeviceToken> DeviceTokens { get; set; }

    /// <summary>Which nutrients a trainer has pinned to track, per client —
    /// Nutrition tab "Tracked nutrients".</summary>
    public DbSet<TrainerNutrientPin> TrainerNutrientPins { get; set; }

    /// <summary>Which nutrients a user with no trainer has pinned to track for
    /// themselves — the self-service counterpart to <see cref="TrainerNutrientPins"/>.</summary>
    public DbSet<UserNutrientPin> UserNutrientPins { get; set; }

    /// <summary>A user's own app-store subscription, as reported by RevenueCat.</summary>
    public DbSet<RevenueCatSubscription> RevenueCatSubscriptions { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(u => u.Id);
            entity.HasIndex(u => u.Email).IsUnique();
            entity.HasIndex(u => u.UserName).IsUnique();
        });

        modelBuilder.Entity<WeightTracking>(entity =>
        {
            entity.HasKey(w => w.Id);
            entity.HasOne(w => w.User)
                  .WithMany()
                  .HasForeignKey(w => w.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Exercise>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasOne(e => e.User).WithMany().HasForeignKey(e => e.UserId).IsRequired(false).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Workout>(entity =>
        {
            entity.HasKey(w => w.Id);
            entity.HasOne(w => w.User)
                  .WithMany()
                  .HasForeignKey(w => w.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<WorkoutExercise>(entity =>
        {
            entity.HasKey(we => we.Id);
            entity.HasOne(we => we.Workout)
                  .WithMany(w => w.Exercises)
                  .HasForeignKey(we => we.WorkoutId)
                  .OnDelete(DeleteBehavior.Cascade);
            // ExerciseId is an opaque client-side identifier — no FK to the Exercise table
            // because exercises are seeded locally on the client and may not exist in the API.
        });

        modelBuilder.Entity<WorkoutSetTemplate>(entity =>
        {
            entity.HasKey(t => t.Id);
            entity.HasOne(t => t.WorkoutExercise)
                  .WithMany(we => we.SetTemplates)
                  .HasForeignKey(t => t.WorkoutExerciseId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<WorkoutPlan>(entity =>
        {
            entity.HasKey(p => p.Id);
            entity.HasOne(p => p.User)
                  .WithMany()
                  .HasForeignKey(p => p.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<WorkoutPlanWorkout>(entity =>
        {
            entity.HasKey(pw => pw.Id);
            entity.HasOne(pw => pw.WorkoutPlan)
                  .WithMany(p => p.PlanWorkouts)
                  .HasForeignKey(pw => pw.PlanId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(pw => pw.Workout)
                  .WithMany(w => w.PlanWorkouts)
                  .HasForeignKey(pw => pw.WorkoutId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ScheduledWorkout>(entity =>
        {
            entity.HasKey(sw => sw.Id);
            entity.HasOne(sw => sw.Workout)
                  .WithMany()
                  .HasForeignKey(sw => sw.WorkoutId)
                  .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(sw => sw.WorkoutPlan)
                  .WithMany(p => p.ScheduledWorkouts)
                  .HasForeignKey(sw => sw.WorkoutPlanId)
                  .OnDelete(DeleteBehavior.SetNull);
            // Every trainer-facing read of a client's sessions joins Workouts (filtered by
            // UserId) and then range-scans the date. The convention index is on WorkoutId
            // alone, which leaves the date range filtering every session the client has ever
            // logged.
            entity.HasIndex(sw => new { sw.WorkoutId, sw.ScheduledDate });
        });

        modelBuilder.Entity<ScheduledWorkoutExercise>(entity =>
        {
            entity.HasKey(se => se.Id);
            entity.HasOne(se => se.ScheduledWorkout)
                  .WithMany(sw => sw.Exercises)
                  .HasForeignKey(se => se.ScheduledWorkoutId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(se => se.WorkoutExercise)
                  .WithMany(we => we.ScheduledExercises)
                  .HasForeignKey(se => se.WorkoutExerciseId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<WorkoutSet>(entity =>
        {
            entity.HasKey(s => s.Id);
            entity.HasOne(s => s.ScheduledWorkoutExercise)
                  .WithMany(se => se.Sets)
                  .HasForeignKey(s => s.ScheduledWorkoutExerciseId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<FoodItem>(entity =>
        {
            entity.HasKey(f => f.Id);
            entity.HasOne(f => f.User)
                  .WithMany()
                  .HasForeignKey(f => f.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Meal>(entity =>
        {
            entity.HasKey(m => m.Id);
            entity.HasOne(m => m.User)
                  .WithMany()
                  .HasForeignKey(m => m.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            // The nutrition summary reads a seven-day window for one user; this is exactly
            // the pair it filters on.
            entity.HasIndex(m => new { m.UserId, m.Date });
            // FoodItemId is an opaque client-side reference — no FK enforced
        });

        modelBuilder.Entity<MealFoodEntry>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasOne(e => e.Meal)
                  .WithMany(m => m.FoodEntries)
                  .HasForeignKey(e => e.MealId)
                  .OnDelete(DeleteBehavior.Cascade);
            // FoodItemId is an opaque client-side reference — no FK enforced
        });

        modelBuilder.Entity<UserSettings>(entity =>
        {
            entity.HasKey(s => s.Id);
            entity.HasOne(s => s.User)
                  .WithMany()
                  .HasForeignKey(s => s.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(s => s.UserId).IsUnique(); // one settings row per user
        });

        modelBuilder.Entity<MealTemplate>(entity =>
        {
            entity.HasKey(t => t.Id);
            entity.HasOne(t => t.User)
                  .WithMany()
                  .HasForeignKey(t => t.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<MealTemplateItem>(entity =>
        {
            entity.HasKey(i => i.Id);
            entity.HasOne(i => i.Template)
                  .WithMany(t => t.Items)
                  .HasForeignKey(i => i.TemplateId)
                  .OnDelete(DeleteBehavior.Cascade);
            // FoodId is an opaque client-side reference — no FK enforced
        });

        modelBuilder.Entity<TrainerClient>(entity =>
        {
            entity.HasKey(t => t.Id);
            entity.HasOne(t => t.Trainer)
                  .WithMany()
                  .HasForeignKey(t => t.TrainerId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(t => t.Client)
                  .WithMany()
                  .HasForeignKey(t => t.ClientId)
                  .IsRequired(false)
                  .OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(t => t.InviteCode).IsUnique();
            // Both the roster read and the seat count filter on exactly this pair.
            entity.HasIndex(t => new { t.TrainerId, t.Status });
        });

        modelBuilder.Entity<TrainerLicence>(entity =>
        {
            entity.HasKey(l => l.Id);
            entity.HasOne(l => l.Trainer)
                  .WithMany()
                  .HasForeignKey(l => l.TrainerId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(l => l.TrainerId).IsUnique(); // one licence row per trainer
            entity.HasIndex(l => l.StripeSubscriptionId); // webhook lookup path
        });

        modelBuilder.Entity<ChatMessage>(entity =>
        {
            entity.HasKey(m => m.Id);
            entity.HasOne(m => m.TrainerClient)
                  .WithMany()
                  .HasForeignKey(m => m.TrainerClientId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(m => new { m.TrainerClientId, m.SentAt });
        });

        modelBuilder.Entity<ChatAttachment>(entity =>
        {
            entity.HasKey(a => a.Id);
            entity.HasOne(a => a.TrainerClient)
                  .WithMany()
                  .HasForeignKey(a => a.TrainerClientId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(a => a.TrainerClientId);
            // The reaper's own query shape: uncommitted rows past their grace
            // period. See docs/chat-attachments.md §A.5.
            entity.HasIndex(a => new { a.CommittedAt, a.CreatedAt });
        });

        modelBuilder.Entity<UserChatKey>(entity =>
        {
            // The user id is the key, not a surrogate: a user has exactly one
            // current chat key, and a table that allowed two would need a rule
            // for which of them a sender should encrypt to.
            entity.HasKey(k => k.UserId);
            entity.HasOne(k => k.User)
                  .WithMany()
                  .HasForeignKey(k => k.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PasswordResetToken>(entity =>
        {
            entity.HasKey(t => t.Id);
            entity.HasOne(t => t.User)
                  .WithMany()
                  .HasForeignKey(t => t.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(t => t.Token).IsUnique();
        });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.HasKey(t => t.Id);
            entity.HasOne(t => t.User)
                  .WithMany()
                  .HasForeignKey(t => t.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(t => t.TokenHash).IsUnique();
        });

        modelBuilder.Entity<DeviceToken>(entity =>
        {
            entity.HasKey(d => d.Id);
            entity.HasOne(d => d.User)
                  .WithMany()
                  .HasForeignKey(d => d.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            // Unique on the token, not on (user, token): a registration token
            // identifies an app install, and an install serves one account at a
            // time. The uniqueness is what makes re-registering after a user
            // switch move the row instead of leaving the previous user's
            // messages going to that phone.
            entity.HasIndex(d => d.Token).IsUnique();
            entity.HasIndex(d => d.UserId);
        });

        modelBuilder.Entity<TrainerNutrientPin>(entity =>
        {
            entity.HasKey(p => p.Id);
            entity.HasOne(p => p.Trainer)
                  .WithMany()
                  .HasForeignKey(p => p.TrainerId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(p => p.Client)
                  .WithMany()
                  .HasForeignKey(p => p.ClientId)
                  .OnDelete(DeleteBehavior.Cascade);
            // The read path fetches by (trainer, client); the write path
            // replaces the whole set for that pair in one statement, so the
            // constraint doubles as what stops a re-applied write from ever
            // producing two rows for the same nutrient.
            entity.HasIndex(p => new { p.TrainerId, p.ClientId, p.NutrientKey })
                  .IsUnique();
        });

        modelBuilder.Entity<UserNutrientPin>(entity =>
        {
            entity.HasKey(p => p.Id);
            entity.HasOne(p => p.User)
                  .WithMany()
                  .HasForeignKey(p => p.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            // Mirrors TrainerNutrientPin's constraint, one axis narrower: the
            // write path replaces the whole set for this user in one
            // statement, so this is what stops a re-applied write from ever
            // producing two rows for the same nutrient.
            entity.HasIndex(p => new { p.UserId, p.NutrientKey }).IsUnique();
        });

        modelBuilder.Entity<RevenueCatSubscription>(entity =>
        {
            entity.HasKey(s => s.Id);
            entity.HasOne(s => s.User)
                  .WithMany()
                  .HasForeignKey(s => s.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(s => s.UserId).IsUnique(); // one subscription row per user
        });
    }
}
