using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// Where trainer licences come from — and, more to the point, where they don't.
///
/// A licence is the definition of being a trainer (<c>IsTrainer = licence !=
/// null</c>), so whatever can create one decides who can reach the Trainer
/// Console. That used to include <c>GET api/TrainerLicence/me</c>, which
/// provisioned a Free licence as a side effect of reading: an ordinary user who
/// opened the plan screen once became a permanent trainer, complete with three
/// free seats and, on web, a console they landed in on every future sign-in.
///
/// Registration is now the only source. These tests pin both halves of that —
/// that reads create nothing, and that registering as a trainer does.
/// </summary>
public class TrainerProvisioningTests : IDisposable
{
    private readonly DbFixture _fx = new();

    public void Dispose() => _fx.Dispose();

    private TrainerLicenceService LicenceService() => new(
        new TrainerLicenceRepository(_fx.Db),
        new TrainerClientRepository(_fx.Db),
        new LicencePlanCatalog(Configuration()),
        new LicenceStateMachine(new LicencePlanCatalog(Configuration())),
        Configuration(),
        NullLogger<TrainerLicenceService>.Instance);

    private AuthService Auth() => new(
        new UserRepository(_fx.Db),
        Configuration(),
        _fx.Db,
        new NoopEmailService(),
        new TrainerLicenceRepository(_fx.Db),
        NullLogger<AuthService>.Instance);

