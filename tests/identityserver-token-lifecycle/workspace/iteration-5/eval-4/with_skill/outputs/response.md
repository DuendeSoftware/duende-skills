# Custom Profile Service with Scope-Aware Claims and `act` Pass-Through

The profile service decides which claims land in identity tokens, access tokens, and userinfo responses. The recommended pattern is to **extend `DefaultProfileService`** and use `context.AddRequestedClaims(...)` so that only the claims permitted by the client's requested scopes/resources are emitted — this respects consent and avoids bloating tokens. For token-exchange flows we additionally forward the `act` (actor) claim so the delegation chain is preserved.

## Implementation

```csharp
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer.Extensions;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class CustomProfileService : DefaultProfileService
{
    private readonly ILogger<CustomProfileService> _logger;

    public CustomProfileService(ILogger<CustomProfileService> logger)
        : base(logger)
    {
        _logger = logger;
    }

    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // Load claims for this user from the database
        var claims = await GetClaimsFromDatabaseAsync(context.Subject);

        // Emit ONLY the claims the client's scopes actually requested
        context.AddRequestedClaims(claims);

        // Token-exchange (delegation): forward the act claim so the call chain is preserved
        if (context.Subject.GetAuthenticationMethod() == OidcConstants.GrantTypes.TokenExchange)
        {
            var act = context.Subject.FindFirst(JwtClaimTypes.Actor);
            if (act != null)
            {
                context.IssuedClaims.Add(act);
            }
        }
    }

    private Task<IEnumerable<Claim>> GetClaimsFromDatabaseAsync(ClaimsPrincipal subject)
    {
        // Hypothetical data-access; replace with your repository/query
        var sub = subject.GetSubjectId();
        var claims = new List<Claim>
        {
            new Claim(JwtClaimTypes.Name, "Alice Smith"),
            new Claim(JwtClaimTypes.Email, "alice@example.com"),
            new Claim("department", "billing")
        };
        return Task.FromResult<IEnumerable<Claim>>(claims);
    }
}
```

## Register it

```csharp
builder.Services.AddIdentityServer()
    // ... existing configuration ...
    .AddProfileService<CustomProfileService>();
```

## Why `AddRequestedClaims` rather than `IssuedClaims.AddRange`

| Approach | Behavior |
| --- | --- |
| `context.AddRequestedClaims(claims)` | Only emits claims whose types are covered by the requested scopes/resources — respects consent, keeps tokens lean |
| `context.IssuedClaims.AddRange(claims)` | Emits everything unconditionally, regardless of what the client asked for |

The `act` claim is added directly to `IssuedClaims` here because it is a protocol-level delegation marker, not a scope-driven user claim — and it only applies when the authentication method is token exchange.

> Note: for userinfo requests `context.Subject` holds claims from the access token, not the login session; check `context.Caller` if you need to branch on the source.
