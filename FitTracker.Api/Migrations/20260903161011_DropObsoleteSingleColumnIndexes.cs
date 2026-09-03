using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class DropObsoleteSingleColumnIndexes : Migration
    {
        // Model/migration drift found while adding the AddChatAttachments
        // migration in this same PR: `dotnet ef migrations add` reported these
        // three indexes as pending removal. Each was superseded by a composite
        // index added in earlier work (IX_ScheduledWorkouts_WorkoutId by
        // {WorkoutId, ScheduledDate} for the trainer-console read path — see
        // docs/trainer-console-loading.md — and similarly for the other two),
        // but no migration was ever generated to match, so the database kept
        // carrying the redundant single-column index. Unrelated to chat
        // attachments; split into its own migration so that one stays a clean
        // diff. This is exactly the gap `dotnet ef migrations
        // has-pending-model-changes` (added to CI in this same PR) exists to
        // catch before it happens again.
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_TrainerClients_TrainerId",
                table: "TrainerClients");

            migrationBuilder.DropIndex(
                name: "IX_ScheduledWorkouts_WorkoutId",
                table: "ScheduledWorkouts");

            migrationBuilder.DropIndex(
                name: "IX_Meals_UserId",
                table: "Meals");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_TrainerClients_TrainerId",
                table: "TrainerClients",
                column: "TrainerId");

            migrationBuilder.CreateIndex(
                name: "IX_ScheduledWorkouts_WorkoutId",
                table: "ScheduledWorkouts",
                column: "WorkoutId");

            migrationBuilder.CreateIndex(
                name: "IX_Meals_UserId",
                table: "Meals",
                column: "UserId");
        }
    }
}
