using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories;
using FitTracker.Api.Services;

namespace FitTracker.Api.Tests;

/// <summary>
/// The programme-week arithmetic and the kept-set count.
/// </summary>
/// <remarks>
/// <para><b>This is one half of a pair.</b> The Flutter client has a mirror
/// (<c>test/gym/deload_schedule_test.dart</c>) pinned by the same cases, because the trainee
/// app is offline-first and resolves "is today a deload" with no server while the server
/// needs the same answer for its own reads. Two implementations of one rule will drift; the
/// mitigation is that a case added to one table is added to the other.
/// See <c>docs/deload-weeks.md</c> §2b.</para>
/// </remarks>
public class PlanWeekArithmeticTests
{
    // Deliberately a Wednesday: a plan anchored mid-week is the case that breaks any
    // implementation reaching for a Monday-anchored calendar week — which the Trainer
    // Console's attendance bars genuinely are, and which is a *different* week.
    private static readonly DateTime Start = new(2026, 9, 2);

    [Fact]
    public void TheStartDayIsWeekOneNotWeekZero() =>
        Assert.Equal(1, PlanWeeks.WeekNumberFor(Start, Start));

    [Fact]
    public void DaySixIsStillWeekOneAndDaySevenRollsOver()
    {
        Assert.Equal(1, PlanWeeks.WeekNumberFor(Start, new DateTime(2026, 9, 8)));
        Assert.Equal(2, PlanWeeks.WeekNumberFor(Start, new DateTime(2026, 9, 9)));
    }

    [Fact]
    public void WeekBoundariesFollowThePlanNotTheCalendar()
    {
        // Day 27 and day 28 sit in the same Monday-anchored calendar week and are
        // different programme weeks.
        Assert.Equal(4, PlanWeeks.WeekNumberFor(Start, new DateTime(2026, 9, 29)));
        Assert.Equal(5, PlanWeeks.WeekNumberFor(Start, new DateTime(2026, 9, 30)));
    }

    [Fact]
    public void ADateBeforeThePlanStartsHasNoWeek() =>
        Assert.Null(PlanWeeks.WeekNumberFor(Start, new DateTime(2026, 9, 1)));

    [Fact]
    public void TheLastDayIsInThePlanAndTheDayAfterIsNot()
    {
        Assert.Equal(12, PlanWeeks.WeekNumberFor(Start, new DateTime(2026, 11, 24), 84));
        Assert.Null(PlanWeeks.WeekNumberFor(Start, new DateTime(2026, 11, 25), 84));
    }

    [Fact]
    public void AnOpenEndedPlanKeepsCounting() =>
        Assert.Equal(53, PlanWeeks.WeekNumberFor(Start, new DateTime(2027, 9, 2)));

    [Fact]
    public void TimeOfDayCannotMoveAWeekBoundary()
    {
        // StartDate is an instant, not a day. A plan created at 23:30 and a session logged
        // at 00:30 are an hour apart and must be the same programme day.
        var lateStart = new DateTime(2026, 9, 2, 23, 30, 0);
        Assert.Equal(1, PlanWeeks.WeekNumberFor(lateStart, new DateTime(2026, 9, 8, 0, 30, 0)));
        Assert.Equal(2, PlanWeeks.WeekNumberFor(lateStart, new DateTime(2026, 9, 9, 0, 30, 0)));
    }

    [Theory]
    // A local day is 23 or 25 hours across a changeover, so subtracting instants and taking
    // TimeSpan.Days truncates to the wrong day twice a year.
    [InlineData("2026-03-25", "2026-03-31", 1)] // spring forward, day 6
    [InlineData("2026-03-25", "2026-04-01", 2)] // spring forward, day 7
    [InlineData("2026-10-21", "2026-10-27", 1)] // falling back, day 6
    [InlineData("2026-10-21", "2026-10-28", 2)] // falling back, day 7
    public void DstChangeoversDoNotShiftAWeek(string start, string date, int expected) =>
        Assert.Equal(expected, PlanWeeks.WeekNumberFor(DateTime.Parse(start), DateTime.Parse(date)));

    [Theory]
    [InlineData(84, 12)]
    [InlineData(85, 13)] // a partial trailing week is still a week
    [InlineData(7, 1)]
    public void WeeksInRoundsAPartialTrailingWeekUp(int durationDays, int expected) =>
        Assert.Equal(expected, PlanWeeks.WeeksIn(durationDays));

