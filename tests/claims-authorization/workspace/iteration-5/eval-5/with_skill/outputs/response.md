# Returning different claims for identity tokens vs. access tokens

`IProfileService.GetProfileDataAsync` is invoked separately for each token type, and `ProfileDataRequestContext.Caller` tells you which one is being built. Branch on `context.Caller` and compare it against the `IdentityServerConstants.ProfileDataCallers` constants:

| `context.Caller` value | Token being built |
|---|---|
| `IdentityServerConstants.ProfileDataCallers.ClaimsProviderIdentityToken` | id_token (goes to the browser/client) |
| `IdentityServerConstants.ProfileDataCallers.ClaimsProviderAccessToken` | access token (goes to APIs) |
| `IdentityServerConstants.ProfileDataCallers.UserInfoEndpoint` | `/connect/userinfo` response |

Keep identity tokens lean (just `name`) and put the richer application claims in the access token, filtered by scope.

## Implementation

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Extensions;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using Duende.IdentityModel; // JwtClaimTypes
using System.Security.Claims;

public sealed class TokenAwareProfileService : DefaultProfileService
{
    private readonly IUserRepository _users;

    public TokenAwareProfileService(
        IUserRepository users,
        ILogger<TokenAwareProfileService> logger)
        : base(logger)
    {
        _users = users;
    }

    public override async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var user = await _users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
        if (user is null)
        {
            return;
        }

        // Identity token → keep it small: just the display name.
        if (context.Caller == IdentityServerConstants.ProfileDataCallers.ClaimsProviderIdentityToken)
        {
            context.IssuedClaims.Add(new Claim(JwtClaimTypes.Name, user.DisplayName));
            return;
        }

        // Access token (and userinfo) → richer application claims, but respect
        // the requested scopes via AddRequestedClaims.
        var claims = new List<Claim>
        {
            new(JwtClaimTypes.Name, user.DisplayName),
            new(JwtClaimTypes.Email, user.Email),
            new("department", user.Department),
            new("cost_center", user.CostCenter),
            new(JwtClaimTypes.Role, user.PrimaryRole),
        };

        context.AddRequestedClaims(claims);
    }

    public override async Task IsActiveAsync(IsActiveContext context)
    {
        var user = await _users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
        context.IsActive = user is { IsEnabled: true };
    }
}
```

## Register it

```csharp
// Program.cs
builder.Services.AddScoped<IUserRepository, UserRepository>();

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddProfileService<TokenAwareProfileService>();
```

## Notes

- Duende already builds the id_token minimally by default (`includeAllIdentityClaims = false`), so branching on `ClaimsProviderIdentityToken` is the explicit way to guarantee only `name` goes into it.
- For the access token, `AddRequestedClaims` ensures the richer claims are still filtered to what the requested scopes declared in their `UserClaims` — so declare `department`, `cost_center`, etc. on the relevant `ApiScope`/`ApiResource`.
- The same `else` branch also serves the userinfo endpoint (`UserInfoEndpoint` caller), which is usually the right place for full profile data.
