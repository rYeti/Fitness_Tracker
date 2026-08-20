using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// Seat accounting and the two points where it is enforced.
///
/// The redemption-time check is the one worth staring at: a code minted while a
/// seat was free can be redeemed after the trainer filled up or downgraded, so
/// checking only at mint time makes the limit advisory rather than real.
/// </summary>
public class TrainerClientRepositoryTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly TrainerClientRepository _repo;
    private readonly User _trainer;

    public TrainerClientRepositoryTests()
    {
        _repo = new TrainerClientRepository(_fx.Db);
        _trainer = _fx.AddUser("Dana", "Whitfield");
    }

    public void Dispose() => _fx.Dispose();

    // ── Counting ────────────────────────────────────────────────────────────

    [Fact]
    public async Task CountsActiveRelationships()
    {
        _fx.AddLicence(_trainer.Id);
        _fx.FillRoster(_trainer.Id, 3);

        Assert.Equal(3, await _repo.CountSeatsUsedAsync(_trainer.Id));
    }

    [Fact]
    public async Task CountsUnexpiredPendingInvites()
    {
        _fx.AddLicence(_trainer.Id);
        _fx.AddRelationship(_trainer.Id, null, TrainerClientStatus.Pending);

        // A code that's out in the world is a seat the trainer has committed;
        // otherwise they could mint unlimited invites and blow past the limit
        // the moment they're all redeemed.
        Assert.Equal(1, await _repo.CountSeatsUsedAsync(_trainer.Id));
    }

    [Fact]
    public async Task IgnoresExpiredPendingInvites()
    {
        _fx.AddLicence(_trainer.Id);
        _fx.AddRelationship(
            _trainer.Id, null, TrainerClientStatus.Pending,
            expiresAt: DateTime.UtcNow.AddDays(-1));

        Assert.Equal(0, await _repo.CountSeatsUsedAsync(_trainer.Id));
    }

    [Fact]
    public async Task IgnoresRevokedRelationships()
    {
        _fx.AddLicence(_trainer.Id);
        _fx.AddRelationship(_trainer.Id, _fx.AddUser().Id, TrainerClientStatus.Revoked);

        Assert.Equal(0, await _repo.CountSeatsUsedAsync(_trainer.Id));
    }

    [Fact]
    public async Task CountsOnlyThisTrainersSeats()
    {
        var other = _fx.AddUser("Other", "Trainer");
        _fx.AddLicence(_trainer.Id);
        _fx.AddLicence(other.Id);
        _fx.FillRoster(other.Id, 2);

        Assert.Equal(0, await _repo.CountSeatsUsedAsync(_trainer.Id));
    }

    // ── Enforcement at mint time ────────────────────────────────────────────

    [Fact]
    public async Task CreatesInviteBelowTheLimit()
    {
        _fx.AddLicence(_trainer.Id);            // 3 seats
        _fx.FillRoster(_trainer.Id, 2);

        var result = await _repo.CreateInviteAsync(_trainer.Id);

        Assert.Equal(CreateInviteStatus.Ok, result.Status);
        Assert.NotNull(result.Invite);
        Assert.NotEmpty(result.Invite!.InviteCode);
    }

    [Fact]
    public async Task RefusesInviteAtTheLimit()
    {
        _fx.AddLicence(_trainer.Id);            // 3 seats
        _fx.FillRoster(_trainer.Id, 3);

        var result = await _repo.CreateInviteAsync(_trainer.Id);

        Assert.Equal(CreateInviteStatus.SeatLimitReached, result.Status);
        Assert.Null(result.Invite);
        Assert.Equal(3, result.SeatsUsed);
        Assert.Equal(3, result.SeatLimit);
    }

    [Fact]
    public async Task RefusesInviteWhenPendingInvitesFillTheLimit()
    {
        _fx.AddLicence(_trainer.Id);
        _fx.AddRelationship(_trainer.Id, _fx.AddUser().Id, TrainerClientStatus.Active);
        _fx.AddRelationship(_trainer.Id, null, TrainerClientStatus.Pending);
        _fx.AddRelationship(_trainer.Id, null, TrainerClientStatus.Pending);

        var result = await _repo.CreateInviteAsync(_trainer.Id);

        Assert.Equal(CreateInviteStatus.SeatLimitReached, result.Status);
    }

    [Fact]
    public async Task RefusesInviteWithoutALicence()
    {
        // Not a trainer at all — nothing to enforce a limit against.
        var result = await _repo.CreateInviteAsync(_trainer.Id);

        Assert.Equal(CreateInviteStatus.NoLicence, result.Status);
    }

    [Fact]
    public async Task RefusesInviteOnceTheLicenceHasLapsedPastGrace()
    {
        _fx.AddLicence(
            _trainer.Id, LicenceTier.Solo, seatLimit: 10,
            status: LicenceStatus.PastDue,
            graceEndsAt: DateTime.UtcNow.AddDays(-1));

        var result = await _repo.CreateInviteAsync(_trainer.Id);

        Assert.Equal(CreateInviteStatus.NotEntitled, result.Status);
    }

    [Fact]
    public async Task StillAllowsInvitesDuringGrace()
    {
        // A failed card shouldn't stop a trainer working while they fix it.
        _fx.AddLicence(
            _trainer.Id, LicenceTier.Solo, seatLimit: 10,
            status: LicenceStatus.PastDue,
            graceEndsAt: DateTime.UtcNow.AddDays(5));

        var result = await _repo.CreateInviteAsync(_trainer.Id);

        Assert.Equal(CreateInviteStatus.Ok, result.Status);
    }

    // ── Enforcement at redemption time ──────────────────────────────────────

    [Fact]
    public async Task AcceptsAValidInvite()
    {
        _fx.AddLicence(_trainer.Id);
        var client = _fx.AddUser("Priya", "Raman");
        var invite = (await _repo.CreateInviteAsync(_trainer.Id)).Invite!;

        var result = await _repo.AcceptInviteAsync(invite.InviteCode, client.Id);

        Assert.Equal(AcceptInviteStatus.Ok, result.Status);
        Assert.Equal(client.Id, result.Relationship!.ClientId);
        Assert.Equal(TrainerClientStatus.Active, result.Relationship.Status);
    }

    [Fact]
    public async Task RefusesRedemptionWhenTheTrainerFilledUpAfterMinting()
    {
        // One free seat, so the invite mints fine...
        _fx.AddLicence(_trainer.Id);
        _fx.FillRoster(_trainer.Id, 2);
        var invite = (await _repo.CreateInviteAsync(_trainer.Id)).Invite!;

        // ...then the trainer's seats are consumed elsewhere before it's used.
        // Without a check here the limit would be trivially bypassable.
        _fx.AddRelationship(_trainer.Id, _fx.AddUser().Id, TrainerClientStatus.Active);

        var client = _fx.AddUser();
        var result = await _repo.AcceptInviteAsync(invite.InviteCode, client.Id);

        Assert.Equal(AcceptInviteStatus.TrainerAtSeatLimit, result.Status);

        _fx.Db.ChangeTracker.Clear();
        var stored = _fx.Db.TrainerClients.Single(t => t.Id == invite.Id);
        Assert.Equal(TrainerClientStatus.Pending, stored.Status);
        Assert.Null(stored.ClientId);
    }

    [Fact]
    public async Task RefusesRedemptionWhenTheTrainersLicenceHasLapsed()
    {
        // Seeded directly: the invite was minted while the licence was healthy
        // and is only being redeemed now that it has lapsed.
        _fx.AddLicence(
            _trainer.Id, LicenceTier.Solo, seatLimit: 10,
            status: LicenceStatus.Canceled,
            graceEndsAt: DateTime.UtcNow.AddDays(-1));
        var invite = _fx.AddRelationship(_trainer.Id, null, TrainerClientStatus.Pending);
        var client = _fx.AddUser();

        var result = await _repo.AcceptInviteAsync(invite.InviteCode, client.Id);

        Assert.Equal(AcceptInviteStatus.TrainerNotEntitled, result.Status);
    }

    [Fact]
    public async Task DistinguishesAnExpiredCodeFromAnUnknownOne()
    {
        _fx.AddLicence(_trainer.Id);
        var expired = _fx.AddRelationship(
            _trainer.Id, null, TrainerClientStatus.Pending,
            expiresAt: DateTime.UtcNow.AddDays(-1));
        var client = _fx.AddUser();

        // "Your code has expired, ask for a new one" is actionable in a way
        // that "invalid code" is not.
        Assert.Equal(
            AcceptInviteStatus.Expired,
            (await _repo.AcceptInviteAsync(expired.InviteCode, client.Id)).Status);
        Assert.Equal(
            AcceptInviteStatus.NotFound,
            (await _repo.AcceptInviteAsync("NOSUCHCODE12", client.Id)).Status);
    }

    [Fact]
    public async Task RefusesSelfInvite()
    {
        _fx.AddLicence(_trainer.Id);
        var invite = (await _repo.CreateInviteAsync(_trainer.Id)).Invite!;

        var result = await _repo.AcceptInviteAsync(invite.InviteCode, _trainer.Id);

        Assert.Equal(AcceptInviteStatus.SelfInvite, result.Status);
    }

    [Fact]
    public async Task RedeemingRevokesTheClientsPreviousTrainer()
    {
        var oldTrainer = _fx.AddUser("Marcus", "Bell");
        _fx.AddLicence(oldTrainer.Id);
        _fx.AddLicence(_trainer.Id);
        var client = _fx.AddUser();
        var old = _fx.AddRelationship(oldTrainer.Id, client.Id, TrainerClientStatus.Active);
        var invite = (await _repo.CreateInviteAsync(_trainer.Id)).Invite!;

        await _repo.AcceptInviteAsync(invite.InviteCode, client.Id);

        _fx.Db.ChangeTracker.Clear();
        Assert.Equal(
            TrainerClientStatus.Revoked,
            _fx.Db.TrainerClients.Single(t => t.Id == old.Id).Status);
        // ...and the seat they were holding is freed for the old trainer.
        Assert.Equal(0, await _repo.CountSeatsUsedAsync(oldTrainer.Id));
    }

    // ── Freeing seats ───────────────────────────────────────────────────────

    [Fact]
    public async Task RevokingAPendingInviteFreesItsSeat()
    {
        _fx.AddLicence(_trainer.Id);
        _fx.FillRoster(_trainer.Id, 2);
        var invite = (await _repo.CreateInviteAsync(_trainer.Id)).Invite!;
        Assert.Equal(CreateInviteStatus.SeatLimitReached,
            (await _repo.CreateInviteAsync(_trainer.Id)).Status);

        Assert.True(await _repo.RevokeInviteAsync(invite.Id, _trainer.Id));

        Assert.Equal(2, await _repo.CountSeatsUsedAsync(_trainer.Id));
        Assert.Equal(CreateInviteStatus.Ok,
            (await _repo.CreateInviteAsync(_trainer.Id)).Status);
    }

    [Fact]
    public async Task OnlyTheIssuingTrainerMayRevokeAnInvite()
    {
        _fx.AddLicence(_trainer.Id);
        var invite = (await _repo.CreateInviteAsync(_trainer.Id)).Invite!;
        var stranger = _fx.AddUser();

        Assert.False(await _repo.RevokeInviteAsync(invite.Id, stranger.Id));
        Assert.Equal(1, await _repo.CountSeatsUsedAsync(_trainer.Id));
    }

    [Fact]
    public async Task AnOverLimitTrainerKeepsEveryExistingClient()
    {
        // The downgrade case: seats drop below the roster. Nothing is revoked —
        // only new invites are blocked. Clients must never be cut loose because
        // their trainer changed plan.
        _fx.AddLicence(_trainer.Id, LicenceTier.Solo, seatLimit: 10);
        _fx.FillRoster(_trainer.Id, 8);
        var licence = _fx.Db.TrainerLicences.Single(l => l.TrainerId == _trainer.Id);
        licence.SeatLimit = 3;
        _fx.Db.SaveChanges();

        Assert.Equal(8, await _repo.CountSeatsUsedAsync(_trainer.Id));
        Assert.Equal(
            CreateInviteStatus.SeatLimitReached,
            (await _repo.CreateInviteAsync(_trainer.Id)).Status);
        Assert.Equal(
            8,
            (await _repo.GetClientsAsync(_trainer.Id)).Count);
    }
}
