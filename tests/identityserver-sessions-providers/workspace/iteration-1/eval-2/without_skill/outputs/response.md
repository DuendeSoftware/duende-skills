# Managing Sessions with ISessionManagementService

Here's how to build an admin endpoint for session management in IdentityServer.

## Session Admin Controller

```csharp
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

    // Query first page
    [HttpGet]
    public async Task<IActionResult> GetSessions(int pageSize = 10)
    {
        var result = await _sessionManagement.QuerySessionsAsync(new SessionQuery
        {
            CountRequested = pageSize
        });

        return Ok(result);
    }

    // Next page
    [HttpGet("page")]
    public async Task<IActionResult> GetNextPage([FromQuery] string token, int pageSize = 10)
    {
        var result = await _sessionManagement.QuerySessionsAsync(new SessionQuery
        {
            ResultsToken = token,
            CountRequested = pageSize
        });

        return Ok(result);
    }

    // Revoke sessions
    [HttpDelete("{subjectId}")]
    public async Task<IActionResult> RevokeSessions(string subjectId)
    {
        await _sessionManagement.RemoveSessionsAsync(new RemoveSessionsContext
        {
            SubjectId = subjectId,
            RemoveServerSideSession = true,
            RevokeTokens = true,
            SendBackchannelLogoutNotification = true,
            RevokeConsents = true
        });

        return NoContent();
    }
}
```

## Notes

- Use paging tokens to navigate through large result sets
- The remove operation cleans up sessions, tokens, consents, and sends logout notifications
- Consider caching session queries for performance in admin dashboards