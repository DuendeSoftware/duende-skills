```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(), new IdentityResources.Profile(), new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new[] { new ApiScope("orders.read"), new ApiScope("inventory.write") })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "batch-processor",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("change-me".Sha256()) },
            AllowedScopes = { "orders.read", "inventory.write" }
        },
        new Client
        {
            ClientId = "admin-portal",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("change-me-too".Sha256()) },
            RedirectUris = { "https://admin.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://admin.example.com/signout-callback-oidc" },
            AllowOfflineAccess = true,
            AllowedScopes = { "openid", "profile", "email", "orders.read" }
        }
    });

var app = builder.Build();
app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```
Load real secrets from configuration in production.