    [Theory]
    [InlineData(4, 50, 2)]
    [InlineData(6, 40, 2)]
    [InlineData(4, 70, 3)]
    [InlineData(8, 25, 2)]
    public void KeptSetCountTakesTheGivenShare(int total, int percent, int expected) =>
        Assert.Equal(expected, PlanWeeks.KeptSetCount(total, percent));

    [Theory]
    // The reason MidpointRounding.AwayFromZero is passed explicitly: C# rounds halves to
    // even by default and Dart's num.round() rounds them away from zero, and the most
    // common configuration in the feature lands on a midpoint. 5 sets at the default 50%
    // is 2.5 — three sets, not the two banker's rounding would give. If any of these fail
    // after a refactor, the two halves of the pair have started disagreeing about the same
    // prescription.
    [InlineData(5, 50, 3)]
    [InlineData(3, 50, 2)]
    [InlineData(7, 50, 4)]
    [InlineData(5, 90, 5)]
    [InlineData(10, 45, 5)]
    public void KeptSetCountRoundsHalvesAwayFromZeroNotToEven(int total, int percent, int expected) =>
        Assert.Equal(expected, PlanWeeks.KeptSetCount(total, percent));

    [Theory]
    // An exercise where every set is optional is one the UI has quietly told the trainee to
    // skip — cessation arrived at by rounding rather than by anyone choosing it.
    [InlineData(2, 10, 1)]
    [InlineData(1, 10, 1)]
    [InlineData(3, 10, 1)]
    public void KeptSetCountNeverReturnsZero(int total, int percent, int expected) =>
        Assert.Equal(expected, PlanWeeks.KeptSetCount(total, percent));

    [Fact]
    public void KeptSetCountNeverExceedsTheSetsPrescribed()
    {
        Assert.Equal(2, PlanWeeks.KeptSetCount(2, 90));
        Assert.Equal(0, PlanWeeks.KeptSetCount(0, 50));
    }
}

/// <summary>Parsing and normalising the stored deload column.</summary>
public class DeloadScheduleParsingTests
{
    [Fact]
    public void RoundTripsThroughSerialisation()
    {
        var weeks = new[]
        {
            new DeloadWeek { Week = 5, VolumePercent = 50 },
            new DeloadWeek { Week = 10, VolumePercent = 40 },
        };
        Assert.Equal(weeks, DeloadSchedule.Parse(DeloadSchedule.Serialise(weeks)));
    }

    [Fact]
    public void StoresTheShareToPerformNotTheReduction()
    {
        // Guards the one ambiguity that would invert the whole feature.
        var json = DeloadSchedule.Serialise([new DeloadWeek { Week = 3, VolumePercent = 40 }]);
        Assert.Contains("\"volumePercent\":40", json);
        Assert.Equal(2, PlanWeeks.KeptSetCount(5, 40));
    }

    [Fact]
    public void SortsByWeekAndKeepsOneEntryPerWeek()
    {
        var normalised = DeloadSchedule.Normalise(
        [
            new DeloadWeek { Week = 9, VolumePercent = 50 },
            new DeloadWeek { Week = 2, VolumePercent = 60 },
            new DeloadWeek { Week = 9, VolumePercent = 30 },
        ]);
        Assert.Equal([2, 9], normalised.Select(w => w.Week));
        Assert.Equal(30, normalised.Single(w => w.Week == 9).VolumePercent);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("not json")]
    [InlineData("{\"week\":1}")]
    public void ParseIsFailSoft(string? json) =>
        Assert.Empty(DeloadSchedule.Parse(json));

    [Fact]
    public void OneUnusableEntryCostsOneWeekNotTheSchedule()
    {
        // A plan whose deload column is corrupt trains as a normal plan; it does not fail
        // to load, and one bad row does not take the good ones with it.
        var parsed = DeloadSchedule.Parse(
            """
            [{"week":4,"volumePercent":50},
             {"week":0,"volumePercent":50},
             {"week":6,"volumePercent":999},
             {"week":8,"volumePercent":40}]
            """);
        Assert.Equal([4, 8], parsed.Select(w => w.Week));
    }

    [Fact]
    public void AnEntryWithNoVolumeTakesTheDefault() =>
        Assert.Equal(50, DeloadSchedule.Parse("""[{"week":4}]""").Single().VolumePercent);

