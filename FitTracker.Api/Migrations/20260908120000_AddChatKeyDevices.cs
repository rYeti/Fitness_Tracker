using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitTracker.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddChatKeyDevices : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // UserChatKeys moves from "one row per user" to "one row per
            // device" — see docs/chat-multi-device-keys.md for the incident
            // that made this necessary: a second device silently overwrote
            // the first's row, so the first device could no longer read
            // anything the second sent (its own messages included), kept
            // sending unreadably to the peer, and the peer's own
            // decryption-failure recovery eventually discarded the first
            // device's key from its cache too, taking the conversation's
            // history with it.
            //
            // UserId stops being the primary key; a surrogate Id takes over,
            // matching every other table in this schema, and the
            // one-row-per-device invariant moves to a unique index on
            // (UserId, DeviceId) instead. The FK on UserId is untouched by
            // any of this — it was never part of the primary key constraint
            // itself.
            migrationBuilder.DropPrimaryKey(
                name: "PK_UserChatKeys",
                table: "UserChatKeys");

            migrationBuilder.AddColumn<Guid>(
                name: "Id",
                table: "UserChatKeys",
                type: "uuid",
                nullable: false,
                defaultValueSql: "gen_random_uuid()");

            // Every row that exists before this migration was published by a
            // client that predates device ids, so it gets the one well-known
            // device id every such client implicitly shares — see
            // UserChatKey.LegacyDeviceId's own remarks for why that is a
            // single specific id rather than "no device id" as a distinct
            // state.
            migrationBuilder.AddColumn<string>(
                name: "DeviceId",
                table: "UserChatKeys",
                type: "text",
                nullable: false,
                defaultValue: "00000000-0000-0000-0000-000000000000");

            // Nullable at first so it can be backfilled per-row from an
            // existing column below, then tightened to NOT NULL — a literal
            // column default can't reference another column, the way
            // DeviceId's single constant above could.
            migrationBuilder.AddColumn<DateTime>(
                name: "LastSeenAt",
                table: "UserChatKeys",
                type: "timestamp with time zone",
                nullable: true);

            // UpdatedAt is the closest existing signal to "when was this key
            // last known current" for a pre-existing row — it was bumped on
            // every re-registration under the old single-row design, which is
            // exactly what LastSeenAt now means going forward.
            migrationBuilder.Sql(
                """UPDATE "UserChatKeys" SET "LastSeenAt" = "UpdatedAt" WHERE "LastSeenAt" IS NULL;""");

            migrationBuilder.AlterColumn<DateTime>(
                name: "LastSeenAt",
                table: "UserChatKeys",
                type: "timestamp with time zone",
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "timestamp with time zone",
                oldNullable: true);

            migrationBuilder.AddPrimaryKey(
                name: "PK_UserChatKeys",
                table: "UserChatKeys",
                column: "Id");

            migrationBuilder.CreateIndex(
                name: "IX_UserChatKeys_UserId_DeviceId",
                table: "UserChatKeys",
                columns: new[] { "UserId", "DeviceId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserChatKeys_UserId_LastSeenAt",
                table: "UserChatKeys",
                columns: new[] { "UserId", "LastSeenAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Lossy if any user has published from more than one device since
            // Up ran: restoring UserId as the sole primary key fails outright
            // if duplicate UserId values exist by then. Safe only as a
            // developer rollback taken immediately after Up, never as a
            // production migration-back path once multi-device keys are
            // actually in use — the same caveat AddChatEncryption's Down
            // already carries for a different reason (it doesn't restore
            // plaintext bodies either).
            migrationBuilder.DropIndex(
                name: "IX_UserChatKeys_UserId_LastSeenAt",
                table: "UserChatKeys");

            migrationBuilder.DropIndex(
                name: "IX_UserChatKeys_UserId_DeviceId",
                table: "UserChatKeys");

            migrationBuilder.DropPrimaryKey(
                name: "PK_UserChatKeys",
                table: "UserChatKeys");

            migrationBuilder.DropColumn(
                name: "LastSeenAt",
                table: "UserChatKeys");

            migrationBuilder.DropColumn(
                name: "DeviceId",
                table: "UserChatKeys");

            migrationBuilder.DropColumn(
                name: "Id",
                table: "UserChatKeys");

            migrationBuilder.AddPrimaryKey(
                name: "PK_UserChatKeys",
                table: "UserChatKeys",
                column: "UserId");
        }
    }
}
