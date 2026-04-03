# Admin Endpoint for Session Querying and Termination

Here's how to build an admin endpoint for managing user sessions in Duende IdentityServer.

## Injecting the Session Management Service

```csharp
using Duende.IdentityServer.Services;

public class SessionAdminController
{
    private readonly ISessionManagementService _sessionManagementService;

    public SessionAdminController(ISessionManagementService sessionManagementService)
    {
        _sessionManagementService = sessionManagementService;
    }
}
```

## 1. Query the First Page of 10 Sessions

```csharp
public async Task<object> GetFirstPageAsync()
{
    var result = await _sessionManagementService.QuerySessionsAsync(new SessionQuery
    {
        CountRequested = 10
    });

    return result;
}
```

## 2. Get the Next Page

To get the next page, you need to use the continuation token from the previous result:

```csharp
public async Task<object> GetNextPageAsync(string continuationToken)
{
    var result = await _sessionManagementService.QuerySessionsAsync(new SessionQuery
    {
        ResultsToken = continuationToken,
        CountRequested = 10
    });

    return result;
}
```

The `ResultsToken` property from the first query result is used to retrieve the next page of results.

## 3. Revoke All Sessions for a User

To terminate all sessions and trigger back-channel logout, while keeping consent grants:

```csharp
public async Task RevokeAllSessionsAsync(string subjectId)
{
    await _sessionManagementService.RemoveSessionsAsync(new RemoveSessionsContext
    {
        SubjectId = subjectId,
        RemoveServerSideSession = true,
        RevokeTokens = true,
        SendBackchannelLogoutNotification = true,
        RevokeConsents = false
    });
}
```

This configuration will:
- Remove the server-side session from the store
- Revoke any associated refresh tokens
- Send back-channel logout notifications to clients with a logout URI
- Keep the user's consent grants intact

## Usage in a Minimal API

```csharp
app.MapGet("/admin/sessions", async (ISessionManagementService sessionMgmt, string? token) =>
{
    var result = await sessionMgmt.QuerySessionsAsync(new SessionQuery
    {
        ResultsToken = token,
        CountRequested = 10
    });
    return Results.Ok(result);
});

app.MapDelete("/admin/sessions/{subjectId}", async (ISessionManagementService sessionMgmt, string subjectId) =>
{
    await sessionMgmt.RemoveSessionsAsync(new RemoveSessionsContext
    {
        SubjectId = subjectId,
        RevokeConsents = false
    });
    return Results.NoContent();
});
```

Note that IdentityServer needs to be configured with server-side sessions enabled for these APIs to function properly.
