# Admin endpoint using ISessionManagementService

```csharp
using Duende.IdentityServer.Services;

app.MapGet("/admin/sessions", async (ISessionManagementService sessions, string? token, bool? prior) =>
{
    var result = await sessions.QuerySessionsAsync(new SessionQuery
    {
        CountRequested = 10,
        ResultsToken = token,                // null for first page
        RequestPriorResults = prior ?? false
    });

    return Results.Ok(new
    {
        result.TotalCount,
        result.CurrentPage,
        result.TotalPages,
        result.HasNextResults,
        result.HasPrevResults,
        result.ResultsToken,
        Sessions = result.Results.Select(s => new { s.SubjectId, s.SessionId, s.DisplayName, s.Created, s.Expires, s.ClientIds })
    });
}).RequireAuthorization("admin");
```

## 1. First page
`QuerySessionsAsync(new SessionQuery { CountRequested = 10 })`.

## 2. Next page
Pass back the `ResultsToken` from the previous result:

```csharp
var page1 = await sessions.QuerySessionsAsync(new SessionQuery { CountRequested = 10 });
var page2 = await sessions.QuerySessionsAsync(new SessionQuery
{
    CountRequested = 10,
    ResultsToken = page1.ResultsToken
});
// previous page: same token with RequestPriorResults = true
```

## 3. Revoke all sessions for a user

```csharp
app.MapDelete("/admin/users/{subjectId}/sessions", async (string subjectId, ISessionManagementService sessions) =>
{
    await sessions.RemoveSessionsAsync(new RemoveSessionsContext
    {
        SubjectId = subjectId,
        SendBackchannelLogoutNotification = true,
        RevokeConsents = false
        // RevokeTokens defaults to true
    });
    return Results.NoContent();
}).RequireAuthorization("admin");
```

Optionally filter with `SessionId` or `ClientIds`. This requires server-side sessions (`AddServerSideSessions()`) to be enabled, and the endpoint must be protected by an admin policy.
