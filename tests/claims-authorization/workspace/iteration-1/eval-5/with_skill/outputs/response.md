# Differentiating Claims by Token Type Using context.Caller

You can use `context.Caller` in your `IProfileService.GetProfileDataAsync` to check which token type is being built, and emit different claim sets accordingly.

## Implementation

```csharp
using System.Security.Claims;
using Duende.IdentityModel;
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;

public sealed class CallerAwareProfileService : DefaultProfileService
{
    private readonly IUserRepository _users;
    private readonly ILogger<CallerAwareProfileService> _logger;

    public CallerAwareProfileService(
        IUserRepository users,
        ILogger<CallerAwareProfileService> logger)
        : base(logger)
    {
        _users = users;
        _logger = logger;
    }

    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var subjectId = context.Subject.GetSubjectId();
        var user = await _users.FindBySubjectIdAsync(subjectId);
        if (user is null) return;

        if (context.Caller == IdentityServerConstants.ProfileDataCallers.ClaimsProviderIdentityToken)
        {
            // Identity tokens go to the browser — keep them small
            context.IssuedClaims.Add(new Claim(JwtClaimTypes.Name, user.DisplayName));
            return;
        }

        // Access tokens and userinfo can include richer application claims
        var claims = new List<Claim>
        {
            new(JwtClaimTypes.Name, user.DisplayName),
            new(JwtClaimTypes.Email, user.Email),
            new("department", user.Department),
            new("tenant_id", user.TenantId),
            new("subscription_tier", user.SubscriptionTier),
        };

        // Use AddRequestedClaims so scope-based filtering still applies
        context.AddRequestedClaims(claims);
    }

    public override async Task IsActiveAsync(IsActiveContext context)
    {
        var subjectId = context.Subject.GetSubjectId();
        var user = await _users.FindBySubjectIdAsync(subjectId);
        context.IsActive = user is { IsEnabled: true };
    }
}
```

## Registration

```csharp
builder.Services.AddIdentityServer()
    .AddProfileService<CallerAwareProfileService>();
```

## context.Caller Values

| Caller Constant | When It's Called |
|---|---|
| `IdentityServerConstants.ProfileDataCallers.ClaimsProviderIdentityToken` | Building an identity token |
| `IdentityServerConstants.ProfileDataCallers.ClaimsProviderAccessToken` | Building an access token |
| `IdentityServerConstants.ProfileDataCallers.UserInfoEndpoint` | Responding to userinfo request |

This pattern keeps identity tokens lean (just the user's name for the client) while allowing access tokens to carry the richer claim set that APIs need for authorization.
