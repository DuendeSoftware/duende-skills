# Custom Profile Service with Scope-Filtered Claims and Token Exchange Support

Here's how to create a custom profile service that loads claims from a database, emits only scope-requested claims, and passes through the `act` claim for token exchange flows.

## Custom Profile Service

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Duende.IdentityModel;

public class CustomProfileService : DefaultProfileService
{
    public CustomProfileService(ILogger<DefaultProfileService> logger) : base(logger)
    {
    }

    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // Load claims from database based on user's subject ID
        var subjectId = context.Subject.FindFirst(JwtClaimTypes.Subject)?.Value;
        var claims = await GetClaimsFromDatabaseAsync(subjectId);

        // Only emit claims that are actually requested by the client's scopes
        context.AddRequestedClaims(claims);

        // For token exchange flows, pass through the act claim for delegation
        if (context.Subject.GetAuthenticationMethod() == OidcConstants.GrantTypes.TokenExchange)
        {
            var actClaim = context.Subject.FindFirst(JwtClaimTypes.Actor);
            if (actClaim != null)
            {
                context.IssuedClaims.Add(actClaim);
            }
        }
    }

    private Task<List<Claim>> GetClaimsFromDatabaseAsync(string subjectId)
    {
        // Replace with actual database lookup
        var claims = new List<Claim>
        {
            new Claim(JwtClaimTypes.Name, "Alice Smith"),
            new Claim(JwtClaimTypes.Email, "alice@example.com"),
            new Claim(JwtClaimTypes.Role, "admin"),
            new Claim("department", "engineering")
        };
        return Task.FromResult(claims);
    }
}
```

## Registration in Program.cs

Add the profile service to the IdentityServer builder:

```csharp
builder.Services.AddIdentityServer()
    // ... existing configuration ...
    .AddProfileService<CustomProfileService>();
```

## How It Works

1. **Extends `DefaultProfileService`** — By extending the built-in `DefaultProfileService` rather than implementing `IProfileService` from scratch, you get the default behavior for free and only need to override what you need.

2. **`context.AddRequestedClaims(claims)`** — This is the key method. Instead of adding all claims directly to `context.IssuedClaims`, `AddRequestedClaims` filters the claims list based on the scopes/resources that the client actually requested. This respects the consent model and prevents claim bloat in tokens.

3. **Token exchange `act` claim forwarding** — When the authentication method is `OidcConstants.GrantTypes.TokenExchange`, the code checks for the `JwtClaimTypes.Actor` claim on the subject principal and adds it to `IssuedClaims`. This preserves the delegation chain in the resulting token.

4. **`AddProfileService<CustomProfileService>()`** — Registers the custom profile service in the DI container. IdentityServer will use this instead of the default profile service when building tokens.