    [Theory]
    [InlineData(9, false)]   // below the floor: not a deload, just light
    [InlineData(10, true)]
    [InlineData(90, true)]
    [InlineData(91, false)]  // above the ceiling
    [InlineData(100, false)] // 100% retained is not a deload at all
    [InlineData(0, false)]   // 0% is cessation, a different intervention entirely
    public void VolumeMustBeInsideTheBand(int percent, bool valid) =>
        Assert.Equal(valid, DeloadWeek.IsValidVolumePercent(percent));
}

/// <summary>
/// Who may write a plan's deload weeks, and what a write is allowed to touch.
/// </summary>
public class DeloadWeekWriteTests : IDisposable
{
    private readonly DbFixture _fx = new();

    public void Dispose() => _fx.Dispose();

    private WorkoutPlanService BuildService() => new(
        new WorkoutPlanRepository(_fx.Db),
        new RevenueCatSubscriptionRepository(_fx.Db),
        null);

    private async Task GrantEntitlement(Guid userId)
    {
        var repo = new RevenueCatSubscriptionRepository(_fx.Db);
        var subscription = await repo.GetOrCreateAsync(userId);
        subscription.ExpiresAt = DateTime.UtcNow.AddDays(30);
        subscription.LastEventAt = DateTime.UtcNow;
        await repo.SaveAsync(subscription);
    }

    private static readonly DeloadWeek[] OneWeek =
        [new DeloadWeek { Week = 4, VolumePercent = 40 }];

    [Fact]
    public async Task AnEntitledOwnerCanSetTheirOwnDeloadWeeks()
    {
        var user = _fx.AddUser().Id;
        await GrantEntitlement(user);
        var plan = _fx.AddPlan(user, "Block A", isActive: true);

        var result = await BuildService().SetDeloadWeeksAsync(plan.Id, user, OneWeek);

        Assert.Equal(SetDeloadWeeksStatus.Ok, result.Status);
        Assert.Equal(4, Assert.Single(result.DeloadWeeks).Week);
        Assert.Equal(40, result.DeloadWeeks.Single().VolumePercent);
    }

    [Fact]
    public async Task ANonEntitledUserIsRefusedAndNothingIsWritten()
    {
        var user = _fx.AddUser().Id;
        var plan = _fx.AddPlan(user, "Block A", isActive: true);

        var result = await BuildService().SetDeloadWeeksAsync(plan.Id, user, OneWeek);

        Assert.Equal(SetDeloadWeeksStatus.NotEntitled, result.Status);
        Assert.Equal("[]", _fx.Db.WorkoutPlans.Single(p => p.Id == plan.Id).DeloadWeeksJson);
    }

    [Fact]
    public async Task ATrainerAssignedPlanIsRefusedEvenWhenEntitled()
    {
        // Ownership is checked before entitlement on purpose: buying Premium would not give
        // this client the pen, so telling them to buy it would be a lie.
        var user = _fx.AddUser().Id;
        await GrantEntitlement(user);
        var plan = _fx.AddPlan(user, "Coached block", isActive: true);
        plan.AssignedByTrainerId = Guid.NewGuid();
        await _fx.Db.SaveChangesAsync();

        var result = await BuildService().SetDeloadWeeksAsync(plan.Id, user, OneWeek);

        Assert.Equal(SetDeloadWeeksStatus.AssignedByTrainer, result.Status);
    }

    [Fact]
    public async Task TheAssigningTrainerCanWriteThroughTheConsolePath()
    {
        var trainer = Guid.NewGuid();
        var user = _fx.AddUser().Id;
        var plan = _fx.AddPlan(user, "Coached block", isActive: true);
        plan.AssignedByTrainerId = trainer;
        await _fx.Db.SaveChangesAsync();

        // The trainer's own entitlement is the console endpoint's filter to enforce; what
        // this layer checks is that the plan is theirs.
        var result = await BuildService()
            .SetDeloadWeeksAsync(plan.Id, user, OneWeek, actingTrainerId: trainer);

        Assert.Equal(SetDeloadWeeksStatus.Ok, result.Status);
    }

    [Fact]
    public async Task ADifferentTrainerCannotWriteToThisTrainersPlan()
    {
        var user = _fx.AddUser().Id;
        var plan = _fx.AddPlan(user, "Coached block", isActive: true);
        plan.AssignedByTrainerId = Guid.NewGuid();
        await _fx.Db.SaveChangesAsync();

        var result = await BuildService()
            .SetDeloadWeeksAsync(plan.Id, user, OneWeek, actingTrainerId: Guid.NewGuid());

        Assert.Equal(SetDeloadWeeksStatus.NotPermitted, result.Status);
        Assert.Equal("[]", _fx.Db.WorkoutPlans.Single(p => p.Id == plan.Id).DeloadWeeksJson);
    }

