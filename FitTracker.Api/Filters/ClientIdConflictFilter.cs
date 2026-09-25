using FitTracker.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace FitTracker.Api.Filters;

/// <summary>
/// Answers a <see cref="ClientIdConflictException"/> with 409 Conflict, from any action.
/// </summary>
/// <remarks>
/// Registered globally rather than caught per controller: every create that accepts a
/// client-chosen id can raise it, and a controller that forgot the catch would turn a
/// reused id into a 500 the app retries forever instead of a 409 it answers by minting
/// a new id.
/// </remarks>
public sealed class ClientIdConflictFilter : IExceptionFilter
{
    /// <inheritdoc/>
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not ClientIdConflictException conflict) return;

        context.Result = new ConflictObjectResult(new
        {
            error = "id_in_use",
            id = conflict.Id,
        });
        context.ExceptionHandled = true;
    }
}
