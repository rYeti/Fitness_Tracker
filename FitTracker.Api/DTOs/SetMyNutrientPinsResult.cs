namespace FitTracker.Api.DTOs;

/// <summary>Outcome of a user replacing their own self-managed pinned-nutrients
/// selection — see
/// <see cref="Services.Interfaces.ITrainerClientService.SetMyNutrientPinsAsync"/>.
/// The sibling of <c>SetNutrientPinsStatus</c> (a trainer picking for a
/// client); kept as its own type rather than reused because the failure
/// modes are different — a trainer/client mismatch has no analogue here, and
/// "has an active trainer" / "not entitled" do.</summary>
public enum SetMyNutrientPinsStatus
{
    Ok,

    /// <summary>The caller has an active trainer — pins for a linked client
    /// are the trainer's to set, not a bypass through this endpoint.</summary>
    HasActiveTrainer,

    /// <summary>The caller doesn't hold the RevenueCat premium entitlement.</summary>
    NotEntitled,

    /// <summary>One or more keys didn't match <see cref="Nutrition.NutrientKeys.All"/>.</summary>
    InvalidNutrientKey,
}

public class SetMyNutrientPinsResult
{
    public SetMyNutrientPinsStatus Status { get; set; }

    /// <summary>The saved set, in order — echoed back so the caller doesn't
    /// need a second read to confirm what was actually stored.</summary>
    public List<string> PinnedNutrients { get; set; } = [];
}
