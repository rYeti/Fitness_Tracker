using FitTracker.Api.Models;
using FitTracker.Api.Services;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// How a Stripe subscription's state lands on a licence: tier and seats, grace
/// windows, trial consumption, and the guards against Stripe's at-least-once,
/// occasionally-out-of-order delivery.
/// </summary>
public class LicenceStateMachineTests
{
    private const string SoloPrice = "price_solo_test";
    private const string ProPrice = "price_pro_test";

    private static LicenceStateMachine Machine()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Stripe:Prices:Solo"] = SoloPrice,
                ["Stripe:Prices:Pro"] = ProPrice,
                ["Stripe:Prices:Studio"] = "price_studio_test",
            })
            .Build();
        return new LicenceStateMachine(new LicencePlanCatalog(configuration));
    }

    private static TrainerLicence FreshLicence() => new() { TrainerId = Guid.NewGuid() };

    private static SubscriptionSnapshot Snapshot(
        string status,
        string? priceId = SoloPrice,
        DateTime? eventTime = null) => new(
            SubscriptionId: "sub_123",
            CustomerId: "cus_123",
            PriceId: priceId,
            StripeStatus: status,
            CurrentPeriodEnd: DateTime.UtcNow.AddDays(30),
            EventTime: eventTime ?? DateTime.UtcNow);

    // ── Tier and seats ──────────────────────────────────────────────────────

    [Fact]
    public void MapsPriceToTierAndSeatLimit()
    {
        var licence = FreshLicence();

        Machine().Apply(licence, Snapshot("active", ProPrice));

        Assert.Equal(LicenceTier.Pro, licence.Tier);
        Assert.Equal(30, licence.SeatLimit);
        Assert.Equal(LicenceStatus.Active, licence.Status);
        Assert.True(licence.GrantsPro);
    }

    [Fact]
    public void AnUnknownPriceLeavesTheTierAlone()
    {
        // A price id missing from config is a deployment mistake. Reacting by
        // downgrading the trainer to Free would strip Pro from their entire
        // roster over a typo.
        var licence = FreshLicence();
        Machine().Apply(licence, Snapshot("active", ProPrice));

        Machine().Apply(licence, Snapshot("active", "price_not_ours",
            eventTime: DateTime.UtcNow.AddMinutes(1)));

        Assert.Equal(LicenceTier.Pro, licence.Tier);
        Assert.Equal(30, licence.SeatLimit);
    }

    [Fact]
    public void UpgradingChangesSeatsImmediately()
    {
        var licence = FreshLicence();
        var machine = Machine();
        machine.Apply(licence, Snapshot("active", SoloPrice));
        Assert.Equal(10, licence.SeatLimit);

        machine.Apply(licence, Snapshot("active", ProPrice,
            eventTime: DateTime.UtcNow.AddMinutes(1)));

        Assert.Equal(30, licence.SeatLimit);
    }

    // ── Grace ───────────────────────────────────────────────────────────────

    [Fact]
    public void PaymentFailureOpensAGraceWindow()
    {
        var licence = FreshLicence();
        var machine = Machine();
        machine.Apply(licence, Snapshot("active"));

        var failedAt = DateTime.UtcNow.AddMinutes(1);
        machine.Apply(licence, Snapshot("past_due", eventTime: failedAt));

        Assert.Equal(LicenceStatus.PastDue, licence.Status);
        Assert.Equal(failedAt + TrainerLicence.GracePeriod, licence.GraceEndsAt);
        // Still working — a card that fails on a Sunday shouldn't take a whole
        // roster down before anyone can fix it.
        Assert.True(licence.IsEntitled);
        Assert.True(licence.GrantsPro);
    }

    [Fact]
    public void RepeatedFailuresDoNotExtendTheGraceWindow()
    {
        // Otherwise a trainer could ride an unpaid licence indefinitely by
        // letting the same card fail over and over.
        var licence = FreshLicence();
        var machine = Machine();
        machine.Apply(licence, Snapshot("active"));

        var first = DateTime.UtcNow.AddMinutes(1);
        machine.Apply(licence, Snapshot("past_due", eventTime: first));
        var opened = licence.GraceEndsAt;

        machine.Apply(licence, Snapshot("past_due", eventTime: first.AddDays(3)));

        Assert.Equal(opened, licence.GraceEndsAt);
    }

    [Fact]
    public void RecoveryClosesTheGraceWindow()
    {
        var licence = FreshLicence();
        var machine = Machine();
        machine.Apply(licence, Snapshot("past_due"));
        Assert.NotNull(licence.GraceEndsAt);

        machine.Apply(licence, Snapshot("active", eventTime: DateTime.UtcNow.AddMinutes(1)));

        Assert.Null(licence.GraceEndsAt);
        Assert.Equal(LicenceStatus.Active, licence.Status);
    }

    [Fact]
    public void CancellationKeepsTheTierSoGraceStillGrantsPro()
    {
        // Dropping to Free on cancel would make the grace window pointless:
        // GrantsPro requires a paid tier, so the trainees would lose Pro
        // instantly rather than after 14 days.
        var licence = FreshLicence();
        var machine = Machine();
        machine.Apply(licence, Snapshot("active", ProPrice));

        machine.Apply(licence, Snapshot("canceled", ProPrice,
            eventTime: DateTime.UtcNow.AddMinutes(1)));

        Assert.Equal(LicenceTier.Pro, licence.Tier);
        Assert.Equal(LicenceStatus.Canceled, licence.Status);
        Assert.True(licence.GrantsPro);
    }

    [Fact]
    public void ProStopsOnceTheGraceWindowElapses()
    {
        var licence = FreshLicence();
        var machine = Machine();
        var cancelledAt = DateTime.UtcNow - TrainerLicence.GracePeriod - TimeSpan.FromDays(1);
        machine.Apply(licence, Snapshot("canceled", ProPrice, eventTime: cancelledAt));

        Assert.False(licence.IsEntitled);
        Assert.False(licence.GrantsPro);
    }

    // ── Trials ──────────────────────────────────────────────────────────────

    [Fact]
    public void TrialingGrantsProAndBurnsTheTrial()
    {
        var licence = FreshLicence();

        Machine().Apply(licence, Snapshot("trialing", ProPrice));

        Assert.Equal(LicenceStatus.Trialing, licence.Status);
        Assert.True(licence.GrantsPro);
        Assert.True(licence.HasUsedTrial);
    }

    [Fact]
    public void TheTrialFlagIsNeverCleared()
    {
        // Cancel-and-resubscribe must not mint a fresh free fortnight of Pro.
        var licence = FreshLicence();
        var machine = Machine();
        machine.Apply(licence, Snapshot("trialing"));
        machine.Apply(licence, Snapshot("canceled", eventTime: DateTime.UtcNow.AddDays(1)));
        machine.Apply(licence, Snapshot("active", eventTime: DateTime.UtcNow.AddDays(2)));

        Assert.True(licence.HasUsedTrial);
    }

    // ── Delivery guarantees ─────────────────────────────────────────────────

    [Fact]
    public void ReplayingTheSameEventChangesNothing()
    {
        var licence = FreshLicence();
        var machine = Machine();
        var snapshot = Snapshot("active", ProPrice);
        machine.Apply(licence, snapshot);

        var before = (licence.Tier, licence.SeatLimit, licence.Status, licence.GraceEndsAt);
        machine.Apply(licence, snapshot);

        Assert.Equal(before, (licence.Tier, licence.SeatLimit, licence.Status, licence.GraceEndsAt));
    }

    [Fact]
    public void AStaleEventIsIgnored()
    {
        // Stripe can deliver out of order. A "payment failed" that arrives after
        // the "payment succeeded" which resolved it must not re-break the licence.
        var licence = FreshLicence();
        var machine = Machine();
        var recoveredAt = DateTime.UtcNow;
        machine.Apply(licence, Snapshot("active", eventTime: recoveredAt));

        var applied = machine.Apply(
            licence, Snapshot("past_due", eventTime: recoveredAt.AddMinutes(-5)));

        Assert.False(applied);
        Assert.Equal(LicenceStatus.Active, licence.Status);
        Assert.Null(licence.GraceEndsAt);
    }

    [Fact]
    public void AnUnrecognisedStripeStatusIsTreatedAsUnhealthy()
    {
        // Failing open here would mean a status we've never seen silently keeps
        // handing out Pro.
        var licence = FreshLicence();

        Machine().Apply(licence, Snapshot("something_new"));

        Assert.Equal(LicenceStatus.PastDue, licence.Status);
        Assert.NotNull(licence.GraceEndsAt);
    }
}
