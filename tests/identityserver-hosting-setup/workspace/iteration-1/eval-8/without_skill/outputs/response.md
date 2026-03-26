# IdentityServer with Interactive Client

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("weatherapi", "Weather API")
    })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "webapp",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "weatherapi" }
        }
    });

var app = builder.Build();

app.UseAuthentication();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

This sets up IdentityServer with identity resources, an API scope, and an interactive client using authorization code flow.
