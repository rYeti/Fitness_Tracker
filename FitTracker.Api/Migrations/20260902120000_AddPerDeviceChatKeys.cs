using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddPerDeviceChatKeys : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "EphemeralPublicKeyJwk",
                table: "ChatMessages",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "UserChatDeviceKeys",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    DeviceId = table.Column<string>(type: "text", nullable: false),
                    PublicKeyJwk = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastSeenAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    // Composite on (user, device) rather than a surrogate id: a
                    // user now has one row per registered install, and this is
                    // what makes registering a second device additive instead of
                    // replacing the first — see docs/chat-encryption.md.
                    table.PrimaryKey("PK_UserChatDeviceKeys", x => new { x.UserId, x.DeviceId });
                    table.ForeignKey(
                        name: "FK_UserChatDeviceKeys_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserChatDeviceKeys_UserId",
                table: "UserChatDeviceKeys",
                column: "UserId");

            migrationBuilder.CreateTable(
                name: "ChatMessageKeys",
                columns: table => new
                {
                    MessageId = table.Column<Guid>(type: "uuid", nullable: false),
                    DeviceId = table.Column<string>(type: "text", nullable: false),
                    WrappedKey = table.Column<string>(type: "text", nullable: false),
                    WrappedIv = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChatMessageKeys", x => new { x.MessageId, x.DeviceId });
                    // No FK to UserChatDeviceKeys, deliberately: pruning a
                    // device's key row must never cascade into deleting the
                    // history already wrapped for it.
                    table.ForeignKey(
                        name: "FK_ChatMessageKeys_ChatMessages_MessageId",
                        column: x => x.MessageId,
                        principalTable: "ChatMessages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            // Every account's single existing key becomes device id "legacy" —
            // the row that keeps version-1 (pairwise) history decryptable after
            // this upgrade. It is never regenerated and never republished under
            // that id; only the client's own upgrade path writes a new,
            // permanent device id alongside it.
            migrationBuilder.Sql(
                @"INSERT INTO ""UserChatDeviceKeys"" (""UserId"", ""DeviceId"", ""PublicKeyJwk"", ""CreatedAt"", ""LastSeenAt"")
                  SELECT ""UserId"", 'legacy', ""PublicKeyJwk"", ""CreatedAt"", ""UpdatedAt""
                  FROM ""UserChatKeys"";");

            migrationBuilder.DropTable(
                name: "UserChatKeys");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "UserChatKeys",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PublicKeyJwk = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserChatKeys", x => x.UserId);
                    table.ForeignKey(
                        name: "FK_UserChatKeys_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            // Best-effort restore of the "legacy" row per user. Any additional
            // per-device rows minted after the upgrade have no home in the old
            // schema and are dropped along with the tables below.
            migrationBuilder.Sql(
                @"INSERT INTO ""UserChatKeys"" (""UserId"", ""PublicKeyJwk"", ""CreatedAt"", ""UpdatedAt"")
                  SELECT ""UserId"", ""PublicKeyJwk"", ""CreatedAt"", ""LastSeenAt""
                  FROM ""UserChatDeviceKeys""
                  WHERE ""DeviceId"" = 'legacy';");

            migrationBuilder.DropTable(
                name: "ChatMessageKeys");

            migrationBuilder.DropTable(
                name: "UserChatDeviceKeys");

            migrationBuilder.DropColumn(
                name: "EphemeralPublicKeyJwk",
                table: "ChatMessages");
        }
    }
}
