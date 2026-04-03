# Admin Endpoint for Session Querying and Termination

Here's how to build an admin endpoint using `ISessionManagementService` for querying sessions with paging and terminating user sessions.

## Injecting ISessionManagementService

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Models;

public class SessionAdminEndpoint
{
    private readonly ISessionManagementService _sessionManagementService;

    public SessionAdminEndpoint(ISessionManagementService sessionManagementService)
    {
        _sessionManagementService = sessionManagementService;
    }
}
```

## 1. Query the First Page of 10 Sessions

```csharp
public async Task<QueryResult<UserSession>> GetFirstPageAsync()
{
    var result = await _sessionManagementService.QuerySessionsAsync(new SessionQuery
    {
        CountRequested = 10
    });

    // result.Results contains up to 10 UserSession objects
    // result.ResultsToken is used for paging to the next page
    // result.HasPrevResults / result.HasNextResults indicate more pages
    return result;
}
```

## 2. Get the Next Page Using ResultsToken

```csharp
public async Task<QueryResult<UserSession>> GetNextPageAsync(string resultsToken)
{
    var result = await _sessionManagementService.QuerySessionsAsync(new SessionQuery
    {
        ResultsToken = resultsToken,
        CountRequested = 10
    });

    return result;
}
```

The `ResultsToken` from the previous query result is passed to the next query to retrieve the subsequent page. This is the pagination mechanism — there are no page number parameters.

## 3. Revoke All Sessions for a User (with Back-Channel Logout, without Revoking Consents)

```csharp
public async Task RevokeUserSessionsAsync(string subjectId)
{
    await _sessionManagementService.RemoveSessionsAsync(new RemoveSessionsContext
    {
        SubjectId = subjectId,
        RemoveServerSideSession = true,
        RevokeTokens = true,
        SendBackchannelLogoutNotification = true,  // true is the default
        RevokeConsents = false  // preserve consent grants
    });
}
```

This will:
- **Delete the server-side session records** (`RemoveServerSideSession = true`)
- **Revoke refresh tokens and reference access tokens** (`RevokeTokens = true`)
- **Send back-channel logout notifications** to clients that have a `BackChannelLogoutUri` configured (`SendBackchannelLogoutNotification = true`)
- **Preserve consent grants** (`RevokeConsents = false`)

## Minimal API Example

You can wire this up as minimal API endpoints:

```csharp
app.MapGet("/admin/sessions", async (ISessionManagementService sessionMgmt, string? resultsToken) =>
{
    var result = await sessionMgmt.QuerySessionsAsync(new SessionQuery
    {
        ResultsToken = resultsToken,
        CountRequested = 10
    });
    return Results.Ok(result);
}).RequireAuthorization("AdminPolicy");

app.MapDelete("/admin/sessions/{subjectId}", async (ISessionManagementService sessionMgmt, string subjectId) =>
{
    await sessionMgmt.RemoveSessionsAsync(new RemoveSessionsContext
    {
        SubjectId = subjectId,
        RemoveServerSideSession = true,
        RevokeTokens = true,
        SendBackchannelLogoutNotification = true,
        RevokeConsents = false
    });
    return Results.NoContent();
}).RequireAuthorization("AdminPolicy");
```

## Performance Note

When listing sessions for a specific user, prefer `GetSessionsAsync` over `QuerySessionsAsync`. The `QuerySessionsAsync` method performs a full-text search and may be slower. Use `QuerySessionsAsync` only when you need advanced filtering (e.g., by display name or when you need the full paging infrastructure). For simple listing by subject ID, `GetSessionsAsync` is the better choice.
