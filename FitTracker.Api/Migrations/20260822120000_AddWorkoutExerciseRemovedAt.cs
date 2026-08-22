using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkoutExerciseRemovedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ScheduledWorkoutExercises holds a restricted foreign key into
            // WorkoutExercises, so an exercise the user had ever scheduled could not be
            // deleted at all. Retiring it instead lets the workout lose the exercise
            // while the sessions that logged sets against it keep something to point at.
            // Null means "still part of the workout", which is what every existing row is.
            migrationBuilder.AddColumn<DateTime>(
                name: "RemovedAt",
                table: "WorkoutExercises",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RemovedAt",
                table: "WorkoutExercises");
        }
    }
}
