using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddExerciseSourceExerciseId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Lets a trainer's own exercise be copied into a client's library exactly
            // once when it's prescribed, instead of once per prescription. No FK: the
            // copy must stay resolvable even if the trainer later edits or deletes
            // their original — see the property's remarks on FitTracker.Api.Models.Exercise.
            migrationBuilder.AddColumn<Guid>(
                name: "SourceExerciseId",
                table: "Exercise",
                type: "uuid",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SourceExerciseId",
                table: "Exercise");
        }
    }
}