    [Fact]
    public async Task ATrainerCannotWriteToAPlanTheClientBuiltThemselves()
    {
        // The rule that makes an identity better than a bypass flag, and the one place
        // this deliberately diverges from DeleteClientWorkoutPlanAsync — which lets a
        // trainer delete any of their client's plans. §6's ownership table gives a
        // self-built programme's deloads to the client, even when they have a coach.
        var user = _fx.AddUser().Id;
        var plan = _fx.AddPlan(user, "My own block", isActive: true);
        // AssignedByTrainerId stays null: the client made this one.

        var result = await BuildService()
            .SetDeloadWeeksAsync(plan.Id, user, OneWeek, actingTrainerId: Guid.NewGuid());

        Assert.Equal(SetDeloadWeeksStatus.NotPermitted, result.Status);
        Assert.Equal("[]", _fx.Db.WorkoutPlans.Single(p => p.Id == plan.Id).DeloadWeeksJson);
    }

    [Fact]
    public async Task ATrainerWriteStillRejectsAnOutOfRangeWeek()
    {
        // Validation is shared with the trainee path rather than skipped for trainers:
        // holding the pen is not the same as being right.
        var trainer = Guid.NewGuid();
        var user = _fx.AddUser().Id;
        var plan = _fx.AddPlan(user, "Coached block", isActive: true);
        plan.AssignedByTrainerId = trainer;
        plan.DurationDays = 56; // 8 weeks
        await _fx.Db.SaveChangesAsync();

        var result = await BuildService().SetDeloadWeeksAsync(
            plan.Id, user, [new DeloadWeek { Week = 9, VolumePercent = 50 }],
            actingTrainerId: trainer);

        Assert.Equal(SetDeloadWeeksStatus.InvalidWeek, result.Status);
    }

    [Fact]
    public async Task AWeekPastTheEndOfThePlanIsRejectedRatherThanDropped()
    {
        // Rejecting rather than normalising: silently dropping the week would save a
        // schedule the caller never asked for and report it as success.
        var user = _fx.AddUser().Id;
        await GrantEntitlement(user);
        var plan = _fx.AddPlan(user, "Block A", isActive: true);
        plan.DurationDays = 56; // 8 weeks
        await _fx.Db.SaveChangesAsync();

        var result = await BuildService().SetDeloadWeeksAsync(
            plan.Id, user, [new DeloadWeek { Week = 9, VolumePercent = 50 }]);

        Assert.Equal(SetDeloadWeeksStatus.InvalidWeek, result.Status);
        Assert.Equal("[]", _fx.Db.WorkoutPlans.Single(p => p.Id == plan.Id).DeloadWeeksJson);
    }

    [Fact]
    public async Task AWriteReplacesTheWholeSetRatherThanAppending()
    {
        var user = _fx.AddUser().Id;
        await GrantEntitlement(user);
        var plan = _fx.AddPlan(user, "Block A", isActive: true);
        var service = BuildService();

        await service.SetDeloadWeeksAsync(plan.Id, user,
            [new DeloadWeek { Week = 4, VolumePercent = 50 },
             new DeloadWeek { Week = 8, VolumePercent = 50 }]);
        var result = await service.SetDeloadWeeksAsync(plan.Id, user,
            [new DeloadWeek { Week = 6, VolumePercent = 60 }]);

        Assert.Equal([6], result.DeloadWeeks.Select(w => w.Week));
    }

    [Fact]
    public async Task APlanDocumentPutCannotClobberTheDeloadWeeks()
    {
        // The whole reason deload weeks are absent from WorkoutPlanRequestDto. A device
        // that hasn't pulled a change yet pushes the plan document; that push must be
        // structurally incapable of carrying — and so of clearing — this field.
        var user = _fx.AddUser().Id;
        await GrantEntitlement(user);
        var plan = _fx.AddPlan(user, "Block A", isActive: true);
        var service = BuildService();
        await service.SetDeloadWeeksAsync(plan.Id, user, OneWeek);

        await service.UpdatePlanAsync(plan.Id, user, new WorkoutPlanRequestDto
        {
            Name = "Block A renamed",
            StartDate = DateTime.UtcNow,
            CyclePatternJson = "[]",
        });

        var after = DeloadSchedule.Parse(
            _fx.Db.WorkoutPlans.Single(p => p.Id == plan.Id).DeloadWeeksJson);
        Assert.Equal(4, Assert.Single(after).Week);
    }

