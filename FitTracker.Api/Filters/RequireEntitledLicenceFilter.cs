using FitTracker.Api.Repositories.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using System.Security.Claims;

namespace FitTracker.Api.Filters;

/// <summary>
/// Blocks writes from a trainer whose licence has lapsed past its grace window.
///
/// Reads stay open deliberately: a trainer who stops paying keeps their roster
/// and can still see it, they just can't change anything until they renew.
/// Nothing is deleted, so paying restores the console intact.
///
/// Applied per-action rather than to the whole controller so that adding a new
/// mutating endpoint is a deliberate choice — <c>[ServiceFilter(typeof(
/// RequireEntitledLicenceFilter))]</c> next to the <c>[HttpPost]</c>.
/// </summary>
public class RequireEntitledLicenceFilter(ITrainerLicenceRepository licences) : IAsyncActionFilter
{
    private readonly ITrainerLicenceRepository _licences = licences;

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var claim = context.HttpContext.User.FindFirst(ClaimTypes.NameIdentifier)
                 ?? context.HttpContext.User.FindFirst("sub");

        if (claim == null || !Guid.TryParse(claim.Value, out var trainerId))
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        var licence = await _licences.GetByTrainerAsync(trainerId);
        if (licence == null || !licence.IsEntitled)
        {
            context.Result = new ObjectResult(new
            {
                error = "licence_lapsed",
                message = "Your licence has lapsed. Renew it to make changes to your clients' plans.",
            })
            {
                StatusCode = StatusCodes.Status402PaymentRequired,
            };
            return;
        }

        await next();
    }
}
