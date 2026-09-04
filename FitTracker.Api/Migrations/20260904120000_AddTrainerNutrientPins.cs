using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddTrainerNutrientPins : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TrainerNutrientPins",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TrainerId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientId = table.Column<Guid>(type: "uuid", nullable: false),
                    NutrientKey = table.Column<string>(type: "text", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrainerNutrientPins", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TrainerNutrientPins_Users_TrainerId",
                        column: x => x.TrainerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_TrainerNutrientPins_Users_ClientId",
                        column: x => x.ClientId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            // The read path fetches by (trainer, client); the write path replaces the
            // whole set for that pair in one statement, so this is also what stops a
            // re-applied write from ever producing two rows for the same nutrient.
            migrationBuilder.CreateIndex(
                name: "IX_TrainerNutrientPins_TrainerId_ClientId_NutrientKey",
                table: "TrainerNutrientPins",
                columns: new[] { "TrainerId", "ClientId", "NutrientKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TrainerNutrientPins_ClientId",
                table: "TrainerNutrientPins",
                column: "ClientId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TrainerNutrientPins");
        }
    }
}