    private static IConfiguration Configuration() => new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?>
        {
            // Long enough for HMAC-SHA256; the tests never inspect the token.
            ["Jwt:Key"] = "test-signing-key-that-is-long-enough-for-hs256",
            ["Jwt:Issuer"] = "forgeform-tests",
            ["Jwt:Audience"] = "forgeform-tests",
            ["Stripe:Prices:Solo"] = "price_solo_test",
        })
        .Build();

    private Task<int> LicenceCountAsync() => _fx.Db.TrainerLicences.CountAsync();

    // ── Reads never provision ───────────────────────────────────────────────

    [Fact]
    public async Task ReadingThePlanAsANonTrainerCreatesNothing()
    {
        // The regression this whole change exists for. GetMineAsync is what
        // GET api/TrainerLicence/me calls, and it used to be GetOrCreateAsync.
        var user = _fx.AddUser();

        var licence = await LicenceService().GetMineAsync(user.Id);

        Assert.Null(licence);
        Assert.Equal(0, await LicenceCountAsync());
    }

    [Fact]
    public async Task ReadingThePlanRepeatedlyStillCreatesNothing()
    {
        // Provisioning-on-read only needed one call to do its damage, so assert
        // the absence survives more than a single read.
        var user = _fx.AddUser();
        var service = LicenceService();

        for (var i = 0; i < 3; i++)
        {
            Assert.Null(await service.GetMineAsync(user.Id));
        }

        Assert.Equal(0, await LicenceCountAsync());
        Assert.False(await service.IsTrainerAsync(user.Id));
    }

    [Fact]
    public async Task StartingCheckoutAsANonTrainerIsRefusedAndCreatesNothing()
    {
        // The second route into the old hole: CreateCheckoutSessionAsync also
        // called GetOrCreateAsync, so merely asking to buy a plan minted one.
        // Refused before any Stripe call, so this test needs no Stripe key.
        var user = _fx.AddUser();

        var url = await LicenceService().CreateCheckoutSessionAsync(user.Id, LicenceTier.Solo);

        Assert.Null(url);
        Assert.Equal(0, await LicenceCountAsync());
    }

    [Fact]
    public async Task AnExistingTrainersPlanIsStillReadable()
    {
        // The fix must not break the ordinary case: a real trainer still sees
        // their plan, with seats counted.
        var trainer = _fx.AddUser();
        _fx.AddLicence(trainer.Id);
        _fx.FillRoster(trainer.Id, 2);

        var licence = await LicenceService().GetMineAsync(trainer.Id);

        Assert.NotNull(licence);
        Assert.Equal(nameof(LicenceTier.Free), licence!.Tier);
        Assert.Equal(2, licence.SeatsUsed);
        Assert.Equal(TrainerLicence.FreeSeatLimit, licence.SeatLimit);
    }

    // ── Registration is the only source ─────────────────────────────────────

    [Fact]
    public async Task RegisteringAsATraineeProvisionsNoLicence()
    {
        var result = await Auth().RegisterAsync(
            "trainee_sam", "sam@example.com", "correct-horse", "Sam", "Reyes",
            new DateTime(1990, 1, 1), AccountType.Trainee);

        Assert.NotNull(result);
        Assert.Equal(0, await LicenceCountAsync());
    }

    [Fact]
    public async Task RegisteringWithoutSayingAnythingProvisionsNoLicence()
    {
        // The default matters: a payload that never mentions an account type
        // must not be able to produce a trainer.
        var result = await Auth().RegisterAsync(
            "quiet_sam", "quiet@example.com", "correct-horse", "Sam", "Reyes",
            new DateTime(1990, 1, 1));

        Assert.NotNull(result);
        Assert.Equal(0, await LicenceCountAsync());
    }

    [Fact]
    public async Task RegisteringAsATrainerProvisionsExactlyOneFreeLicence()
    {
        var result = await Auth().RegisterAsync(
            "coach_ana", "ana@example.com", "correct-horse", "Ana", "Duarte",
            new DateTime(1985, 6, 12), AccountType.Trainer);

        Assert.NotNull(result);

        var licence = Assert.Single(await _fx.Db.TrainerLicences.ToListAsync());
        Assert.Equal(LicenceTier.Free, licence.Tier);
        Assert.Equal(LicenceStatus.Active, licence.Status);
        Assert.Equal(TrainerLicence.FreeSeatLimit, licence.SeatLimit);

        var user = await _fx.Db.Users.FirstAsync(u => u.UserName == "coach_ana");
        Assert.Equal(user.Id, licence.TrainerId);
    }

    [Fact]
    public async Task ATrainerRegisteredThisWayIsRecognisedAsATrainer()
    {
        // End-to-end through the predicate the app actually asks:
        // GET api/TrainerClient/status, which is what opens the console.
        await Auth().RegisterAsync(
            "coach_ana", "ana@example.com", "correct-horse", "Ana", "Duarte",
            new DateTime(1985, 6, 12), AccountType.Trainer);

        var user = await _fx.Db.Users.FirstAsync(u => u.UserName == "coach_ana");
        var status = await new TrainerClientService(
            new TrainerClientRepository(_fx.Db),
            new TrainerLicenceRepository(_fx.Db),
            new TrainerNutrientPinRepository(_fx.Db)).GetStatusAsync(user.Id);

        Assert.True(status.IsTrainer);

        // A Free tier makes someone a trainer, not a Pro subscriber. Pinned
        // here too because registration is a new way to reach a Free licence.
        Assert.False(status.ProFromLicence);
    }

    [Fact]
    public async Task AFailedRegistrationProvisionsNoLicence()
    {
        // A duplicate username is refused before the user row exists, so there
        // must be no orphaned licence left behind either.
        var auth = Auth();
        await auth.RegisterAsync(
            "coach_ana", "ana@example.com", "correct-horse", "Ana", "Duarte",
            new DateTime(1985, 6, 12), AccountType.Trainer);

        var duplicate = await auth.RegisterAsync(
            "coach_ana", "other@example.com", "correct-horse", "Ana", "Duarte",
            new DateTime(1985, 6, 12), AccountType.Trainer);

        Assert.Null(duplicate);
        Assert.Equal(1, await LicenceCountAsync());
    }

    private sealed class NoopEmailService : IEmailService
    {
        public Task SendPasswordResetEmailAsync(string toEmail, string resetLink) =>
            Task.CompletedTask;
    }
}
