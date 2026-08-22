namespace FitTracker.Api.Models;

/// <summary>What an account is created as.
///
/// This is the only moment the distinction is made: a Trainer account gets a
/// Free licence provisioned at registration, and holding a licence is what makes
/// someone a trainer. There is deliberately no way to convert an existing
/// account — a trainer signs up as one.
///
/// It isn't stored on <see cref="User"/>; the licence row is the record. Keeping
/// one source of truth avoids a flag and a licence disagreeing about who is a
/// trainer.</summary>
public enum AccountType
{
    /// <summary>An ordinary ForgeForm user. The default.</summary>
    Trainee,

    /// <summary>A trainer, provisioned with a Free licence on registration.</summary>
    Trainer,
}
