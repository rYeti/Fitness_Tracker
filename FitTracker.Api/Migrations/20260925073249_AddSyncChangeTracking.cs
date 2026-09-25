using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSyncChangeTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Workouts_UserId",
                table: "Workouts");

            migrationBuilder.DropIndex(
                name: "IX_WorkoutPlans_UserId",
                table: "WorkoutPlans");

            migrationBuilder.DropIndex(
                name: "IX_WeightTrackings_UserId",
                table: "WeightTrackings");

            migrationBuilder.DropIndex(
                name: "IX_MealTemplates_UserId",
                table: "MealTemplates");

            migrationBuilder.DropIndex(
                name: "IX_FoodItems_UserId",
                table: "FoodItems");

            migrationBuilder.DropIndex(
                name: "IX_Exercise_UserId",
                table: "Exercise");

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "Workouts",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "WorkoutPlans",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "WeightTrackings",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "UserSettings",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "ScheduledWorkouts",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "MealTemplates",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "Meals",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "FoodItems",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "Exercise",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            // Every existing aggregate counts as changed as of this deploy, so the first
            // changes-feed request from any cursor earlier than now is a full pull. The
            // column default above is year 1, which would hide every existing row from
            // every cursor. See docs/sync-architecture.md, part three.
            foreach (var table in new[]
            {
                "Exercise", "Workouts", "WorkoutPlans", "ScheduledWorkouts", "FoodItems",
                "Meals", "MealTemplates", "WeightTrackings", "UserSettings",
            })
            {
                migrationBuilder.Sql($@"UPDATE ""{table}"" SET ""UpdatedAt"" = now();");
            }

            migrationBuilder.CreateTable(
                name: "SyncTombstones",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    EntityType = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    EntityId = table.Column<Guid>(type: "uuid", nullable: false),
                    DeletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SyncTombstones", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SyncTombstones_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Workouts_UserId_UpdatedAt",
                table: "Workouts",
                columns: new[] { "UserId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutPlans_UserId_UpdatedAt",
                table: "WorkoutPlans",
                columns: new[] { "UserId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_WeightTrackings_UserId_UpdatedAt",
                table: "WeightTrackings",
                columns: new[] { "UserId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ScheduledWorkouts_WorkoutId_UpdatedAt",
                table: "ScheduledWorkouts",
                columns: new[] { "WorkoutId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_MealTemplates_UserId_UpdatedAt",
                table: "MealTemplates",
                columns: new[] { "UserId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Meals_UserId_UpdatedAt",
                table: "Meals",
                columns: new[] { "UserId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_FoodItems_UserId_UpdatedAt",
                table: "FoodItems",
                columns: new[] { "UserId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Exercise_UserId_UpdatedAt",
                table: "Exercise",
                columns: new[] { "UserId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_SyncTombstones_UserId_DeletedAt",
                table: "SyncTombstones",
                columns: new[] { "UserId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_SyncTombstones_UserId_EntityId",
                table: "SyncTombstones",
                columns: new[] { "UserId", "EntityId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SyncTombstones");

            migrationBuilder.DropIndex(
                name: "IX_Workouts_UserId_UpdatedAt",
                table: "Workouts");

            migrationBuilder.DropIndex(
                name: "IX_WorkoutPlans_UserId_UpdatedAt",
                table: "WorkoutPlans");

            migrationBuilder.DropIndex(
                name: "IX_WeightTrackings_UserId_UpdatedAt",
                table: "WeightTrackings");

            migrationBuilder.DropIndex(
                name: "IX_ScheduledWorkouts_WorkoutId_UpdatedAt",
                table: "ScheduledWorkouts");

            migrationBuilder.DropIndex(
                name: "IX_MealTemplates_UserId_UpdatedAt",
                table: "MealTemplates");

            migrationBuilder.DropIndex(
                name: "IX_Meals_UserId_UpdatedAt",
                table: "Meals");

            migrationBuilder.DropIndex(
                name: "IX_FoodItems_UserId_UpdatedAt",
                table: "FoodItems");

            migrationBuilder.DropIndex(
                name: "IX_Exercise_UserId_UpdatedAt",
                table: "Exercise");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "Workouts");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "WorkoutPlans");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "WeightTrackings");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "UserSettings");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "ScheduledWorkouts");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "MealTemplates");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "Meals");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "FoodItems");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "Exercise");

            migrationBuilder.CreateIndex(
                name: "IX_Workouts_UserId",
                table: "Workouts",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutPlans_UserId",
                table: "WorkoutPlans",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_WeightTrackings_UserId",
                table: "WeightTrackings",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_MealTemplates_UserId",
                table: "MealTemplates",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_FoodItems_UserId",
                table: "FoodItems",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Exercise_UserId",
                table: "Exercise",
                column: "UserId");
        }
    }
}
