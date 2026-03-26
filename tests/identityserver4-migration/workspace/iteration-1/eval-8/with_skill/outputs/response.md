# Migrated Config.cs — Duende IdentityServer v7

Here is your `Config.cs` updated for Duende IdentityServer:

```csharp
using Duende.IdentityServer.Models;
using System.Collections.Generic;

namespace IdentityServerMigrationSample
{
    public static class Config
    {
        public static IEnumerable<IdentityResource> IdentityResources =>
            new List<IdentityResource>
            {
                new IdentityResources.OpenId(),
                new IdentityResources.Profile()
            };

        public static IEnumerable<ApiScope> ApiScopes =>
            new List<ApiScope>
            {
                new ApiScope("api1", "My API")
            };

        public static IEnumerable<ApiResource> ApiResources =>
            new List<ApiResource>
            {
                new ApiResource("api1", "My API")
                {
                    Scopes = { "api1" }
                }
            };

        public static IEnumerable<Client> Clients =>
            new List<Client>
            {
                new Client
                {
                    ClientId = "m2m.client",
                    AllowedGrantTypes = GrantTypes.ClientCredentials,
                    ClientSecrets = { new Secret("secret".Sha256()) },
                    AllowedScopes = { "api1" }
                },
                new Client
                {
                    ClientId = "interactive.client",
                    AllowedGrantTypes = GrantTypes.Code,
                    RequirePkce = true,
                    ClientSecrets = { new Secret("secret".Sha256()) },
                    RedirectUris = { "https://localhost:5002/signin-oidc" },
                    PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
                    AllowedScopes = { "openid", "profile", "api1" }
                }
            };
    }
}
```

## Changes Made

### Namespace Update
The only required change is the `using` directive:

```csharp
// Old
using IdentityServer4.Models;

// New
using Duende.IdentityServer.Models;
```

### Everything Else Stays the Same

All model types used in this file exist in Duende IdentityServer with the **same API surface**:

| Type | Status |
|------|--------|
| `IdentityResource` | Same API — `IdentityResources.OpenId()`, `IdentityResources.Profile()` work identically |
| `ApiScope` | Same constructor and properties |
| `ApiResource` | Same — `Scopes` property accepts string scope names (v4 semantics, which you're already using) |
| `Client` | Same — `ClientId`, `AllowedGrantTypes`, `ClientSecrets`, `AllowedScopes`, `RedirectUris`, `PostLogoutRedirectUris` all unchanged |
| `Secret` | Same — `.Sha256()` extension method works identically |
| `GrantTypes` | Same — `GrantTypes.ClientCredentials`, `GrantTypes.Code` are identical |

Your Config.cs was already using v4 semantics (string-based `Scopes` on `ApiResource`, `ApiScope` as a separate collection), so no structural changes are needed — just the namespace swap.
