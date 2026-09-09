using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddDeloadWeeks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // A plan's deload weeks, as JSON: [{"week":5,"volumePercent":50}].
            // Non-null with a "[]" default so every existing plan reads as "no
            // deloads" — which is what it was — and so anything reading the
            // column directly can parse it without a special case.
            migrationBuilder.AddColumn<string>(
                name: "DeloadWeeksJson",
                table: "WorkoutPlans",
                type: "text",
                nullable: false,
                defaultValue: "[]");

            // Whether a session was performed in a deload week, stamped when it
            // is first completed. Deliberately NULLABLE with no default: null
            // means "nobody has settled this", which is the truthful value for
            // every session that predates the column. A `false` default would
            // have asserted that all of them were performed in normal weeks —
            // a claim nothing checked. See docs/deload-weeks.md §14d.
            migrationBuilder.AddColumn<bool>(
                name: "WasDeload",
                table: "ScheduledWorkouts",
                type: "boolean",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DeloadWeeksJson",
                table: "WorkoutPlans");

            migrationBuilder.DropColumn(
                name: "WasDeload",
                table: "ScheduledWorkouts");
        }
    }
}
