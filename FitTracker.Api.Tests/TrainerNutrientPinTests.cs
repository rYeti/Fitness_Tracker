using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// A trainer's pinned-nutrient selection for a client — the Nutrition tab's
/// "Tracked nutrients" picker. The write always replaces the whole set: see
/// the remarks on <see cref="Models.TrainerNutrientPin"/> for why toggling a
/// single row isn't safe, the same trap docs/trainer-console-duplicate-rows.md
/// is about for meals and sessions.
/// </summary>
public class TrainerNutrientPinTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly Guid _trainerId;
    private readonly Guid _clientId;
    private readonly TrainerConsoleService _console;

    public TrainerNutrientPinTests()
    {
        _trainerId = _fx.AddUser("Dana", "Whitfield").Id;
        _clientId = _fx.AddUser("Marco", "Fenn").Id;
        _fx.AddRelationship(_trainerId, _clientId, TrainerClientStatus.Active);

        _console = new TrainerConsoleService(
            new ActiveRelationshipStub(_trainerId, _clientId),
            null!, null!, null!, null!, null!, null!, null!, null!,
            new TrainerNutrientPinRepository(_fx.Db));
    }

    public void Dispose() => _fx.Dispose();

    [Fact]
    public async Task PutReplacesRatherThanAppends()
    {
        await _console.SetClientNutrientPinsAsync(_trainerId, _clientId, ["fibre", "sugar"]);
        var result = await _console.SetClientNutrientPinsAsync(_trainerId, _clientId, ["iron"]);

        Assert.Equal(SetNutrientPinsStatus.Ok, result.Status);
        var pins = await new TrainerNutrientPinRepository(_fx.Db).GetPinsAsync(_trainerId, _clientId);
        // Not the union of both calls — only the second call's set survives.
        Assert.Equal(["iron"], pins);
    }

    [Fact]
    public async Task PuttingTheSameSetTwiceIsANoOp()
    {
        await _console.SetClientNutrientPinsAsync(_trainerId, _clientId, ["fibre", "sugar", "sodium"]);
        await _console.SetClientNutrientPinsAsync(_trainerId, _clientId, ["fibre", "sugar", "sodium"]);

        var pins = await new TrainerNutrientPinRepository(_fx.Db).GetPinsAsync(_trainerId, _clientId);
        Assert.Equal(["fibre", "sugar", "sodium"], pins);
    }

    [Fact]
    public async Task UnknownKeysAreRejectedAndNothingIsWritten()
    {
        var result = await _console.SetClientNutrientPinsAsync(
            _trainerId, _clientId, ["fibre", "not-a-real-nutrient"]);

        Assert.Equal(SetNutrientPinsStatus.InvalidNutrientKey, result.Status);
        var pins = await new TrainerNutrientPinRepository(_fx.Db).GetPinsAsync(_trainerId, _clientId);
        Assert.Empty(pins);
    }

    [Fact]
    public async Task ATrainerWhoDoesNotTrainThisClientIsRefused()
    {
        var stranger = _fx.AddUser().Id;

        var result = await _console.SetClientNutrientPinsAsync(_trainerId, stranger, ["fibre"]);

        Assert.Equal(SetNutrientPinsStatus.NotAuthorized, result.Status);
    }

    [Fact]
    public async Task EmptySetIsAValidReplacement()
    {
        await _console.SetClientNutrientPinsAsync(_trainerId, _clientId, ["fibre"]);
        var result = await _console.SetClientNutrientPinsAsync(_trainerId, _clientId, []);

        Assert.Equal(SetNutrientPinsStatus.Ok, result.Status);
        var pins = await new TrainerNutrientPinRepository(_fx.Db).GetPinsAsync(_trainerId, _clientId);
        Assert.Empty(pins);
    }
}

/// <summary>The trainee-facing read: <c>GetMyNutrientPinsAsync</c> on the real
/// <see cref="TrainerClientService"/>, not the stub — this is the one path a
/// stub can't stand in for, since it has to resolve the caller's actual
/// active trainer relationship.</summary>
public class TraineeNutrientPinReadTests : IDisposable
{
    private readonly DbFixture _fx = new();

    public void Dispose() => _fx.Dispose();

    private TrainerClientService BuildService() => new(
        new TrainerClientRepository(_fx.Db),
        new TrainerLicenceRepository(_fx.Db),
        new TrainerNutrientPinRepository(_fx.Db),
        new UserNutrientPinRepository(_fx.Db),
        new RevenueCatSubscriptionRepository(_fx.Db));

    [Fact]
    public async Task ATraineeWithNoTrainerGetsTheDefaults()
    {
        var trainee = _fx.AddUser().Id;

        var pins = await BuildService().GetMyNutrientPinsAsync(trainee);

        Assert.Equal(["fibre", "sugar", "sodium"], pins);
    }

    [Fact]
    public async Task ATraineeSeesTheirTrainersSavedSet()
    {
        var trainerId = _fx.AddUser("Dana", "Whitfield").Id;
        var clientId = _fx.AddUser("Marco", "Fenn").Id;
        _fx.AddRelationship(trainerId, clientId, TrainerClientStatus.Active);
        await new TrainerNutrientPinRepository(_fx.Db).ReplacePinsAsync(
            trainerId, clientId, ["iron", "vitc"]);

        var pins = await BuildService().GetMyNutrientPinsAsync(clientId);

        Assert.Equal(["iron", "vitc"], pins);
    }

