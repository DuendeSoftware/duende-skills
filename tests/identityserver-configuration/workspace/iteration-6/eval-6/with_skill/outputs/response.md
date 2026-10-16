```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<IdentityResource> IdentityResources => new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResource(
            name: "organization",
            displayName: "Your organization info",
            userClaims: new[] { "org_id", "org_name", "org_role" })
        {
            Required = true // not shown as optional on the consent screen
        }
    };
}

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources);
```
`openid` is mandatory and returns `sub`. Clients must list `organization` in `AllowedScopes` and request it; your profile service must supply the three claims.
