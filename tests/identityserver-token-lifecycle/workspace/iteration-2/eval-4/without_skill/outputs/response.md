# Custom Profile Service for Claims Filtering

Here's how to create a profile service that loads claims from a database and only emits what's requested by scopes.

## Profile Service Implementation

```csharp
using System.Security.Claims;

public class CustomProfileService : IProfileService
{
    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        // Load claims from your database
        var subjectId = context.Subject.FindFirst("sub")?.Value;
        var allClaims = await LoadClaimsFromDatabase(subjectId);

        // Filter to only requested claims based on scopes
        var requestedClaimTypes = context.RequestedClaimTypes;
        var filteredClaims = allClaims.Where(c => requestedClaimTypes.Contains(c.Type));
        context.IssuedClaims.AddRange(filteredClaims);

        // For token exchange, pass through the act claim
        if (context.Subject.HasClaim(c => c.Type == "act"))
        {
            var actClaim = context.Subject.FindFirst("act");
            if (actClaim != null)
            {
                context.IssuedClaims.Add(actClaim);
            }
        }
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }

    private Task<List<Claim>> LoadClaimsFromDatabase(string subjectId)
    {
        // Replace with actual DB lookup
        return Task.FromResult(new List<Claim>
        {
            new Claim("name", "Alice"),
            new Claim("email", "alice@example.com"),
            new Claim("role", "admin")
        });
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    // ... existing config
    .AddProfileService<CustomProfileService>();
```

## Key Points

- The `IProfileService` interface has two methods: `GetProfileDataAsync` and `IsActiveAsync`
- `context.RequestedClaimTypes` tells you which claims the client's scopes have requested
- Filter claims using `RequestedClaimTypes` to avoid bloating tokens with unnecessary claims
- For token exchange scenarios, check for and pass through the `act` claim
- Register with `AddProfileService<T>()`
