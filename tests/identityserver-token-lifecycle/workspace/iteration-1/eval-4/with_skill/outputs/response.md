# Custom Profile Service with Scope-Based Claims and Token Exchange Support

## ProfileService Implementation

```csharp
using Duende.IdentityModel;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using System.Security.Claims;

public class CustomProfileService : DefaultProfileService
{
    public CustomProfileService(ILogger<DefaultProfileService> logger) : base(logger)
    {
    }

    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // Load claims from your database based on the user's subject ID
        var subjectId = context.Subject.FindFirst("sub")?.Value;
        var allClaims = await LoadClaimsFromDatabaseAsync(subjectId);

        // Only emit claims that are requested by the client's scopes
        // This respects the scope-to-claims mapping and consent decisions
        context.AddRequestedClaims(allClaims);

        // For token exchange flows, pass through the act claim
        if (context.Subject.GetAuthenticationMethod() == OidcConstants.GrantTypes.TokenExchange)
        {
            var actClaim = context.Subject.FindFirst(JwtClaimTypes.Actor);
            if (actClaim != null)
            {
                context.IssuedClaims.Add(actClaim);
            }
        }
    }

    private Task<IEnumerable<Claim>> LoadClaimsFromDatabaseAsync(string? subjectId)
    {
        // Replace with actual database call
        var claims = new List<Claim>
        {
            new Claim(JwtClaimTypes.Name, "Alice Smith"),
            new Claim(JwtClaimTypes.Email, "alice@example.com"),
            new Claim(JwtClaimTypes.Role, "admin"),
            new Claim("department", "engineering")
        };
        return Task.FromResult<IEnumerable<Claim>>(claims);
    }
}
```

## Registration in Program.cs

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer()
    // ... existing configuration ...
    ;

// Register the custom profile service
idsvrBuilder.AddProfileService<CustomProfileService>();
```

## Key Design Decisions

### `AddRequestedClaims` vs Direct Assignment

Using `context.AddRequestedClaims(claims)` is the recommended approach because it:

- Only emits claims that the client's requested scopes map to
- Respects consent decisions (if the user didn't consent to a scope, its claims are excluded)
- Works with the identity resource and API scope claim type mappings

If you used `context.IssuedClaims.AddRange(claims)` instead, **all** claims would be emitted regardless of which scopes were requested, which could leak sensitive information.

### Token Exchange Act Claim

When a token exchange flow occurs, the subject's authentication method is set to `urn:ietf:params:oauth:grant-type:token-exchange`. The `act` (actor) claim from the exchange validator needs to be explicitly forwarded to the issued token. Without this check, the call chain information would be lost.

### Extending DefaultProfileService

By extending `DefaultProfileService` rather than implementing `IProfileService` directly, you get the default behavior for `IsActiveAsync` (which always returns true) and can focus on just the claims logic. Override `IsActiveAsync` if you need to check user status.
