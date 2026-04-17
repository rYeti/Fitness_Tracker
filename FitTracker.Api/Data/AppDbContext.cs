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
            entity.HasOne(e => e.User).WithMany().HasForeignKey(e => e.UserId).OnDelete(DeleteBehavior.Cascade);
        });
    }
}
