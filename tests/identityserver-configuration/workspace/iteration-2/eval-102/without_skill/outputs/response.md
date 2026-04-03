Here's how to configure a React SPA client:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("orders.read")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "react-spa",
            AllowedGrantTypes = GrantTypes.Code,
            RequireClientSecret = false,
            RedirectUris = { "https://spa.myapp.com/callback" },
            PostLogoutRedirectUris = { "https://spa.myapp.com" },
            AllowedScopes = { "openid", "profile", "orders.read" },
            AllowOfflineAccess = true
        }
    });

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.Run();
```

SPAs should use authorization code flow with PKCE. Since SPAs can't safely store secrets, `RequireClientSecret` is set to false.
