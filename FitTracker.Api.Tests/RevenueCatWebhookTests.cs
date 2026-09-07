using FitTracker.Api.Repositories;
using FitTracker.Api.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FitTracker.Api.Tests;

/// <summary>
/// <see cref="RevenueCatService.HandleWebhookAsync"/> end to end — the auth
/// check, the JSON parse, and above all how a webhook's <c>app_user_id</c>
/// resolves to a real user. <see cref="RevenueCatStateMachineTests"/> covers
/// what happens once a snapshot exists; nothing there constructs one from an
/// actual payload, which is exactly how a webhook that could never match a
/// real user shipped alongside the feature it was meant to power — see
/// docs/revenuecat-self-managed-pins.md.
/// </summary>
public class RevenueCatWebhookTests : IDisposable
{
    private const string Secret = "test-shared-secret";
    private readonly DbFixture _fx = new();

    public void Dispose() => _fx.Dispose();

    private RevenueCatService Service() => new(
        new RevenueCatSubscriptionRepository(_fx.Db),
        new UserRepository(_fx.Db),
        new RevenueCatStateMachine(),
        Configuration(),
        NullLogger<RevenueCatService>.Instance);

    private static IConfiguration Configuration() => new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["RevenueCat:WebhookAuthHeader"] = Secret,
        })
        .Build();

    private static string Payload(
        string appUserId,
        long expiresInMs = 30L * 24 * 60 * 60 * 1000,
        string entitlementId = "ForgeForm Pro",
        string type = "INITIAL_PURCHASE",
        string? originalAppUserId = null,
        string[]? aliases = null) =>
        $$"""
        {
          "event": {
            "type": "{{type}}",
            "app_user_id": "{{appUserId}}",
            {{(originalAppUserId is null ? "" : $"\"original_app_user_id\": \"{originalAppUserId}\",")}}
            {{(aliases is null ? "" : $"\"aliases\": [{string.Join(",", aliases.Select(a => $"\"{a}\""))}],")}}
            "entitlement_ids": ["{{entitlementId}}"],
            "expiration_at_ms": {{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() + expiresInMs}},
            "event_timestamp_ms": {{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}}
          }
        }
        """;

    [Fact]
    public async Task AUsernameAppUserIdIsResolvedAndGrantsEntitlement()
    {
        // The regression this change exists to fix: every RevenueCat customer
        // created before AccessProvider.initialize was given the real user
        // id still carries their username as app_user_id, and can never be
        // renamed to match. A webhook for one of them must still land.
        var user = _fx.AddUser();

        await Service().HandleWebhookAsync(Payload(user.UserName), Secret);

        var repo = new RevenueCatSubscriptionRepository(_fx.Db);
        Assert.True(await repo.IsEntitledAsync(user.Id));
    }

    [Fact]
    public async Task AGuidAppUserIdStillGrantsEntitlement()
    {
        var user = _fx.AddUser();

        await Service().HandleWebhookAsync(Payload(user.Id.ToString()), Secret);

        var repo = new RevenueCatSubscriptionRepository(_fx.Db);
        Assert.True(await repo.IsEntitledAsync(user.Id));
    }

    [Fact]
    public async Task AnAliasIsTriedWhenAppUserIdDoesNotResolve()
    {
        var user = _fx.AddUser();

        await Service().HandleWebhookAsync(
            Payload("$RCAnonymousID:doesnotexist", aliases: [user.UserName]), Secret);

        var repo = new RevenueCatSubscriptionRepository(_fx.Db);
        Assert.True(await repo.IsEntitledAsync(user.Id));
    }

    [Fact]
    public async Task AWellFormedGuidForNoRealUserIsDroppedWithoutThrowing()
    {
        var exception = await Record.ExceptionAsync(() =>
            Service().HandleWebhookAsync(Payload(Guid.NewGuid().ToString()), Secret));

        // No FK violation from handing an unresolved id to GetOrCreateAsync.
        Assert.Null(exception);
    }

    [Fact]
    public async Task AnUnresolvableAppUserIdIsDroppedWithoutThrowing()
    {
        var exception = await Record.ExceptionAsync(() =>
            Service().HandleWebhookAsync(Payload("not-a-known-username-or-guid"), Secret));

        Assert.Null(exception);
    }

    [Fact]
    public async Task AWrongAuthorizationHeaderIsRejected()
    {
        var user = _fx.AddUser();

        await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            Service().HandleWebhookAsync(Payload(user.UserName), "wrong-secret"));

        var repo = new RevenueCatSubscriptionRepository(_fx.Db);
        Assert.False(await repo.IsEntitledAsync(user.Id));
    }

    [Fact]
    public async Task ADifferentEntitlementWritesNothing()
    {
        var user = _fx.AddUser();

        await Service().HandleWebhookAsync(
            Payload(user.UserName, entitlementId: "SomeOtherAppsEntitlement"), Secret);

        var repo = new RevenueCatSubscriptionRepository(_fx.Db);
        Assert.Null(await repo.GetByUserAsync(user.Id));
    }
}
