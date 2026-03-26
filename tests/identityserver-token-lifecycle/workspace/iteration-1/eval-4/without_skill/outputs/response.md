# Custom Profile Service

To create a custom profile service that loads claims from a database and filters them by scope:

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Models;
using System.Security.Claims;

public class DatabaseProfileService : IProfileService
{
    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var subjectId = context.Subject.FindFirst("sub")?.Value;

        // Load all claims from database
        var claims = await GetUserClaimsAsync(subjectId);

        // Add only requested claims based on scopes
        context.AddRequestedClaims(claims);
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }

    private Task<List<Claim>> GetUserClaimsAsync(string subjectId)
    {
        // Database lookup here
        return Task.FromResult(new List<Claim>
        {
            new Claim("name", "Alice"),
            new Claim("email", "alice@example.com")
        });
    }
}
```

Register it:

```csharp
builder.Services.AddIdentityServer()
    .AddProfileService<DatabaseProfileService>();
```

This ensures only claims matching the requested scopes are emitted in tokens.
