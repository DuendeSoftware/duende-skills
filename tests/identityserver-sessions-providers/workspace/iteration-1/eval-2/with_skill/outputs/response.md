# Using ISessionManagementService for Session Management

`ISessionManagementService` provides APIs for querying and terminating user sessions programmatically.

## Admin Endpoint Implementation

```csharp
using Duende.IdentityServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api/admin/sessions")]
[Authorize(Policy = "AdminOnly")]
public class SessionAdminController : ControllerBase
{
    private readonly ISessionManagementService _sessionManagement;

    public SessionAdminController(ISessionManagementService sessionManagement)
    {
        _sessionManagement = sessionManagement;
    }

    // (1) Query the first page of 10 sessions
    [HttpGet]
    public async Task<IActionResult> GetSessions()
    {
        var result = await _sessionManagement.QuerySessionsAsync(new SessionQuery
        {
            CountRequested = 10
        });

        return Ok(new
        {
            Sessions = result.Sessions,
            HasMore = result.HasNextResults,
            ResultsToken = result.ResultsToken,
            TotalCount = result.TotalCount
        });
    }

    // (2) Get the next page using ResultsToken
    [HttpGet("next")]
    public async Task<IActionResult> GetNextPage([FromQuery] string resultsToken)
    {
        var result = await _sessionManagement.QuerySessionsAsync(new SessionQuery
        {
            ResultsToken = resultsToken,
            CountRequested = 10
        });

        return Ok(new
        {
            Sessions = result.Sessions,
            HasMore = result.HasNextResults,
            ResultsToken = result.ResultsToken,
            TotalCount = result.TotalCount
        });
    }

    // (3) Revoke all sessions for a user — back-channel logout yes, consents no
    [HttpDelete("{subjectId}")]
    public async Task<IActionResult> RevokeUserSessions(string subjectId)
    {
        await _sessionManagement.RemoveSessionsAsync(new RemoveSessionsContext
        {
            SubjectId = subjectId,
            RemoveServerSideSession = true,
            RevokeTokens = true,
            SendBackchannelLogoutNotification = true,
            RevokeConsents = false
        });

        return NoContent();
    }
}
```

## Performance Note

For simple session listing (e.g., showing a user their active sessions), prefer `GetSessionsAsync` over `QuerySessionsAsync`. `GetSessionsAsync` is faster because it looks up sessions by subject ID directly. `QuerySessionsAsync` performs a more expensive search and should be reserved for administrative use cases that need filtering by display name or other criteria.

```csharp
// Prefer this for simple listing by user
var sessions = await _sessionManagement.GetSessionsAsync(
    new GetSessionsFilter { SubjectId = "12345" });
```

## Key Points

- `QuerySessionsAsync` returns a `QueryResult<UserSession>` with paging support via `ResultsToken`
- Pass `ResultsToken` from a previous result to fetch the next page
- `RemoveSessionsAsync` accepts a `RemoveSessionsContext` with fine-grained control
- `SendBackchannelLogoutNotification` defaults to `true` — set explicitly for clarity
- `RevokeConsents = false` preserves consent grants when terminating sessions