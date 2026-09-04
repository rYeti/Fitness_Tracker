using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class DropRedundantFkIndexesSupersededByCompositeIndexes : Migration
    {
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
