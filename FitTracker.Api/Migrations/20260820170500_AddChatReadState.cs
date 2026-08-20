using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddChatReadState : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Two columns rather than one: a trainer and a client share a single
            // TrainerClients row, but "when did you last read this thread" is a
            // per-viewer fact. One shared column would let either side clear the
            // other's unread badge. Both start null, meaning "never opened", which
            // correctly counts the whole thread as unread.
            migrationBuilder.AddColumn<DateTime>(
                name: "ClientLastReadAt",
                table: "TrainerClients",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "TrainerLastReadAt",
                table: "TrainerClients",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ClientLastReadAt",
                table: "TrainerClients");

            migrationBuilder.DropColumn(
                name: "TrainerLastReadAt",
                table: "TrainerClients");
        }
    }
}
