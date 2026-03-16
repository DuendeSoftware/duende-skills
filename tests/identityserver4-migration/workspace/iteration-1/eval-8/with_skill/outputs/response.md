# Migrated Config.cs for Duende IdentityServer v7

The migration of `Config.cs` is straightforward — it's primarily a namespace change. The model types (`Client`, `ApiScope`, `ApiResource`, `IdentityResource`, `Secret`, `GrantTypes`) have the same names and API surface in Duende IdentityServer, so your definitions remain intact.

Here is your migrated `Config.cs`:

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

1. **Namespace update**: Replaced `using IdentityServer4.Models` with `using Duende.IdentityServer.Models`
2. **Everything else is unchanged**: The `Client`, `ApiScope`, `ApiResource`, `IdentityResource`, `Secret`, and `GrantTypes` types all exist in `Duende.IdentityServer.Models` with the same API surface. Your client definitions with `ClientId`, `AllowedGrantTypes`, `ClientSecrets`, and `AllowedScopes` are fully compatible.

The `Secret` type and its `Sha256()` extension method work identically in Duende. The `GrantTypes` static class provides the same grant type collections (`ClientCredentials`, `Code`, etc.).

If you had any additional `using IdentityServer4.*` directives in other files (e.g., `IdentityServer4.Services`, `IdentityServer4.Stores`), follow the same pattern: replace `IdentityServer4` with `Duende.IdentityServer`.
