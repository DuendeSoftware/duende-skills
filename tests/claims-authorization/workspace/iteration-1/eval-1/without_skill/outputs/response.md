# Custom Profile Service for IdentityServer

To add custom claims to access tokens, you can implement `IProfileService` and register it with IdentityServer.

## Profile Service Implementation

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
            new Claim("name", user.DisplayName),
            new Claim("email", user.Email),
        };

        // Add all claims to the issued claims
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

```csharp
builder.Services.AddIdentityServer()
    .AddProfileService<CustomProfileService>();
```

This will add your custom claims including `department` and `tenant_id` to the access tokens. The `IsActiveAsync` method is required by the interface and should return whether the user is still active.
