using FitTracker.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace FitTracker.Api.Filters;

/// <summary>
/// Answers a <see cref="ClientIdGoneException"/> with 410 Gone, from any action.
/// </summary>
/// <remarks>
/// The sibling of <see cref="ClientIdConflictFilter"/>, registered globally for the same
/// reason: a controller that forgot a catch would turn a deleted id into a 500 the app
/// retries forever, rather than a 410 it answers by deleting its own copy. The body names
/// the id, as the 409's does, because a batch (a meal's foods) can be refused for one of
/// its entries and the app has to know which.
/// </remarks>
public sealed class ClientIdGoneFilter : IExceptionFilter
{
    /// <inheritdoc/>
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not ClientIdGoneException gone) return;

        context.Result = new ObjectResult(new
        {
            error = "id_deleted",
            id = gone.Id,
        })
        {
            StatusCode = StatusCodes.Status410Gone,
        };
        context.ExceptionHandled = true;
    }
}
