```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("orders.read", "Read orders"),
        new ApiScope("inventory.write", "Modify inventory")
    })
    .AddInMemoryClients(new[]
    {
        // Machine-to-machine
        new Client
        {
            ClientId = "batch-processor",
            ClientName = "Batch Processor",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret(builder.Configuration["Clients:BatchProcessor:SecretHash"]!) },
            AllowedScopes = { "orders.read", "inventory.write" }
        },
        // Interactive web app
        new Client
        {
            ClientId = "admin-portal",
            ClientName = "Admin Portal",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret(builder.Configuration["Clients:AdminPortal:SecretHash"]!) },
            RedirectUris = { "https://admin.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://admin.example.com/signout-callback-oidc" },
            AllowOfflineAccess = true,
            AllowedScopes =
            {
                IdentityServerConstants.StandardScopes.OpenId,
                IdentityServerConstants.StandardScopes.Profile,
                IdentityServerConstants.StandardScopes.Email,
                "orders.read"
            }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.UseAuthorization();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```
- Secrets are pre-hashed values loaded from configuration/vault, not hardcoded.
- `admin-portal` has `AllowOfflineAccess = true` for refresh tokens (client must request `offline_access`) and `openid` is included.
- Redirect URIs match exactly.
- `batch-processor` gets only its two scopes (least privilege).
