# Admin Session Management with ISessionManagementService

Here's how to query and revoke user sessions using Duende IdentityServer's `ISessionManagementService`.

## Querying Sessions with Paging

```csharp
using Duende.IdentityServer.Services;

app.MapGet("/admin/sessions", async (ISessionManagementService sessionManagement) =>
{
    // 1. Query the first page of 10 sessions
    var firstPage = await sessionManagement.QuerySessionsAsync(new SessionQuery
    {
        CountRequested = 10
    });

    // 2. Get the next page using the ResultsToken
    var nextPage = await sessionManagement.QuerySessionsAsync(new SessionQuery
    {
        ResultsToken = firstPage.ResultsToken,
        CountRequested = 10
    });

    return Results.Ok(new
    {
        FirstPage = firstPage.Sessions,
        NextPage = nextPage.Sessions
    });
});
```

## Revoking Sessions for a User

```csharp
app.MapDelete("/admin/sessions/{subjectId}", async (
    string subjectId,
    ISessionManagementService sessionManagement) =>
{
    await sessionManagement.RemoveSessionsAsync(new RemoveSessionsContext
    {
        SubjectId = subjectId,
        RemoveServerSideSession = true,
        RevokeTokens = true,
        SendBackchannelLogoutNotification = true,
        RevokeConsents = false  // Keep user consents intact
    });

    return Results.NoContent();
});
```

## Notes

- `QuerySessionsAsync` supports paging via `ResultsToken` — pass the token from the previous result to get the next page
- `RemoveSessionsAsync` lets you control exactly what gets revoked through its flags
- Setting `RevokeConsents = false` preserves the user's consent grants while still terminating sessions and revoking tokens
- Back-channel logout notifications are sent by default to any client with a `BackChannelLogoutUri` configured
