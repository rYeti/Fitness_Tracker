using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkoutAssignedByTrainer : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Records which trainer prescribed a workout/plan, so a client can be told
            // apart from the trainer who assigned it to them when deciding who may delete
            // it. No FK, same reasoning as Exercise.SourceExerciseId: the row must stay
            // readable after the trainer-client relationship ends.
            migrationBuilder.AddColumn<Guid>(
                name: "AssignedByTrainerId",
                table: "Workouts",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "AssignedByTrainerId",
                table: "WorkoutPlans",
                type: "uuid",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AssignedByTrainerId",
                table: "Workouts");

            migrationBuilder.DropColumn(
                name: "AssignedByTrainerId",
                table: "WorkoutPlans");
        }
    }
}
