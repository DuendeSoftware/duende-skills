# Differentiating Claims by Token Type

To return different claims for identity tokens vs. access tokens in your `IProfileService`, you can inspect the request context to determine what type of token is being issued.

## Implementation

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Models;
using System.Security.Claims;

public class TokenAwareProfileService : IProfileService
{
    private readonly IUserRepository _users;

    public TokenAwareProfileService(IUserRepository users)
    {
        _users = users;
    }

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var userId = context.Subject.FindFirst("sub")?.Value;
        if (userId == null) return;

        var user = await _users.GetUserAsync(userId);
        if (user == null) return;

        // Check what type of request this is
        if (context.RequestedClaimTypes.Contains("name"))
        {
            // Basic profile claims for identity tokens
            context.IssuedClaims.Add(new Claim("name", user.DisplayName));
        }

        // For access tokens, include richer claims
        if (context.RequestedClaimTypes.Contains("department"))
        {
            context.IssuedClaims.Add(new Claim("department", user.Department));
        }

        if (context.RequestedClaimTypes.Contains("email"))
        {
            context.IssuedClaims.Add(new Claim("email", user.Email));
        }
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddProfileService<TokenAwareProfileService>();
```

## Notes

- You can check `context.RequestedClaimTypes` to see what claims are being requested
- Identity tokens typically only request the claims from identity resources (like `openid` and `profile`)
- Access tokens request claims from API scopes and resources
- By checking `RequestedClaimTypes`, you naturally get different claims in different token types based on what scopes were requested
