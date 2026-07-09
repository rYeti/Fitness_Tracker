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

    /// <summary>Trainer–client relationships.</summary>
    public DbSet<TrainerClient> TrainerClients { get; set; }

    /// <summary>Password reset tokens table.</summary>
    public DbSet<PasswordResetToken> PasswordResetTokens { get; set; }

    /// <summary>Refresh tokens table.</summary>
    public DbSet<RefreshToken> RefreshTokens { get; set; }

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
                  .OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(t => t.InviteCode).IsUnique();
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
    }
}
