# Custom Profile Service

You can control which claims IdentityServer emits by implementing a custom profile service. The cleanest way is to extend `DefaultProfileService` and override `GetProfileDataAsync`. To only emit claims that the client's scopes actually asked for, use `context.AddRequestedClaims(...)` instead of dumping everything into `IssuedClaims`.

## Implementation

```csharp
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class CustomProfileService : DefaultProfileService
{
    public CustomProfileService(ILogger<DefaultProfileService> logger)
        : base(logger)
    {
    }

    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // Load the user's claims from the database
        var claims = await LoadUserClaimsAsync(context.Subject);

        // Only emit claims that were requested by the client's scopes
        context.AddRequestedClaims(claims);

        // For token exchange, pass through the act claim if it's there
        var act = context.Subject.FindFirst(JwtClaimTypes.Actor);
        if (act != null)
        {
            context.IssuedClaims.Add(act);
        }
    }

    private Task<IEnumerable<Claim>> LoadUserClaimsAsync(ClaimsPrincipal subject)
    {
        // Pretend this queries a database
        var claims = new List<Claim>
        {
            new Claim("name", "Alice"),
            new Claim("email", "alice@example.com"),
            new Claim("role", "admin")
        };
        return Task.FromResult<IEnumerable<Claim>>(claims);
    }
}
```

## Registration

Register it on the IdentityServer builder:

```csharp
builder.Services.AddIdentityServer()
    // ... existing config ...
    .AddProfileService<CustomProfileService>();
```

## Summary

- Extending `DefaultProfileService` lets you reuse the base behavior.
- `context.AddRequestedClaims(claims)` ensures only scope-requested claims are emitted, which keeps tokens smaller and respects consent.
- The `act` claim is forwarded so downstream services in a token-exchange/delegation scenario can see the actor.
