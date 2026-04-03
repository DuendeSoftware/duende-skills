# Differentiating Claims by Token Type Using context.Caller

You can use `context.Caller` in your `IProfileService` to check whether the token being issued is an identity token or an access token, and emit different claim sets accordingly.

## Implementation

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Duende.IdentityModel;
using System.Security.Claims;

public sealed class TokenTypeAwareProfileService : DefaultProfileService
{
    private readonly IUserRepository _users;
    private readonly ILogger<TokenTypeAwareProfileService> _logger;

    public TokenTypeAwareProfileService(
        IUserRepository users,
        ILogger<TokenTypeAwareProfileService> logger)
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

        // Access tokens (ClaimsProviderAccessToken) and userinfo — include richer claims
        var claims = new List<Claim>
        {
            new(JwtClaimTypes.Name, user.DisplayName),
            new(JwtClaimTypes.Email, user.Email),
            new("department", user.Department),
            new("cost_center", user.CostCenter),
            new(JwtClaimTypes.Role, user.Role),
        };

        // Use AddRequestedClaims to respect scope filtering
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
    .AddProfileService<TokenTypeAwareProfileService>();
```

## The Caller Constants

| Constant | When |
|---|---|
| `IdentityServerConstants.ProfileDataCallers.ClaimsProviderIdentityToken` | Building an identity token |
| `IdentityServerConstants.ProfileDataCallers.ClaimsProviderAccessToken` | Building an access token |
| `IdentityServerConstants.ProfileDataCallers.UserInfoEndpoint` | Responding to a userinfo request |

This approach keeps identity tokens lean (just the user's name) while access tokens include the full application claim set filtered by requested scopes.
