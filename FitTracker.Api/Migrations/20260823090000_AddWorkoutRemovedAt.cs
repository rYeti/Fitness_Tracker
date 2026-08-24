using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkoutRemovedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ScheduledWorkouts holds a restricted foreign key into Workouts, so a workout the
            // user had ever scheduled could not be deleted at all — the delete raised a
            // foreign-key violation and the workout survived, staying visible to their trainer
            // long after they had removed it. Retiring it instead lets the workout leave the
            // user's list while the sessions that logged sets against it keep something to
            // point at. Null means "still exists", which is what every existing row is.
            migrationBuilder.AddColumn<DateTime>(
                name: "RemovedAt",
                table: "Workouts",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RemovedAt",
                table: "Workouts");
        }
    }
}
