using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <summary>
    /// Composite indexes for the Trainer Console's read paths.
    ///
    /// Each one covers a pair of columns that a hot console query filters on together, where the
    /// only index available was the single-column one EF creates for the foreign key. The roster
    /// and dashboard KPIs now aggregate a date window across the whole roster in one grouped
    /// query rather than reading each client's entire history, and that query is only cheap if
    /// the date is part of the index rather than a filter applied after it.
    /// </summary>
    /// <inheritdoc />
    public partial class AddTrainerConsoleReadIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Sessions are reached through Workouts.UserId and then range-scanned by date.
            migrationBuilder.CreateIndex(
                name: "IX_ScheduledWorkouts_WorkoutId_ScheduledDate",
                table: "ScheduledWorkouts",
                columns: new[] { "WorkoutId", "ScheduledDate" });

            // The nutrition summary reads a seven-day window for one user.
            migrationBuilder.CreateIndex(
                name: "IX_Meals_UserId_Date",
                table: "Meals",
                columns: new[] { "UserId", "Date" });

            // Both the roster read and the seat count filter on trainer plus status.
            migrationBuilder.CreateIndex(
                name: "IX_TrainerClients_TrainerId_Status",
                table: "TrainerClients",
                columns: new[] { "TrainerId", "Status" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_TrainerClients_TrainerId_Status",
                table: "TrainerClients");

            migrationBuilder.DropIndex(
                name: "IX_Meals_UserId_Date",
                table: "Meals");

            migrationBuilder.DropIndex(
                name: "IX_ScheduledWorkouts_WorkoutId_ScheduledDate",
                table: "ScheduledWorkouts");
        }
    }
}
