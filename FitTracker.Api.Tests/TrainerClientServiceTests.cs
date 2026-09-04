using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// What <c>GET api/TrainerClient/status</c> tells the app about a user: whether
/// they're a trainer, and where — if anywhere — their Pro comes from.
///
/// Two of these are regression tests for bugs that shipped, and are commented
/// as such. Both are cheap to reintroduce and expensive to notice.
/// </summary>
public class TrainerClientServiceTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly TrainerClientService _service;

    public TrainerClientServiceTests()
    {
        _service = new TrainerClientService(
            new TrainerClientRepository(_fx.Db),
            new TrainerLicenceRepository(_fx.Db),
            new TrainerNutrientPinRepository(_fx.Db));
    }

    public void Dispose() => _fx.Dispose();

    // ── Who is a trainer ────────────────────────────────────────────────────

    [Fact]
    public async Task AUserHoldingALicenceIsATrainerEvenWithNoClients()
    {
        // The chicken-and-egg regression test. IsTrainer used to be
        // "has at least one active client", which meant a trainer who had just
        // signed up was refused the console — the only place they could invite
        // their first client from.
        var trainer = _fx.AddUser();
        _fx.AddLicence(trainer.Id);

        var status = await _service.GetStatusAsync(trainer.Id);

        Assert.True(status.IsTrainer);
        Assert.Equal(0, status.Licence!.SeatsUsed);
        Assert.Equal(TrainerLicence.FreeSeatLimit, status.Licence.SeatLimit);
    }

    [Fact]
    public async Task AUserWithoutALicenceIsNotATrainer()
    {
        var user = _fx.AddUser();

        var status = await _service.GetStatusAsync(user.Id);

        Assert.False(status.IsTrainer);
        Assert.Null(status.Licence);
    }

    [Fact]
    public async Task ReportsSeatsUsedAgainstTheLimit()
    {
        var trainer = _fx.AddUser();
        _fx.AddLicence(trainer.Id, LicenceTier.Solo, seatLimit: 10);
        _fx.FillRoster(trainer.Id, 4);
        _fx.AddRelationship(trainer.Id, null, TrainerClientStatus.Pending);

        var status = await _service.GetStatusAsync(trainer.Id);

        Assert.Equal(5, status.Licence!.SeatsUsed); // 4 active + 1 outstanding
        Assert.Equal(10, status.Licence.SeatLimit);
    }

    // ── Where Pro comes from ────────────────────────────────────────────────

    [Fact]
    public async Task ATraineeOfAFreeTierTrainerGetsNoPro()
    {
        // The loophole regression test, and the reason the free tier exists in
        // the shape it does. If this fails, anyone can register a second
        // account, give themselves a free licence, invite themselves and hold a
        // permanent Pro entitlement that nobody paid for.
        var trainer = _fx.AddUser();
        var trainee = _fx.AddUser();
        _fx.AddLicence(trainer.Id, LicenceTier.Free);
        _fx.AddRelationship(trainer.Id, trainee.Id, TrainerClientStatus.Active);

        var status = await _service.GetStatusAsync(trainee.Id);

        Assert.True(status.IsTrainerClient);
        Assert.False(status.ProFromLicence);
    }

    [Fact]
    public async Task ATraineeOfAPaidTrainerGetsPro()
    {
        var trainer = _fx.AddUser();
        var trainee = _fx.AddUser();
        _fx.AddLicence(trainer.Id, LicenceTier.Pro, seatLimit: 30);
        _fx.AddRelationship(trainer.Id, trainee.Id, TrainerClientStatus.Active);

        var status = await _service.GetStatusAsync(trainee.Id);

        Assert.True(status.ProFromLicence);
        Assert.Null(status.ProEndsAt);
    }

    [Fact]
    public async Task ATraineeKeepsProDuringTheTrainersGracePeriod_AndIsToldWhenItEnds()
    {
        var trainer = _fx.AddUser();
        var trainee = _fx.AddUser();
        var graceEnds = DateTime.UtcNow.AddDays(9);
        _fx.AddLicence(
            trainer.Id, LicenceTier.Pro, seatLimit: 30,
            status: LicenceStatus.PastDue, graceEndsAt: graceEnds);
        _fx.AddRelationship(trainer.Id, trainee.Id, TrainerClientStatus.Active);

        var status = await _service.GetStatusAsync(trainee.Id);

        Assert.True(status.ProFromLicence);
        // The trainee did nothing wrong; they get told before a feature locks.
        Assert.Equal(graceEnds, status.ProEndsAt);
    }

    [Fact]
    public async Task ATraineeLosesProOnceTheTrainersGraceHasElapsed()
    {
        var trainer = _fx.AddUser();
        var trainee = _fx.AddUser();
        _fx.AddLicence(
            trainer.Id, LicenceTier.Pro, seatLimit: 30,
            status: LicenceStatus.Canceled,
            graceEndsAt: DateTime.UtcNow.AddDays(-1));
        _fx.AddRelationship(trainer.Id, trainee.Id, TrainerClientStatus.Active);

        var status = await _service.GetStatusAsync(trainee.Id);

        Assert.False(status.ProFromLicence);
        // The relationship survives — only the entitlement lapses.
        Assert.True(status.IsTrainerClient);
    }

    [Fact]
    public async Task ARevokedTraineeGetsNoProFromTheirFormerTrainer()
    {
        var trainer = _fx.AddUser();
        var trainee = _fx.AddUser();
        _fx.AddLicence(trainer.Id, LicenceTier.Pro, seatLimit: 30);
        _fx.AddRelationship(trainer.Id, trainee.Id, TrainerClientStatus.Revoked);

        var status = await _service.GetStatusAsync(trainee.Id);

        Assert.False(status.IsTrainerClient);
        Assert.False(status.ProFromLicence);
    }

    [Fact]
    public async Task APaidTrainerGetsProThemselves()
    {
        var trainer = _fx.AddUser();
        _fx.AddLicence(trainer.Id, LicenceTier.Solo, seatLimit: 10);

        var status = await _service.GetStatusAsync(trainer.Id);

        Assert.True(status.ProFromLicence);
    }

    [Fact]
    public async Task AFreeTierTrainerGetsNoProThemselves()
    {
        // Otherwise "become a trainer" would be a one-click Pro button.
        var trainer = _fx.AddUser();
        _fx.AddLicence(trainer.Id, LicenceTier.Free);

        var status = await _service.GetStatusAsync(trainer.Id);

        Assert.False(status.ProFromLicence);
        Assert.True(status.IsTrainer);
    }

    [Fact]
    public async Task AnOwnPaidLicenceOutlivesALapsedTrainersOne()
    {
        // Someone who is both a trainer and someone else's client keeps the Pro
        // they pay for even when the trainer above them stops paying.
        var trainer = _fx.AddUser();
        var both = _fx.AddUser();
        _fx.AddLicence(
            trainer.Id, LicenceTier.Pro, seatLimit: 30,
            status: LicenceStatus.Canceled, graceEndsAt: DateTime.UtcNow.AddDays(-1));
        _fx.AddLicence(both.Id, LicenceTier.Solo, seatLimit: 10);
        _fx.AddRelationship(trainer.Id, both.Id, TrainerClientStatus.Active);

        var status = await _service.GetStatusAsync(both.Id);

        Assert.True(status.ProFromLicence);
        Assert.Null(status.ProEndsAt);
    }
}
