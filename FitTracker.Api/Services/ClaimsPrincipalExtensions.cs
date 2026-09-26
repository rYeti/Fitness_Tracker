using System.Security.Claims;

namespace FitTracker.Api.Services;

/// <summary>Reading the signed-in user from their claims.</summary>
public static class ClaimsPrincipalExtensions
{
    /// <summary>
    /// The signed-in user's id: the <see cref="ClaimTypes.NameIdentifier"/> claim, or the bare
    /// <c>sub</c> when there is none, parsed as a <see cref="Guid"/>.
    /// </summary>
    /// <remarks>
    /// The one reading of a caller's id, for every controller, filter, middleware and hub.
    /// Tokens minted by the OAuth path carry the id as a bare <c>sub</c>. The hub once read
    /// <c>NameIdentifier</c> alone and threw on a token the controllers accepted, one entry
    /// point working and another not for the same signed-in user, because the parse had been
    /// copied and one copy had drifted. The first claim found is the one parsed. A
    /// <c>NameIdentifier</c> that isn't a GUID is a failure, not a reason to try <c>sub</c>.
    /// </remarks>
    /// <returns>False when <paramref name="user"/> is null, carries neither claim, or its
    /// claim isn't a GUID.</returns>
    public static bool TryGetUserId(this ClaimsPrincipal? user, out Guid id)
    {
        var claim = user?.FindFirst(ClaimTypes.NameIdentifier) ?? user?.FindFirst("sub");
        return Guid.TryParse(claim?.Value, out id);
    }
}
