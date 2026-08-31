using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddChatEncryption : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Nullable, and no backfill. Every existing row keeps its plaintext
            // body and lands on EncryptionVersion 0, which is the honest
            // description of it: this server cannot encrypt what it was never
            // given a key for, and pretending otherwise by inventing one here
            // would put the key exactly where the whole feature says it must
            // not be. See docs/chat-encryption.md.
            migrationBuilder.AddColumn<string>(
                name: "Iv",
                table: "ChatMessages",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "EncryptionVersion",
                table: "ChatMessages",
                type: "integer",
                nullable: false,
                defaultValue: 0);

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
                    // The user id is the primary key. A user has exactly one
                    // current chat key, and a table that allowed two would need
                    // a rule for which one a sender should encrypt to.
                    table.PrimaryKey("PK_UserChatKeys", x => x.UserId);
                    table.ForeignKey(
                        name: "FK_UserChatKeys_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UserChatKeys");

            // Dropping these does not make the bodies readable again. Anything
            // written at version 1 stays ciphertext, and after this runs there
            // is nothing left recording that it is.
            migrationBuilder.DropColumn(
                name: "EncryptionVersion",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "Iv",
                table: "ChatMessages");
        }
    }
}
