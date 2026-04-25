using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddTrainerClient : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TrainerClients",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TrainerId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientId = table.Column<Guid>(type: "uuid", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    InviteCode = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    AcceptedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrainerClients", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TrainerClients_Users_ClientId",
                        column: x => x.ClientId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TrainerClients_Users_TrainerId",
                        column: x => x.TrainerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TrainerClients_ClientId",
                table: "TrainerClients",
                column: "ClientId");

            migrationBuilder.CreateIndex(
                name: "IX_TrainerClients_InviteCode",
                table: "TrainerClients",
                column: "InviteCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TrainerClients_TrainerId",
                table: "TrainerClients",
                column: "TrainerId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TrainerClients");
        }
    }
}
