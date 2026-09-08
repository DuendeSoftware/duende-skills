# `Config.cs` migrated to Duende IdentityServer

Duende IdentityServer kept the configuration model identical to IdentityServer4 — the `Client`, `ApiScope`, `ApiResource`, `IdentityResource`, `Secret`, and `GrantTypes` types all still exist with the same members. So migrating this file is a one-line namespace change from `IdentityServer4.Models` to `Duende.IdentityServer.Models`; the rest stays exactly as written.

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

## Summary of the change

- Replaced `using IdentityServer4.Models;` with `using Duende.IdentityServer.Models;`.
- Left both client definitions untouched — `m2m.client` (client credentials) and `interactive.client` (code flow with PKCE), including their `ClientId`, `AllowedGrantTypes`, `ClientSecrets`, redirect URIs, and `AllowedScopes`.
- Kept the `IdentityResource`, `ApiScope`, and `ApiResource` definitions as-is.
- `Secret("secret".Sha256())` and the `GrantTypes` values continue to work unchanged in Duende.

This file is already compatible with the v4 scope model (scopes referenced by string), so no further restructuring is needed beyond the namespace.
