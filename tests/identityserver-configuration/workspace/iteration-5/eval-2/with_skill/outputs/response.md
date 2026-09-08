# Adding M2M and Interactive Clients

Below are the two client definitions plus the supporting API scopes. The `batch-processor` is a machine-to-machine client using client credentials; the `admin-portal` is an interactive web app using authorization code flow with PKCE and refresh tokens.

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<ApiScope> ApiScopes =>
        new ApiScope[]
        {
            new ApiScope("orders.read", "Read orders"),
            new ApiScope("inventory.write", "Write inventory")
        };

    public static IEnumerable<Client> Clients =>
        new Client[]
        {
            // Machine-to-machine (client credentials)
            new Client
            {
                ClientId = "batch-processor",
                ClientName = "Batch Processor Service",

                AllowedGrantTypes = GrantTypes.ClientCredentials,
                ClientSecrets = { new Secret("secret".Sha256()) }, // load from config/vault in production

                AllowedScopes = { "orders.read", "inventory.write" }
            },

            // Interactive web application (authorization code + PKCE)
            new Client
            {
                ClientId = "admin-portal",
                ClientName = "Admin Portal",

                AllowedGrantTypes = GrantTypes.Code,
                RequirePkce = true, // default in Duende IdentityServer

                ClientSecrets = { new Secret("secret".Sha256()) },

                RedirectUris = { "https://admin.example.com/signin-oidc" },
                PostLogoutRedirectUris = { "https://admin.example.com/signout-callback-oidc" },

                // Enable refresh tokens
                AllowOfflineAccess = true,

                AllowedScopes =
                {
                    IdentityServerConstants.StandardScopes.OpenId,
                    IdentityServerConstants.StandardScopes.Profile,
                    IdentityServerConstants.StandardScopes.Email,
                    "orders.read"
                }
            }
        };
}
```

Register the clients (and scopes) on the builder:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

## Notes

- **`batch-processor`** uses `GrantTypes.ClientCredentials` — no user, no PKCE, no refresh tokens (client credentials clients simply re-authenticate). It can access `orders.read` and `inventory.write`.
- **`admin-portal`** uses `GrantTypes.Code` with `RequirePkce = true`. PKCE is the default in Duende IdentityServer but is stated explicitly here.
- **`AllowOfflineAccess = true`** is what enables refresh token issuance — the client must also request the `offline_access` scope at runtime.
- **`openid`** must be present for any OpenID Connect flow (it maps to the `sub` claim); the admin portal includes `openid`, `profile`, `email`, plus `orders.read`.
- **Redirect URIs must match exactly** — no trailing slash — so `https://admin.example.com/signin-oidc` and `https://admin.example.com/signout-callback-oidc` are used verbatim.
