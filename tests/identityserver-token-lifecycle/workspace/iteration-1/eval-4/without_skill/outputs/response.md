# Custom Profile Service for Scope-Based Claims

Here's how to create a profile service that loads claims from a database and emits only the claims requested by the client's scopes.

## ProfileService Implementation

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class CustomProfileService : IProfileService
{
    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // Load claims from database
        var claims = await LoadClaimsFromDatabase(context.Subject.FindFirst("sub")?.Value);

        // Add all loaded claims to issued claims
        context.IssuedClaims.AddRange(claims);

        // For token exchange, pass through the act claim
        var actClaim = context.Subject.FindFirst("act");
        if (actClaim != null)
        {
            context.IssuedClaims.Add(actClaim);
        }
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }

    private Task<List<Claim>> LoadClaimsFromDatabase(string? subjectId)
    {
        // Hypothetical database lookup
        var claims = new List<Claim>
        {
            new Claim("name", "Alice Smith"),
            new Claim("email", "alice@example.com"),
            new Claim("role", "admin")
        };
        return Task.FromResult(claims);
    }
}
```

## Registration

In `Program.cs`, register the profile service:

```csharp
var idsvrBuilder = builder.Services.AddIdentityServer()
    // ... existing configuration
    ;

idsvrBuilder.AddProfileService<CustomProfileService>();
```

## Notes

- The profile service is called whenever tokens are issued to populate claims.
- `GetProfileDataAsync` receives a context with information about the caller, requested resources, and the subject.
- `IsActiveAsync` is called to determine if the user is still active/allowed to receive tokens.
- The `act` claim is checked and forwarded when present, which supports token exchange scenarios.
