# Migrated `Config.cs` for Duende IdentityServer v7

The only change your `Config.cs` needs is the namespace: `IdentityServer4.Models` → `Duende.IdentityServer.Models`. Every model type (`IdentityResource`, `ApiScope`, `ApiResource`, `Client`, `Secret`, `GrantTypes`, and the `IdentityResources.*` helpers) exists in Duende with the **same names and API surface**, so the definitions themselves are unchanged.

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

## What changed / what stayed the same

- **Changed:** `using IdentityServer4.Models;` → `using Duende.IdentityServer.Models;` — this is the single edit required.
- **Unchanged — Clients:** both `m2m.client` (client credentials) and `interactive.client` (authorization code + PKCE) keep their `ClientId`, `AllowedGrantTypes`, `ClientSecrets`, `RedirectUris`, `PostLogoutRedirectUris`, and `AllowedScopes` exactly as-is.
- **Unchanged — Resources/Scopes:** `IdentityResources.OpenId()`/`Profile()`, the `ApiScope("api1", …)`, and the `ApiResource("api1", …) { Scopes = { "api1" } }` definitions are identical.
- **Unchanged — Types:** `Secret` (with the `.Sha256()` extension) and `GrantTypes` (`ClientCredentials`, `Code`) have the same API in Duende.

Your file is already written in v4 style (independent `ApiScope`, string scope references), so no v3→v4 restructuring is needed here — just the namespace. Note this is `IdentityModel`-free; if this file (or others) used `using IdentityModel;`, that would become `using Duende.IdentityModel;`, but `Config.cs` doesn't.
