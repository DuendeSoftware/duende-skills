# Custom IProfileService for IdentityServer

To include custom claims like `department` and `tenant_id` in access tokens from Duende IdentityServer, you need to implement `IProfileService`.

## Implementation

```csharp
using System.Security.Claims;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public class CustomProfileService : IProfileService
{
    private readonly IUserRepository _users;

    public CustomProfileService(IUserRepository users)
    {
        _users = users;
    }

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var subjectId = context.Subject.FindFirst("sub")?.Value;
        if (subjectId == null) return;

        var user = await _users.FindBySubjectIdAsync(subjectId);
        if (user == null) return;

        var claims = new List<Claim>
        {
            new Claim("department", user.Department),
            new Claim("tenant_id", user.TenantId),
        };

        context.IssuedClaims.AddRange(claims);
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var subjectId = context.Subject.FindFirst("sub")?.Value;
        if (subjectId == null)
        {
            context.IsActive = false;
            return;
        }

        var user = await _users.FindBySubjectIdAsync(subjectId);
        context.IsActive = user != null && user.IsEnabled;
    }
}
```

## Registration

Register it in your `Program.cs`:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddProfileService<CustomProfileService>();
```

This will ensure both `department` and `tenant_id` are included in access tokens issued by your IdentityServer.

## Notes

- The `GetProfileDataAsync` method is called when tokens are being issued
- `IsActiveAsync` checks whether the user account is still valid
- You can inject any services you need through the constructor
