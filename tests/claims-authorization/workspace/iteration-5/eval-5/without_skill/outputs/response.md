# Emitting different claims for identity vs. access tokens

Your `IProfileService.GetProfileDataAsync` is called once per token type, and the `ProfileDataRequestContext` carries a `Caller` property that tells you which token is currently being built. You can branch on it to shape the claim set differently.

The caller value for the identity token is `IdentityServerConstants.ProfileDataCallers.ClaimsProviderIdentityToken`; for the access token it's `ClaimsProviderAccessToken` (and there's also `UserInfoEndpoint`).

## Implementation

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Extensions;
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Services;
using System.Security.Claims;

public class TokenAwareProfileService : IProfileService
{
    private readonly IUserRepository _users;

    public TokenAwareProfileService(IUserRepository users)
    {
        _users = users;
    }

    public async Task GetProfileDataAsync(ProfileDataRequestContext context)
    {
        var user = await _users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
        if (user is null)
        {
            return;
        }

        if (context.Caller == IdentityServerConstants.ProfileDataCallers.ClaimsProviderIdentityToken)
        {
            // Identity token: keep it minimal — just the name.
            context.IssuedClaims.Add(new Claim("name", user.DisplayName));
        }
        else
        {
            // Access token: include the richer application claim set.
            context.IssuedClaims.AddRange(new[]
            {
                new Claim("name", user.DisplayName),
                new Claim("email", user.Email),
                new Claim("department", user.Department),
                new Claim("cost_center", user.CostCenter),
                new Claim("role", user.PrimaryRole),
            });
        }
    }

    public async Task IsActiveAsync(IsActiveContext context)
    {
        var user = await _users.FindBySubjectIdAsync(context.Subject.GetSubjectId());
        context.IsActive = user is not null && user.IsEnabled;
    }
}
```

## Register it

```csharp
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

- Branching on `context.Caller` is the key: the identity-token branch adds only `name`, while the access-token branch adds the fuller set.
- Identity tokens are meant to be small and travel to the browser, so keeping them to essentials avoids bloated cookies and redirect URLs.
- The `else` branch also handles the userinfo endpoint call, which is usually appropriate since userinfo is expected to return richer profile data.