    [Fact]
    public async Task ThePayloadOmitsDeloadWeeksForANonEntitledOwner()
    {
        // Absent, not emptied — a locked value is missing from the payload rather than
        // merely hidden by the client, and absent must never be read as "clear it".
        var user = _fx.AddUser().Id;
        await GrantEntitlement(user);
        var plan = _fx.AddPlan(user, "Block A", isActive: true);
        await BuildService().SetDeloadWeeksAsync(plan.Id, user, OneWeek);

        var entitled = await BuildService().GetPlanByIdAsync(plan.Id, user);
        Assert.NotNull(entitled!.DeloadWeeks);

        // Lapse the entitlement and read again.
        var repo = new RevenueCatSubscriptionRepository(_fx.Db);
        var subscription = await repo.GetOrCreateAsync(user);
        subscription.ExpiresAt = DateTime.UtcNow.AddDays(-1);
        await repo.SaveAsync(subscription);

        var lapsed = await BuildService().GetPlanByIdAsync(plan.Id, user);
        Assert.Null(lapsed!.DeloadWeeks);

        // The stored set is untouched. A lapse hides; it never deletes.
        Assert.Equal(4, Assert.Single(
            DeloadSchedule.Parse(_fx.Db.WorkoutPlans.Single(p => p.Id == plan.Id).DeloadWeeksJson)).Week);
    }

    [Fact]
    public async Task ATrainerSetDeloadIsStillSentToANonEntitledClient()
    {
        // The row a naive "premium or nothing" gate gets wrong. A client whose trainer's
        // licence lapsed would otherwise stop seeing the deload weeks their own programme
        // still contains — information loss, not a locked control.
        var user = _fx.AddUser().Id;
        var plan = _fx.AddPlan(user, "Coached block", isActive: true);
        plan.AssignedByTrainerId = Guid.NewGuid();
        await _fx.Db.SaveChangesAsync();
        await BuildService().SetDeloadWeeksAsync(
            plan.Id, user, OneWeek, actingTrainerId: plan.AssignedByTrainerId);

        var dto = await BuildService().GetPlanByIdAsync(plan.Id, user);

        Assert.NotNull(dto!.DeloadWeeks);
        Assert.Equal(4, Assert.Single(dto.DeloadWeeks!).Week);
    }
}

/// <summary>The Trainer Console's own path into the same write.</summary>
public class TrainerDeloadWeekTests : IDisposable
{
    private readonly DbFixture _fx = new();

    public void Dispose() => _fx.Dispose();

    private static readonly DeloadWeek[] OneWeek =
        [new DeloadWeek { Week = 5, VolumePercent = 40 }];

    private TrainerConsoleService BuildConsole(Guid trainer, Guid client) =>
        new(
            new ActiveRelationshipStub(trainer, client),
            null!,
            new WorkoutPlanService(new WorkoutPlanRepository(_fx.Db)),
            null!, null!, null!, null!, null!, null!, null!);

    [Fact]
    public async Task ATrainerSetsDeloadWeeksOnThePlanTheyAssigned()
    {
        var trainer = _fx.AddUser("Nina", "Brandt").Id;
        var client = _fx.AddUser().Id;
        var plan = _fx.AddPlan(client, "Coached block", isActive: true);
        plan.AssignedByTrainerId = trainer;
        await _fx.Db.SaveChangesAsync();

        var result = await BuildConsole(trainer, client)
            .SetClientDeloadWeeksAsync(trainer, client, plan.Id, OneWeek);

        Assert.Equal(SetDeloadWeeksStatus.Ok, result.Status);
        Assert.Equal(40, Assert.Single(result.DeloadWeeks).VolumePercent);
    }

    [Fact]
    public async Task SomeoneElsesTrainerIsRefused()
    {
        // The relationship gate, one layer above the plan check.
        var trainer = _fx.AddUser("Nina", "Brandt").Id;
        var client = _fx.AddUser().Id;
        var plan = _fx.AddPlan(client, "Coached block", isActive: true);
        plan.AssignedByTrainerId = trainer;
        await _fx.Db.SaveChangesAsync();

        var stranger = Guid.NewGuid();
        var result = await BuildConsole(trainer, client)
            .SetClientDeloadWeeksAsync(stranger, client, plan.Id, OneWeek);

        Assert.Equal(SetDeloadWeeksStatus.NotPermitted, result.Status);
        Assert.Equal("[]", _fx.Db.WorkoutPlans.Single(p => p.Id == plan.Id).DeloadWeeksJson);
    }

