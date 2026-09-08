# Adding M2M and Interactive Clients

Here are the two clients you need. `batch-processor` is a client-credentials (machine-to-machine) client, and `admin-portal` is an interactive web app using authorization code flow with PKCE and refresh tokens.

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<Client> Clients =>
        new Client[]
        {
            // Machine-to-machine
            new Client
            {
                ClientId = "batch-processor",
                AllowedGrantTypes = GrantTypes.ClientCredentials,
                ClientSecrets = { new Secret("batch-secret".Sha256()) },
                AllowedScopes = { "orders.read", "inventory.write" }
            },

            // Interactive admin portal
            new Client
            {
                ClientId = "admin-portal",
                AllowedGrantTypes = GrantTypes.Code,
                RequirePkce = true,
                ClientSecrets = { new Secret("admin-secret".Sha256()) },

                RedirectUris = { "https://admin.example.com/signin-oidc" },
                PostLogoutRedirectUris = { "https://admin.example.com/signout-callback-oidc" },

                AllowOfflineAccess = true, // refresh tokens

                AllowedScopes =
                {
                    "openid",
                    "profile",
                    "email",
                    "orders.read"
                }
            }
        };
}
```

You'll also need the API scopes registered:

```csharp
public static IEnumerable<ApiScope> ApiScopes =>
    new ApiScope[]
    {
        new ApiScope("orders.read"),
        new ApiScope("inventory.write")
    };
```

## Key points

- The M2M client uses `GrantTypes.ClientCredentials` and only needs its two API scopes.
- The interactive client uses `GrantTypes.Code` with PKCE. `RequirePkce = true` is the secure default.
- `AllowOfflineAccess = true` enables refresh tokens for the admin portal.
- `openid` is required for OIDC; the portal requests `openid`, `profile`, `email`, and `orders.read`.
- Redirect and post-logout URIs are set exactly as given.
