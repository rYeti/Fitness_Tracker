using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// The Dashboard roster: one row per active client, carrying their programme, their
/// adherence over the trailing four weeks, and when they last trained.
///
/// These tests exist because that endpoint had none. It was written as a loop over the
/// roster that read each client's entire training history — every session, exercise and
/// set they had ever logged — in order to count four weeks of them and take one maximum.
/// That is correct code: it type-checks, it returns the right numbers, and at the two-client
/// scale a test fixture runs at it is not even slow. Nothing in a test suite can see it.
///
/// So these pin the *answers*, which a rewrite into set-based SQL could silently change,
/// and <see cref="RosterCostsTheSameNumberOfQueriesWhateverTheRosterSize"/> pins the
/// *shape*, which is the thing that was actually wrong.
/// </summary>
public class TrainerRosterTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly TrainerConsoleService _console;
    private readonly User _trainer;
    private readonly User _client;

    public TrainerRosterTests()
    {
        _trainer = _fx.AddUser("Dana", "Whitfield");
        _client = _fx.AddUser("Marco", "Fenn");
        _fx.AddRelationship(_trainer.Id, _client.Id, TrainerClientStatus.Active);

        _console = BuildConsole();
    }

    /// <summary>The real relationship service, not the single-client stub the other console
    /// tests use — the roster is about several clients at once, and one of these tests is
    /// specifically that a trainer's aggregate cannot pick up another trainer's clients.</summary>
    private TrainerConsoleService BuildConsole() => new(
        new TrainerClientService(
            new TrainerClientRepository(_fx.Db),
            new TrainerLicenceRepository(_fx.Db),
            new TrainerNutrientPinRepository(_fx.Db)),
        null!,
        new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db)),
        new ScheduledWorkoutService(new ScheduledWorkoutRepository(_fx.Db)),
        null!,
        null!,
        null!,
        null!,
        null!,
        new TrainerNutrientPinRepository(_fx.Db));

    public void Dispose() => _fx.Dispose();

    private static DateTime Today => DateTime.UtcNow.Date;

    // ── Adherence ───────────────────────────────────────────────────────────

    [Fact]
    public async Task AdherenceIsNullWhenNothingWasScheduled()
    {
        _fx.AddWorkout(_client.Id);

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        // Not 0. A client with nothing on their calendar has not missed anything, and a
        // roster that reports them at 0% adherent is accusing them of something.
        Assert.Null(row.AdherencePercent);
    }

    [Fact]
    public async Task AdherenceCountsCompletedOverPlannedInTheWindow()
    {
        var workout = _fx.AddWorkout(_client.Id);
        _fx.AddSession(workout.Id, Today.AddDays(-3), completed: true);
        _fx.AddSession(workout.Id, Today.AddDays(-5), completed: true);
        _fx.AddSession(workout.Id, Today.AddDays(-7));
        _fx.AddSession(workout.Id, Today.AddDays(-9));

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Equal(50d, row.AdherencePercent!.Value, 3);
    }

    [Fact]
    public async Task AdherenceCountsOnlyTheTrailingFourWeeks()
    {
        var workout = _fx.AddWorkout(_client.Id);
        _fx.AddSession(workout.Id, Today.AddDays(-2), completed: true);
        // Outside the window: a session missed two months ago is not this month's adherence.
        _fx.AddSession(workout.Id, Today.AddDays(-60));

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Equal(100d, row.AdherencePercent!.Value, 3);
    }

    [Fact]
    public async Task AdherenceExcludesSessionsScheduledForTheFuture()
    {
        var workout = _fx.AddWorkout(_client.Id);
        _fx.AddSession(workout.Id, Today.AddDays(-1), completed: true);
        // Tomorrow's session cannot have been missed yet.
        _fx.AddSession(workout.Id, Today.AddDays(1));

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Equal(100d, row.AdherencePercent!.Value, 3);
    }

    [Fact]
    public async Task ASessionLoggedLaterTodayStillCountsAsToday()
    {
        var workout = _fx.AddWorkout(_client.Id);
        // Sits after midnight-today, so an "on or before today" bound written as
        // `<= today` rather than `< tomorrow` would silently drop it.
        _fx.AddSession(workout.Id, Today.AddHours(18), completed: true);

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Equal(100d, row.AdherencePercent!.Value, 3);
    }

    // ── Sessions left behind by an abandoned plan ───────────────────────────
    // The rule these three pin is documented in docs/trainer-session-review.md. The roster
    // now applies it in SQL rather than in memory, so it has to be re-proved here.

    [Fact]
    public async Task IgnoresUntouchedSessionsFromAPlanTheClientHasMovedOff()
    {
        var workout = _fx.AddWorkout(_client.Id);
        var dead = _fx.AddPlan(_client.Id, "Old block", isActive: false);
        _fx.AddPlan(_client.Id, "Current block", isActive: true);

        _fx.AddSession(workout.Id, Today.AddDays(-3), completed: true);
        // Generated by the abandoned plan and never touched — work never asked of the client.
        _fx.AddSession(workout.Id, Today.AddDays(-4), planId: dead.Id);

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Equal(100d, row.AdherencePercent!.Value, 3);
    }

    [Fact]
    public async Task CountsAbandonedPlanSessionsTheClientActuallyEngagedWith()
    {
        var workout = _fx.AddWorkout(_client.Id);
        var exercise = _fx.AddWorkoutExercise(workout.Id, Guid.NewGuid());
        var dead = _fx.AddPlan(_client.Id, "Old block", isActive: false);

        var logged = _fx.AddSession(workout.Id, Today.AddDays(-4), planId: dead.Id);
        _fx.AddLoggedSet(logged.Id, exercise.Id, weight: 60);
        _fx.AddSession(workout.Id, Today.AddDays(-3), completed: true, planId: dead.Id);

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        // Both are real history: one was completed, the other has sets logged against it.
        Assert.Equal(50d, row.AdherencePercent!.Value, 3);
    }

    [Fact]
    public async Task CountsHandScheduledSessionsThatCarryNoPlan()
    {
        var workout = _fx.AddWorkout(_client.Id);
        _fx.AddPlan(_client.Id, "Current block", isActive: true);
        _fx.AddSession(workout.Id, Today.AddDays(-2));

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Equal(0d, row.AdherencePercent!.Value, 3);
    }

    // ── Last session, programme label, scoping ──────────────────────────────

    [Fact]
    public async Task LastSessionDateIsTheNewestCompletedSession()
    {
        var workout = _fx.AddWorkout(_client.Id);
        var completed = Today.AddDays(-4);
        _fx.AddSession(workout.Id, completed, completed: true);
        _fx.AddSession(workout.Id, Today.AddDays(-9), completed: true);
        // Newer, but never completed — it is not when they last trained.
        _fx.AddSession(workout.Id, Today.AddDays(-1));

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Equal(completed, row.LastSessionDate);
    }

    [Fact]
    public async Task LastSessionDateIsNullForAClientWhoHasNeverCompletedOne()
    {
        var workout = _fx.AddWorkout(_client.Id);
        _fx.AddSession(workout.Id, Today.AddDays(-2));

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Null(row.LastSessionDate);
    }

    [Fact]
    public async Task ProgramLabelIsTheActivePlan()
    {
        _fx.AddPlan(_client.Id, "Old block", isActive: false);
        _fx.AddPlan(_client.Id, "Hypertrophy — block 2", isActive: true);

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Equal("Hypertrophy — block 2", row.ProgramLabel);
    }

    [Fact]
    public async Task ProgramLabelIsNullWithNoActivePlan()
    {
        _fx.AddPlan(_client.Id, "Old block", isActive: false);

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Null(row.ProgramLabel);
    }

    [Fact]
    public async Task RosterIsScopedToTheTrainersOwnClients()
    {
        var otherTrainer = _fx.AddUser("Priya", "Raman");
        var otherClient = _fx.AddUser("Ines", "Okafor");
        _fx.AddRelationship(otherTrainer.Id, otherClient.Id, TrainerClientStatus.Active);

        var theirWorkout = _fx.AddWorkout(otherClient.Id);
        _fx.AddSession(theirWorkout.Id, Today.AddDays(-2), completed: true);

        var row = Assert.Single(await _console.GetRosterAsync(_trainer.Id));

        Assert.Equal(_client.Id, row.ClientId);
        // The other trainer's client trained; ours did not. The aggregate is now scoped by a
        // single `Contains` over client ids, where it used to be a loop that could only ever
        // see one client at a time — so this is the assertion standing between the two.
        Assert.Null(row.AdherencePercent);
    }

    [Fact]
    public async Task ARosterWithNoClientsIsEmpty()
    {
        var lonely = _fx.AddUser("Tomas", "Bergh");

        Assert.Empty(await _console.GetRosterAsync(lonely.Id));
    }

    // ── The shape, not the answer ───────────────────────────────────────────

    [Fact]
    public async Task RosterCostsTheSameNumberOfQueriesWhateverTheRosterSize()
    {
        var oneClient = _fx.AddUser("Solo", "Client");
        var smallTrainer = _fx.AddUser("Small", "Trainer");
        _fx.AddRelationship(smallTrainer.Id, oneClient.Id, TrainerClientStatus.Active);
        SeedSomeTraining(oneClient.Id);

        _fx.Queries.Reset();
        await _console.GetRosterAsync(smallTrainer.Id);
        var withOneClient = _fx.Queries.Count;

        var bigTrainer = _fx.AddUser("Big", "Trainer");
        for (var i = 0; i < 10; i++)
        {
            var client = _fx.AddUser("Client", $"Number{i}");
            _fx.AddRelationship(bigTrainer.Id, client.Id, TrainerClientStatus.Active);
            SeedSomeTraining(client.Id);
        }

        _fx.Queries.Reset();
        await _console.GetRosterAsync(bigTrainer.Id);
        var withTenClients = _fx.Queries.Count;

        // This is the test the original defect needed. It cannot be written as a timing
        // assertion — at fixture scale the slow version is not slow — but the cost growing
        // with the roster is exactly what was wrong, and that is visible here.
        Assert.Equal(withOneClient, withTenClients);
    }

    private void SeedSomeTraining(Guid clientId)
    {
        var workout = _fx.AddWorkout(clientId);
        _fx.AddPlan(clientId, "Block", isActive: true);
        _fx.AddSession(workout.Id, Today.AddDays(-2), completed: true);
        _fx.AddSession(workout.Id, Today.AddDays(-5));
    }
}
