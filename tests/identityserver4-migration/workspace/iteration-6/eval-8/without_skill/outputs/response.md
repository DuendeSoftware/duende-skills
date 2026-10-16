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
            new List<ApiScope> { new ApiScope("api1", "My API") };

        public static IEnumerable<ApiResource> ApiResources =>
            new List<ApiResource>
            {
                new ApiResource("api1", "My API") { Scopes = { "api1" } }
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
Only the namespace changed; the definitions already use v4 structure (ApiScopes separate, ApiResource.Scopes as names, PKCE with code flow), so they work in v7. Notes: `Sha256()` still lives in `Duende.IdentityServer.Models`; replace the "secret" values with strong secrets; `AllowedGrantTypes = GrantTypes.Code` already requires PKCE. Register with `AddInMemoryClients(Config.Clients)` etc., or seed the EF stores.
