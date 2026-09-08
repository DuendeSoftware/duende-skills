# Admin Session Management Endpoint with `ISessionManagementService`

`ISessionManagementService` is the public API for querying and terminating server-side sessions. Inject it into a controller (or minimal-API endpoint) and use `QuerySessionsAsync` for paged, filtered queries and `RemoveSessionsAsync` for revocation.

> **Requires server-side sessions enabled** (`.AddServerSideSessions()`), which is part of the Business/Enterprise editions.

## Endpoint

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("admin/sessions")]
public class SessionAdminController : ControllerBase
{
    private readonly ISessionManagementService _sessions;

    public SessionAdminController(ISessionManagementService sessions)
        => _sessions = sessions;

    // (1) First page of 10 sessions
    [HttpGet]
    public async Task<IActionResult> GetFirstPage([FromQuery] string? subjectId)
    {
        var page = await _sessions.QuerySessionsAsync(new SessionQuery
        {
            CountRequested = 10,
            SubjectId = subjectId,   // optional filter
        });

        return Ok(new
        {
            results = page.Results,
            resultsToken = page.ResultsToken,   // pass this back for the next page
            hasNextResults = page.HasNextResults,
            hasPrevResults = page.HasPrevResults,
        });
    }

    // (2) Next page — pass the ResultsToken from the previous response
    [HttpGet("next")]
    public async Task<IActionResult> GetNextPage([FromQuery] string resultsToken)
    {
        var page = await _sessions.QuerySessionsAsync(new SessionQuery
        {
            CountRequested = 10,
            ResultsToken = resultsToken,   // forward paging
            // RequestPriorResults = true, // set this instead to page backwards
        });

        return Ok(new { results = page.Results, resultsToken = page.ResultsToken });
    }

    // (3) Revoke ALL sessions for a user: kill the session, revoke tokens,
    //     send back-channel logout, but KEEP their consent grants.
    [HttpPost("{subjectId}/revoke")]
    public async Task<IActionResult> RevokeAll(string subjectId)
    {
        await _sessions.RemoveSessionsAsync(new RemoveSessionsContext
        {
            SubjectId = subjectId,
            RemoveServerSideSession = true,           // delete the session record
            RevokeTokens = true,                      // revoke refresh/reference tokens
            SendBackchannelLogoutNotification = true, // notify clients (default true)
            RevokeConsents = false,                   // preserve consent grants
        });

        return NoContent();
    }
}
```

## Paging model

`QuerySessionsAsync` returns a `QueryResult<UserSession>` exposing:

- `Results` — the page of sessions.
- `ResultsToken` — an opaque cursor; pass it back in the next `SessionQuery` to move forward.
- `RequestPriorResults = true` (combined with the `ResultsToken`) — pages **backward**.
- `HasNextResults` / `HasPrevResults` — whether more pages exist.

## Revocation flags (`RemoveSessionsContext`)

| Flag | Default | This request |
| --- | --- | --- |
| `RemoveServerSideSession` | true | `true` — delete the session |
| `RevokeTokens` | true | `true` — revoke refresh & reference tokens |
| `SendBackchannelLogoutNotification` | true | `true` — send back-channel logout |
| `RevokeConsents` | true | **`false`** — keep the user's consent grants |

You can also scope removal with `SessionId` and `ClientIds` on the same context.

## Performance recommendation

For a **simple listing** of a user's sessions, prefer **`GetSessionsAsync`** over `QuerySessionsAsync`. `QuerySessionsAsync` performs a full-text style search and is comparatively slower — reserve it for when you actually need the paging/filtering (subject id, display name, etc.). For example:

```csharp
// Simpler and faster when you just want a user's sessions:
var userSessions = await _sessions.GetSessionsAsync(new SessionsFilter { SubjectId = subjectId });
```

Use `QuerySessionsAsync` (as in the endpoint above) only when you need paged/advanced filtering.