    [Fact]
    public async Task ATraineeWhoseTrainerNeverChoseGetsTheDefaults()
    {
        var trainerId = _fx.AddUser("Dana", "Whitfield").Id;
        var clientId = _fx.AddUser("Marco", "Fenn").Id;
        _fx.AddRelationship(trainerId, clientId, TrainerClientStatus.Active);

        var pins = await BuildService().GetMyNutrientPinsAsync(clientId);

        Assert.Equal(["fibre", "sugar", "sodium"], pins);
    }
}

/// <summary>An unlinked user's own RevenueCat-entitled pins — the case the
/// trainer-console feature (PR #83) left uncovered: a premium user with no
/// trainer to curate pins for them. Covers both the read
/// (<c>GetMyNutrientPinsAsync</c>'s third branch) and the write
/// (<c>SetMyNutrientPinsAsync</c>) on the real <see cref="TrainerClientService"/>.</summary>
public class SelfManagedNutrientPinTests : IDisposable
{
    private readonly DbFixture _fx = new();

    public void Dispose() => _fx.Dispose();

    private TrainerClientService BuildService() => new(
        new TrainerClientRepository(_fx.Db),
        new TrainerLicenceRepository(_fx.Db),
        new TrainerNutrientPinRepository(_fx.Db),
        new UserNutrientPinRepository(_fx.Db),
        new RevenueCatSubscriptionRepository(_fx.Db));

    private async Task GrantEntitlement(Guid userId)
    {
        var subscription = await new RevenueCatSubscriptionRepository(_fx.Db).GetOrCreateAsync(userId);
        subscription.ExpiresAt = DateTime.UtcNow.AddDays(30);
        subscription.LastEventAt = DateTime.UtcNow;
        await new RevenueCatSubscriptionRepository(_fx.Db).SaveAsync(subscription);
    }

    [Fact]
    public async Task AnEntitledUnlinkedUserCanSetAndReadTheirOwnPins()
    {
        var user = _fx.AddUser().Id;
        await GrantEntitlement(user);

        var setResult = await BuildService().SetMyNutrientPinsAsync(user, ["iron", "vitc"]);
        Assert.Equal(SetMyNutrientPinsStatus.Ok, setResult.Status);

        var pins = await BuildService().GetMyNutrientPinsAsync(user);
        Assert.Equal(["iron", "vitc"], pins);
    }

    [Fact]
    public async Task AnEntitledUnlinkedUserWithNoChoiceYetGetsTheDefaults()
    {
        var user = _fx.AddUser().Id;
        await GrantEntitlement(user);

        var pins = await BuildService().GetMyNutrientPinsAsync(user);

        Assert.Equal(["fibre", "sugar", "sodium"], pins);
    }

    [Fact]
    public async Task ANonEntitledUnlinkedUserIsRefused()
    {
        var user = _fx.AddUser().Id;

        var result = await BuildService().SetMyNutrientPinsAsync(user, ["iron"]);

        Assert.Equal(SetMyNutrientPinsStatus.NotEntitled, result.Status);
        var pins = await new UserNutrientPinRepository(_fx.Db).GetPinsAsync(user);
        Assert.Empty(pins);
    }

    [Fact]
    public async Task ALinkedClientIsRefusedEvenIfEntitled()
    {
        // A linked client's pins are their trainer's to set — this isn't a
        // bypass around the coach-driven picker.
        var trainerId = _fx.AddUser("Dana", "Whitfield").Id;
        var clientId = _fx.AddUser("Marco", "Fenn").Id;
        _fx.AddRelationship(trainerId, clientId, TrainerClientStatus.Active);
        await GrantEntitlement(clientId);

        var result = await BuildService().SetMyNutrientPinsAsync(clientId, ["iron"]);

        Assert.Equal(SetMyNutrientPinsStatus.HasActiveTrainer, result.Status);
    }

    [Fact]
    public async Task UnknownKeysAreRejectedAndNothingIsWritten()
    {
        var user = _fx.AddUser().Id;
        await GrantEntitlement(user);

        var result = await BuildService().SetMyNutrientPinsAsync(user, ["iron", "not-a-real-nutrient"]);

        Assert.Equal(SetMyNutrientPinsStatus.InvalidNutrientKey, result.Status);
        var pins = await new UserNutrientPinRepository(_fx.Db).GetPinsAsync(user);
        Assert.Empty(pins);
    }

    [Fact]
    public async Task SettingReplacesRatherThanAppends()
    {
        var user = _fx.AddUser().Id;
        await GrantEntitlement(user);

        await BuildService().SetMyNutrientPinsAsync(user, ["fibre", "sugar"]);
        await BuildService().SetMyNutrientPinsAsync(user, ["iron"]);

        var pins = await new UserNutrientPinRepository(_fx.Db).GetPinsAsync(user);
        Assert.Equal(["iron"], pins);
    }

    [Fact]
    public async Task ALapsedEntitlementIsTreatedAsNotEntitled()
    {
        var user = _fx.AddUser().Id;
        var repo = new RevenueCatSubscriptionRepository(_fx.Db);
        var subscription = await repo.GetOrCreateAsync(user);
        subscription.ExpiresAt = DateTime.UtcNow.AddDays(-1);
        subscription.LastEventAt = DateTime.UtcNow;
        await repo.SaveAsync(subscription);

        var result = await BuildService().SetMyNutrientPinsAsync(user, ["iron"]);

        Assert.Equal(SetMyNutrientPinsStatus.NotEntitled, result.Status);
    }
}
