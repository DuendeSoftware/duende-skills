# Migrating Config.cs from IdentityServer4 to Duende IdentityServer

The main change required is updating the namespace. Here's the migrated file:

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

## Key Changes

1. **Namespace**: Changed `using IdentityServer4.Models` to `using Duende.IdentityServer.Models`

The model classes like `Client`, `ApiScope`, `ApiResource`, `IdentityResource`, `Secret`, and `GrantTypes` are essentially the same in Duende IdentityServer. Your existing client and resource definitions should work without modification beyond the namespace change.

You may also want to consider using newer C# features if you're upgrading to a newer target framework (e.g., collection expressions, file-scoped namespaces), but these are optional cosmetic improvements.
