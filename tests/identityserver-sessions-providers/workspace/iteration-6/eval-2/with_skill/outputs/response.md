# Admin endpoint with `ISessionManagementService`

Requires server-side sessions (`.AddServerSideSessions()`). Inject `ISessionManagementService` and protect the endpoints with an admin policy.

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;

var admin = app.MapGroup("/admin/sessions").RequireAuthorization("AdminOnly");

// (1) first page of 10, (2) next/previous page via ResultsToken
admin.MapGet("/", async (ISessionManagementService sessions, string? token, bool prior = false) =>
{
    var page = await sessions.QuerySessionsAsync(new SessionQuery
    {
        CountRequested = 10,
        ResultsToken = token,              // null => first page
        RequestPriorResults = prior        // true => previous page
    });

    return Results.Ok(new
    {
        page.ResultsToken,
        page.HasNextResults,
        page.HasPrevResults,
        page.TotalCount,
        page.CurrentPage,
        page.TotalPages,
        Sessions = page.Results.Select(s => new { s.SubjectId, s.SessionId, s.DisplayName, s.Created, s.Expires })
    });
});

// (3) revoke all sessions for a user
admin.MapDelete("/user/{subjectId}", async (string subjectId, ISessionManagementService sessions) =>
{
    await sessions.RemoveSessionsAsync(new RemoveSessionsContext
    {
        SubjectId = subjectId,
        SendBackchannelLogoutNotification = true,  // back-channel logout to clients with BackChannelLogoutUri
        RevokeConsents = false                     // keep consents
        // RemoveServerSideSession (default true) and RevokeTokens (default true) stay on
    });
    return Results.NoContent();
});
```

## Explicit paging example

```csharp
var page1 = await sessions.QuerySessionsAsync(new SessionQuery { CountRequested = 10 });

var page2 = await sessions.QuerySessionsAsync(new SessionQuery
{
    ResultsToken = page1.ResultsToken,
    CountRequested = 10
});

var back = await sessions.QuerySessionsAsync(new SessionQuery
{
    ResultsToken = page2.ResultsToken,
    RequestPriorResults = true,
    CountRequested = 10
});
```

## `RemoveSessionsContext` defaults

| Flag | Default | Effect |
|---|---|---|
| `RemoveServerSideSession` | true | delete the session record |
| `RevokeTokens` | true | revoke refresh + reference access tokens |
| `RevokeConsents` | true | remove persisted consent (**we set false**) |
| `SendBackchannelLogoutNotification` | true | notify clients with `BackChannelLogoutUri` |

You can also target one session (`SessionId`) or specific clients (`ClientIds`).

Notes: `QuerySessionsAsync` does full-text style filtering and can be slower; for plain listing by subject/session at the store level prefer the store's filter-based `GetSessionsAsync`. Also set `UserDisplayNameClaimType` if you want `DisplayName` filtering in the admin UI.
