# Custom Profile Service for IdentityServer

To include custom claims like `department` and `tenant_id` in your access tokens, you'll need to implement `IProfileService`.

## Implementation

```csharp
using Duende.IdentityServer.Services;
using Duende.IdentityServer.Models;
using System.Security.Claims;

public class CustomProfileService : IProfileService
{
    private readonly IUserRepository _users;

    public CustomProfileService(IUserRepository users)
    {
        _users = users;
    }

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var userId = context.Subject.FindFirst("sub")?.Value;
        if (userId == null) return;

        var user = await _users.GetUserAsync(userId);
        if (user == null) return;

        var claims = new List<Claim>
        {
            new Claim("department", user.Department),
            new Claim("tenant_id", user.TenantId),
            new Claim("name", user.DisplayName),
            new Claim("email", user.Email),
        };

        context.IssuedClaims.AddRange(claims);
    }

    public Task IsActiveAsync(IsActiveContext context)
    {
        context.IsActive = true;
        return Task.CompletedTask;
    }
}
```

## Registration

Register the profile service in your startup:

```csharp
builder.Services.AddIdentityServer()
    .AddProfileService<CustomProfileService>();
```

## Notes

- The `GetProfileDataAsync` method is called whenever a token is being issued
- You can load claims from any data source (database, external service, etc.)
- The `IsActiveAsync` method determines if the user is still active — return `true` to allow token issuance
- Make sure the claims you want in the token are also declared in your API scope or resource configuration
