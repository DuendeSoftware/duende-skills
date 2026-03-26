# Differentiating Claims by Token Type Using context.Caller

The `ProfileDataRequestContext.Caller` property tells you what type of token is being issued. You can use the `IdentityServerConstants.ProfileDataCallers` constants to differentiate between identity tokens and access tokens.

## Profile Service with Caller-Based Logic

```csharp
using System.Security.Claims;
using Duende.IdentityServer;
using Duende.IdentityServer.Extensions;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using IdentityModel;

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
            // Only include the user's display name
            context.IssuedClaims.Add(new Claim(JwtClaimTypes.Name, user.DisplayName));
            return;
        }

        // Access tokens and userinfo get the full claim set
        // Use AddRequestedClaims so only scope-requested claims are emitted
        var claims = new List<Claim>
        {
            new(JwtClaimTypes.Name, user.DisplayName),
            new(JwtClaimTypes.Email, user.Email),
            new("department", user.Department),
            new("subscription_tier", user.SubscriptionTier),
            new(JwtClaimTypes.Role, user.Role),
        };
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

## Caller Constants

| Constant | When Called |
|----------|------------|
| `ClaimsProviderIdentityToken` | Building an identity token |
| `ClaimsProviderAccessToken` | Building an access token |
| `UserInfoEndpoint` | Handling a userinfo request |

By checking `context.Caller`, you can emit a minimal claim set for identity tokens (keeping them small for browser transport) while providing richer application claims for access tokens consumed by APIs.
