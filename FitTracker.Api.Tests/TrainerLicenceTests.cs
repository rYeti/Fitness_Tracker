using FitTracker.Api.Models;

namespace FitTracker.Api.Tests;

/// <summary>
/// The two entitlement predicates on <see cref="TrainerLicence"/>, which decide
/// (a) whether a trainer may use the console at all and (b) whether Pro flows
/// to that trainer and their trainees.
///
/// These are the highest-leverage assertions in the suite: <c>GrantsPro</c> is
/// the single line standing between the invite system and unlimited free Pro.
/// </summary>
public class TrainerLicenceTests
{
    private static TrainerLicence Licence(
        LicenceTier tier,
        LicenceStatus status,
        DateTime? graceEndsAt = null) => new()
        {
            TrainerId = Guid.NewGuid(),
            Tier = tier,
            Status = status,
            GraceEndsAt = graceEndsAt,
            SeatLimit = 3,
        };

    private static readonly DateTime Future = DateTime.UtcNow.AddDays(7);
    private static readonly DateTime Past = DateTime.UtcNow.AddDays(-1);

    public static TheoryData<LicenceTier, LicenceStatus, DateTime?, bool, bool> Cases => new()
    {
        // tier,               status,                grace,  entitled, grantsPro
        { LicenceTier.Free,    LicenceStatus.Active,   null,   true,  false },
        { LicenceTier.Solo,    LicenceStatus.Active,   null,   true,  true  },
        { LicenceTier.Pro,     LicenceStatus.Trialing, null,   true,  true  },
        { LicenceTier.Pro,     LicenceStatus.PastDue,  Future, true,  true  },
        { LicenceTier.Pro,     LicenceStatus.PastDue,  Past,   false, false },
        { LicenceTier.Pro,     LicenceStatus.Canceled, Future, true,  true  },
        { LicenceTier.Pro,     LicenceStatus.Canceled, Past,   false, false },
        { LicenceTier.Studio,  LicenceStatus.Canceled, null,   false, false },
        // A Free licence that lapses is still not a Pro source, and a Free
        // licence in grace is not either — Free never grants Pro, full stop.
        { LicenceTier.Free,    LicenceStatus.PastDue,  Future, true,  false },
        { LicenceTier.Free,    LicenceStatus.Canceled, Past,   false, false },
    };

    [Theory]
    [MemberData(nameof(Cases))]
    public void EvaluatesEntitlementAndProGrant(
        LicenceTier tier,
        LicenceStatus status,
        DateTime? grace,
        bool expectedEntitled,
        bool expectedGrantsPro)
    {
        var licence = Licence(tier, status, grace);

        Assert.Equal(expectedEntitled, licence.IsEntitled);
        Assert.Equal(expectedGrantsPro, licence.GrantsPro);
    }

    [Fact]
    public void FreeTierNeverGrantsPro_HoweverHealthyTheLicence()
    {
        // The loophole regression test. If this ever goes green-to-red, someone
        // has made the free tier a Pro dispenser and anyone with a throwaway
        // email can self-invite their way to a paid entitlement.
        foreach (var status in Enum.GetValues<LicenceStatus>())
        {
            var licence = Licence(LicenceTier.Free, status, Future);
            Assert.False(licence.GrantsPro);
        }
    }

    [Fact]
    public void GraceIsInclusiveOfPaidTiersOnly_ButEntitlementSurvivesForFree()
    {
        // Free in grace keeps console access (nothing was being paid for, so
        // there's nothing to cut off) while still granting no Pro.
        var free = Licence(LicenceTier.Free, LicenceStatus.PastDue, Future);
        Assert.True(free.IsEntitled);
        Assert.False(free.GrantsPro);
    }
}
