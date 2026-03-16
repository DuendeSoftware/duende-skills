# Admin Session Management with ISessionManagementService

Here's how to build an admin endpoint that queries and terminates user sessions using `ISessionManagementService`.

## Injection and Setup

First, inject `ISessionManagementService` into your admin endpoint or controller:

```csharp
using Duende.IdentityServer.Services;

app.MapGet("/admin/sessions", async (ISessionManagementService sessionManagement) =>
{
    // 1. Query the first page of 10 sessions
    var firstPage = await sessionManagement.QuerySessionsAsync(new SessionQuery
    {
        CountRequested = 10
    });

    // 2. Get the next page using the ResultsToken from the first query
    var nextPage = await sessionManagement.QuerySessionsAsync(new SessionQuery
    {
        ResultsToken = firstPage.ResultsToken,
        CountRequested = 10
    });

    return Results.Ok(new
    {
        FirstPage = firstPage.Sessions,
        NextPage = nextPage.Sessions,
        HasMore = nextPage.HasNextResults
    });
});
```

## Terminating All Sessions for a User

```csharp
app.MapDelete("/admin/sessions/{subjectId}", async (
    string subjectId,
    ISessionManagementService sessionManagement) =>
{
    // 3. Revoke all sessions for the user
    await sessionManagement.RemoveSessionsAsync(new RemoveSessionsContext
    {
        SubjectId = subjectId,
        RemoveServerSideSession = true,           // Delete the session record
        RevokeTokens = true,                      // Revoke refresh tokens and reference tokens
        SendBackchannelLogoutNotification = true,  // Notify clients via back-channel logout
        RevokeConsents = false                     // Preserve user consent grants
    });

    return Results.NoContent();
});
```

## Key Points

- **Paging**: `QuerySessionsAsync` returns a `ResultsToken` that you pass to the next call to fetch subsequent pages. You can also set `RequestPriorResults = true` to navigate backwards.

- **`RemoveSessionsAsync` flags**: Each flag controls what gets cleaned up:
  - `RemoveServerSideSession` (default: `true`) — deletes the session record from the store
  - `RevokeTokens` (default: `true`) — revokes refresh tokens and reference access tokens
  - `RevokeConsents` (default: `true`) — removes persisted consent grants (set to `false` to preserve them)
  - `SendBackchannelLogoutNotification` (default: `true`) — sends back-channel logout notifications to clients with a `BackChannelLogoutUri`

- **Performance tip**: Prefer `GetSessionsAsync` over `QuerySessionsAsync` for simple session listing. `QuerySessionsAsync` performs a full-text search and may be slower. Use it only when you need advanced filtering by display name or other criteria.

- **Selective revocation**: You can also filter by `SessionId` (target a specific session) or `ClientIds` (target specific clients within a session).
