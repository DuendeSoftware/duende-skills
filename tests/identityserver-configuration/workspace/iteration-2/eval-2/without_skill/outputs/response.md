Here's how to configure both clients in your `Program.cs`:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("orders.read"),
        new ApiScope("inventory.write")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "batch-processor",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "orders.read", "inventory.write" }
        },
        new Client
        {
            ClientId = "admin-portal",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://admin.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://admin.example.com/signout-callback-oidc" },
            AllowOfflineAccess = true,
            AllowedScopes = { "openid", "profile", "email", "orders.read" }
        }
    });

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.Run();
```

The batch-processor uses client credentials for M2M access. The admin-portal uses authorization code flow with PKCE (which should be enabled by default) and has refresh tokens enabled via `AllowOfflineAccess = true`.
