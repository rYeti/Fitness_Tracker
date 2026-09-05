using FitTracker.Api.Models;
using FitTracker.Api.Services;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// How a RevenueCat webhook event lands on a subscription row: liveness is
/// always <c>ExpiresAt</c> vs now, so there's no status/tier mapping to test —
/// only the ordering guard against RevenueCat's at-least-once, occasionally
/// out-of-order delivery. Mirrors <see cref="LicenceStateMachineTests"/>.
/// </summary>
public class RevenueCatStateMachineTests
{
    private static RevenueCatSubscription FreshSubscription() => new() { UserId = Guid.NewGuid() };

    private static RevenueCatSnapshot Snapshot(DateTime? expiresAt, DateTime? eventTime = null) => new(
        UserId: Guid.NewGuid(),
        ExpiresAt: expiresAt,
        EventTime: eventTime ?? DateTime.UtcNow);

    [Fact]
    public void ANewerEventExtendsExpiry()
    {
        var subscription = FreshSubscription();
        var machine = new RevenueCatStateMachine();
        var firstExpiry = DateTime.UtcNow.AddDays(30);
        machine.Apply(subscription, Snapshot(firstExpiry));

        var laterExpiry = DateTime.UtcNow.AddDays(60);
        var applied = machine.Apply(
            subscription, Snapshot(laterExpiry, eventTime: DateTime.UtcNow.AddMinutes(1)));

        Assert.True(applied);
        Assert.Equal(laterExpiry, subscription.ExpiresAt);
    }

    [Fact]
    public void AnOutOfOrderEventIsIgnored()
    {
        // RevenueCat can deliver out of order. A stale renewal confirmation
        // arriving after a more recent cancellation must not resurrect it.
        var subscription = FreshSubscription();
        var machine = new RevenueCatStateMachine();
        var recoveredAt = DateTime.UtcNow;
        machine.Apply(subscription, Snapshot(DateTime.UtcNow.AddDays(30), eventTime: recoveredAt));

        var applied = machine.Apply(
            subscription, Snapshot(DateTime.UtcNow.AddDays(-1), eventTime: recoveredAt.AddMinutes(-5)));

        Assert.False(applied);
        Assert.True(subscription.IsEntitled);
    }

    [Fact]
    public void APastExpiryComputesNotEntitledWithNoSpecialCasing()
    {
        // No EXPIRATION-specific code path needed: the event's own expiry
        // timestamp already puts IsEntitled in the past at read time.
        var subscription = FreshSubscription();
        var machine = new RevenueCatStateMachine();

        machine.Apply(subscription, Snapshot(DateTime.UtcNow.AddDays(-1)));

        Assert.False(subscription.IsEntitled);
    }

    [Fact]
    public void ReplayingTheSameEventChangesNothing()
    {
        var subscription = FreshSubscription();
        var machine = new RevenueCatStateMachine();
        var snapshot = Snapshot(DateTime.UtcNow.AddDays(30));
        machine.Apply(subscription, snapshot);
        var before = (subscription.ExpiresAt, subscription.LastEventAt);

        machine.Apply(subscription, snapshot);

        Assert.Equal(before, (subscription.ExpiresAt, subscription.LastEventAt));
    }

    [Fact]
    public void ANullExpiryLeavesTheSubscriptionNotEntitled()
    {
        var subscription = FreshSubscription();
        var machine = new RevenueCatStateMachine();

        machine.Apply(subscription, Snapshot(expiresAt: null));

        Assert.False(subscription.IsEntitled);
    }
}
