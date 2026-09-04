using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// The three numbers above the roster: how many clients, how many sessions completed this
/// week, and the average adherence across the clients who had anything scheduled.
///
/// Like the roster, this had no tests, and for the same reason it was worth writing them
/// before touching it: the endpoint recomputed the roster's data through a second window,
/// in a second loop, and nothing anywhere said what it was supposed to answer.
/// </summary>
public class TrainerDashboardKpiTests : IDisposable
{
    private readonly DbFixture _fx = new();
    private readonly TrainerConsoleService _console;
    private readonly User _trainer;

    public TrainerDashboardKpiTests()
    {
        _trainer = _fx.AddUser("Dana", "Whitfield");
        _console = new TrainerConsoleService(
            new TrainerClientService(
                new TrainerClientRepository(_fx.Db),
                new TrainerLicenceRepository(_fx.Db),
                new TrainerNutrientPinRepository(_fx.Db),
                new UserNutrientPinRepository(_fx.Db),
                new RevenueCatSubscriptionRepository(_fx.Db)),
            null!,
            new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db)),
            new ScheduledWorkoutService(new ScheduledWorkoutRepository(_fx.Db)),
            null!,
            null!,
            null!,
            null!,
            null!,
            null!);
    }

    public void Dispose() => _fx.Dispose();

    /// <summary>The Monday of the current week, in UTC — the same boundary the service uses.</summary>
    /// <remarks>Spelled the same way deliberately. The point of these tests is the counting,
    /// not the calendar; the calendar itself is pinned by
    /// <see cref="TheWeekStartsOnMondayEvenWhenTodayIsSunday"/>.</remarks>
    private static DateTime WeekStart
    {
        get
        {
            var today = DateTime.UtcNow.Date;
            return today.AddDays(-(((int)today.DayOfWeek + 6) % 7));
        }
    }

    private User AddClient(string first, string last)
    {
        var client = _fx.AddUser(first, last);
        _fx.AddRelationship(_trainer.Id, client.Id, TrainerClientStatus.Active);
        return client;
    }

    [Fact]
    public async Task CountsTheTrainersActiveClients()
    {
        AddClient("Marco", "Fenn");
        AddClient("Ines", "Okafor");

        var kpis = await _console.GetDashboardKpisAsync(_trainer.Id);

        Assert.Equal(2, kpis.ActiveClientCount);
    }

    [Fact]
    public async Task SessionsThisWeekCountsOnlyCompletedSessionsInThisWeek()
    {
        var client = AddClient("Marco", "Fenn");
        var workout = _fx.AddWorkout(client.Id);

        _fx.AddSession(workout.Id, WeekStart, completed: true);
        _fx.AddSession(workout.Id, WeekStart.AddDays(2), completed: true);
        // Scheduled this week but not done — planned, not completed.
        _fx.AddSession(workout.Id, WeekStart.AddDays(3));
        // Completed, but last week.
        _fx.AddSession(workout.Id, WeekStart.AddDays(-2), completed: true);

        var kpis = await _console.GetDashboardKpisAsync(_trainer.Id);

        Assert.Equal(2, kpis.SessionsThisWeek);
    }

    [Fact]
    public async Task SessionsThisWeekSumsAcrossClients()
    {
        var one = AddClient("Marco", "Fenn");
        var two = AddClient("Ines", "Okafor");
        _fx.AddSession(_fx.AddWorkout(one.Id).Id, WeekStart, completed: true);
        _fx.AddSession(_fx.AddWorkout(two.Id).Id, WeekStart.AddDays(1), completed: true);

        var kpis = await _console.GetDashboardKpisAsync(_trainer.Id);

        Assert.Equal(2, kpis.SessionsThisWeek);
    }

    [Fact]
    public async Task AverageAdherenceIgnoresClientsWithNothingScheduledThisWeek()
    {
        var training = AddClient("Marco", "Fenn");
        var workout = _fx.AddWorkout(training.Id);
        _fx.AddSession(workout.Id, WeekStart, completed: true);
        _fx.AddSession(workout.Id, WeekStart.AddDays(1));

        // Nothing on their calendar at all. Averaging them in as 0% would report the trainer's
        // roster as half as adherent as it is, for a client who was asked to do nothing.
        AddClient("Ines", "Okafor");

        var kpis = await _console.GetDashboardKpisAsync(_trainer.Id);

        Assert.Equal(50d, kpis.AvgAdherencePercent, 3);
    }

    [Fact]
    public async Task AverageAdherenceIsZeroWhenNobodyHasAnythingScheduled()
    {
        AddClient("Marco", "Fenn");

        var kpis = await _console.GetDashboardKpisAsync(_trainer.Id);

        Assert.Equal(0d, kpis.AvgAdherencePercent, 3);
    }

    [Fact]
    public void TheWeekStartsOnMondayEvenWhenTodayIsSunday()
    {
        // Not a data test — an arithmetic one, over every day of the week.
        //
        // The old expression was `today.AddDays(-(int)today.DayOfWeek + 1)`, which is right
        // for Monday through Saturday and wrong for Sunday: DayOfWeek.Sunday is 0, so it
        // lands on *tomorrow*. Every Sunday, both numbers on this row read zero, and the
        // 12-week attendance chart beside them was shifted a week. It is untestable through
        // the service — which reads DateTime.UtcNow directly — so it is pinned here, on the
        // expression itself, until a clock seam exists.
        for (var offset = 0; offset < 7; offset++)
        {
            var day = new DateTime(2026, 8, 24, 0, 0, 0, DateTimeKind.Utc).AddDays(offset);
            var weekStart = day.AddDays(-(((int)day.DayOfWeek + 6) % 7));

            Assert.Equal(DayOfWeek.Monday, weekStart.DayOfWeek);
            Assert.True(weekStart <= day, $"{day:ddd} produced a week starting in the future");
            Assert.True((day - weekStart).TotalDays < 7);
        }
    }

    [Fact]
    public async Task KpisCostTheSameNumberOfQueriesWhateverTheRosterSize()
    {
        var solo = _fx.AddUser("Small", "Trainer");
        _fx.AddRelationship(solo.Id, _fx.AddUser("Solo", "Client").Id, TrainerClientStatus.Active);

        _fx.Queries.Reset();
        await _console.GetDashboardKpisAsync(solo.Id);
        var withOneClient = _fx.Queries.Count;

        for (var i = 0; i < 10; i++)
        {
            AddClient("Client", $"Number{i}");
        }

        _fx.Queries.Reset();
        await _console.GetDashboardKpisAsync(_trainer.Id);
        var withTenClients = _fx.Queries.Count;

        Assert.Equal(withOneClient, withTenClients);
    }
}
