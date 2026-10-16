## Config.cs for Duende IdentityServer

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

### What changed and what didn't
- **Namespace**: `IdentityServer4.Models` → `Duende.IdentityServer.Models` (the only code change).
- The definitions already use the **v4 structure**: `ApiScope`s are top-level, `ApiResource.Scopes` holds scope-name strings (not nested `Scope` objects), and the code client uses PKCE. So no restructuring is needed; no v3→v4 changes remain.
- Project prerequisites: reference `Duende.IdentityServer` (via `Duende.IdentityServer.EntityFramework`), target `net8.0` (v7) / `net10.0` (v8), and keep `Sha256()` working via the Duende models namespace.
- Replace the demo `"secret"` values with real secrets before production.
- If these are used to seed the EF stores, remember `Duende.IdentityServer.EntityFramework.Mappers` (`ToEntity()`), and create/apply EF migrations for the new schema.