    [Fact]
    public async Task ATrainerIsRefusedOnAPlanTheClientBuiltThemselves()
    {
        // Being someone's coach is not the same as owning their programme. This is the
        // case a bool bypass could not have expressed, and the one that diverges from
        // DeleteClientWorkoutPlanAsync.
        var trainer = _fx.AddUser("Nina", "Brandt").Id;
        var client = _fx.AddUser().Id;
        var plan = _fx.AddPlan(client, "My own block", isActive: true);

        var result = await BuildConsole(trainer, client)
            .SetClientDeloadWeeksAsync(trainer, client, plan.Id, OneWeek);

        Assert.Equal(SetDeloadWeeksStatus.NotPermitted, result.Status);
        Assert.Equal("[]", _fx.Db.WorkoutPlans.Single(p => p.Id == plan.Id).DeloadWeeksJson);
    }
}

/// <summary>Stamping a completed session with the week it was performed in.</summary>
public class WasDeloadStampTests : IDisposable
{
    private readonly DbFixture _fx = new();

    public void Dispose() => _fx.Dispose();

    private ScheduledWorkoutRepository Repo() => new(_fx.Db);

    /// <summary>A client on a 12-week plan starting Wed 2 Sep 2026, deloading in week 5.</summary>
    private async Task<(Guid userId, WorkoutPlan plan, Workout workout)> SeedDeloadingPlan()
    {
        var user = _fx.AddUser();
        var plan = _fx.AddPlan(user.Id, "Block A", isActive: true);
        plan.StartDate = new DateTime(2026, 9, 2);
        plan.DurationDays = 84;
        plan.DeloadWeeksJson = DeloadSchedule.Serialise(
            [new DeloadWeek { Week = 5, VolumePercent = 50 }]);
        await _fx.Db.SaveChangesAsync();
        return (user.Id, plan, _fx.AddWorkout(user.Id));
    }

    [Fact]
    public async Task ASessionCompletedInADeloadWeekIsStampedTrue()
    {
        var (userId, plan, workout) = await SeedDeloadingPlan();
        // Day 28 — the first day of week 5.
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 9, 30), planId: plan.Id);

        Assert.True(await Repo().CompleteWorkoutAsync(session.Id, userId));

        Assert.True(_fx.Db.ScheduledWorkouts.Single(s => s.Id == session.Id).WasDeload);
    }

    [Fact]
    public async Task ASessionCompletedInANormalWeekIsStampedFalse()
    {
        // False, not null. Null means "not settled"; this one is settled and the answer
        // is no, which is what stops a reader falling back to the plan for it later.
        var (userId, plan, workout) = await SeedDeloadingPlan();
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 9, 29), planId: plan.Id);

        await Repo().CompleteWorkoutAsync(session.Id, userId);

        Assert.False(_fx.Db.ScheduledWorkouts.Single(s => s.Id == session.Id).WasDeload);
    }

    [Fact]
    public async Task AnUncompletedSessionIsNotStamped()
    {
        var (_, plan, workout) = await SeedDeloadingPlan();
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 9, 30), planId: plan.Id);

        Assert.Null(_fx.Db.ScheduledWorkouts.Single(s => s.Id == session.Id).WasDeload);
    }

    [Fact]
    public async Task ReCompletingASessionDoesNotRestampIt()
    {
        // The rule that makes this history rather than a cache. A trainer clearing the
        // deload set afterwards must not relabel what the client already did.
        var (userId, plan, workout) = await SeedDeloadingPlan();
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 9, 30), planId: plan.Id);
        await Repo().CompleteWorkoutAsync(session.Id, userId);

        plan.DeloadWeeksJson = "[]";
        await _fx.Db.SaveChangesAsync();
        await Repo().CompleteWorkoutAsync(session.Id, userId);

        Assert.True(_fx.Db.ScheduledWorkouts.Single(s => s.Id == session.Id).WasDeload);
    }

    [Fact]
    public async Task ASessionWithNoPlanIsLeftUnstamped()
    {
        // A hand-scheduled session belongs to no programme, so there is no week to be in.
        var user = _fx.AddUser();
        var workout = _fx.AddWorkout(user.Id);
        var session = _fx.AddSession(workout.Id, new DateTime(2026, 9, 30));

        await Repo().CompleteWorkoutAsync(session.Id, user.Id);

        Assert.Null(_fx.Db.ScheduledWorkouts.Single(s => s.Id == session.Id).WasDeload);
    }
}
