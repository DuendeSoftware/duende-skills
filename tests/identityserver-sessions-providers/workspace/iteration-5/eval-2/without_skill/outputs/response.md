# Admin Session Endpoint using `ISessionManagementService`

Duende IdentityServer exposes `ISessionManagementService` for administrative querying and termination of server-side sessions. Inject it and use `QuerySessionsAsync` for paged queries and `RemoveSessionsAsync` to terminate.

Make sure server-side sessions are enabled (`AddServerSideSessions()`), otherwise there is nothing to query.

## Controller

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("admin/sessions")]
public class SessionAdminController : ControllerBase
{
    private readonly ISessionManagementService _sessionManagement;

    public SessionAdminController(ISessionManagementService sessionManagement)
        => _sessionManagement = sessionManagement;

    // (1) First page of 10 sessions
    [HttpGet]
    public async Task<IActionResult> FirstPage()
    {
        var result = await _sessionManagement.QuerySessionsAsync(new SessionQuery
        {
            CountRequested = 10
        });

        return Ok(new { result.Results, result.ResultsToken });
    }

    // (2) Next page using the ResultsToken from the previous query
    [HttpGet("next")]
    public async Task<IActionResult> NextPage(string resultsToken)
    {
        var result = await _sessionManagement.QuerySessionsAsync(new SessionQuery
        {
            CountRequested = 10,
            ResultsToken = resultsToken
        });

        return Ok(new { result.Results, result.ResultsToken });
    }

    // (3) Revoke all sessions for a user, with back-channel logout but keeping consents
    [HttpPost("{subjectId}/revoke-all")]
    public async Task<IActionResult> RevokeAll(string subjectId)
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

## Notes

- **Paging**: `QuerySessionsAsync` returns a result object that includes a `ResultsToken`. Pass that token back into a subsequent `SessionQuery` to fetch the next page. The result also exposes flags such as `HasNextResults`/`HasPrevResults`, and you can request the previous page by combining the token with `RequestPriorResults = true`.
- **Filtering**: You can narrow the query with `SubjectId`, `SessionId`, or a display-name filter.
- **Revocation flags** on `RemoveSessionsContext`:
  - `RemoveServerSideSession = true` deletes the stored session.
  - `RevokeTokens = true` revokes refresh and reference tokens.
  - `SendBackchannelLogoutNotification = true` sends back-channel logout to clients that registered a `BackChannelLogoutUri`.
  - `RevokeConsents = false` preserves the user's consent grants (so they aren't re-prompted).

This satisfies all three requirements: paged querying (10 per page), forward paging via the results token, and a full revocation that logs the user out everywhere while leaving consents intact.
