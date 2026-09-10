using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddMealTemplateItemExtendedNutrients : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ExtendedNutrientsJson",
                table: "MealTemplateItems",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ExtendedNutrientsJson",
                table: "MealTemplateItems");
        }
    }
}
