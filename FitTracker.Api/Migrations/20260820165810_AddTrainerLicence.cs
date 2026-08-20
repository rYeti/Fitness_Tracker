using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddTrainerLicence : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TrainerLicences",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TrainerId = table.Column<Guid>(type: "uuid", nullable: false),
                    Tier = table.Column<int>(type: "integer", nullable: false),
                    SeatLimit = table.Column<int>(type: "integer", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    HasUsedTrial = table.Column<bool>(type: "boolean", nullable: false),
                    StripeCustomerId = table.Column<string>(type: "text", nullable: true),
                    StripeSubscriptionId = table.Column<string>(type: "text", nullable: true),
                    CurrentPeriodEnd = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    GraceEndsAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastStripeEventAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrainerLicences", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TrainerLicences_Users_TrainerId",
                        column: x => x.TrainerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TrainerLicences_TrainerId",
                table: "TrainerLicences",
                column: "TrainerId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TrainerLicences_StripeSubscriptionId",
                table: "TrainerLicences",
                column: "StripeSubscriptionId");

            // Backfill every existing trainer with a Free licence.
            //
            // This is not optional. From this migration onward a user is a
            // trainer because they hold a licence, not because they happen to
            // have clients (TrainerClientService.GetStatusAsync). Without this
            // block every trainer already using the console loses access the
            // moment it deploys.
            //
            // SeatLimit is GREATEST(3, active client count) so that a trainer
            // who already has more clients than the free tier allows is
            // grandfathered rather than waking up over their limit. They keep
            // what they have; the seat check only blocks *new* invites.
            migrationBuilder.Sql("""
                INSERT INTO "TrainerLicences" (
                    "Id", "TrainerId", "Tier", "SeatLimit", "Status",
                    "HasUsedTrial", "CreatedAt", "UpdatedAt")
                SELECT
                    gen_random_uuid(),
                    tc."TrainerId",
                    0,                                  -- LicenceTier.Free
                    GREATEST(3, COUNT(*)::int),
                    0,                                  -- LicenceStatus.Active
                    FALSE,
                    NOW(),
                    NOW()
                FROM "TrainerClients" tc
                WHERE tc."Status" = 1                   -- TrainerClientStatus.Active
                GROUP BY tc."TrainerId";
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TrainerLicences");
        }
    }
}
