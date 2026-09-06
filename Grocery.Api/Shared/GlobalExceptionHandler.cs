using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Grocery.Api.Shared;

/// <summary>
/// The last line of defence. Anything a controller did not handle ends up here and leaves
/// as a problem details payload, so the client always gets JSON it can read and the stack
/// trace stays in the server log.
/// </summary>
public sealed class GlobalExceptionHandler(
    ILogger<GlobalExceptionHandler> logger,
    IProblemDetailsService problemDetailsService) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var problemDetails = Describe(exception);

        if (problemDetails.Status == StatusCodes.Status500InternalServerError)
        {
            logger.LogError(exception, "An unexpected error occurred.");
        }

        httpContext.Response.StatusCode = problemDetails.Status!.Value;

        return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = problemDetails,
            Exception = exception
        });
    }

    private static ProblemDetails Describe(Exception exception) => exception switch
    {
        // A rule inside the Product entity rejected the values.
        ArgumentException argumentException => new ProblemDetails
        {
            Title = argumentException.Message,
            Status = StatusCodes.Status400BadRequest
        },

        // 23505 is PostgreSQL's "unique constraint violated", i.e. a duplicate barcode
        // that slipped past the check because two requests arrived at the same time.
        DbUpdateException { InnerException: PostgresException { SqlState: "23505" } } => new ProblemDetails
        {
            Title = "Another product already uses that barcode.",
            Status = StatusCodes.Status409Conflict
        },

        _ => new ProblemDetails
        {
            Title = "An unexpected error occurred.",
            Status = StatusCodes.Status500InternalServerError
        }
    };
}
