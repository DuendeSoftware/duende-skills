# Complete IdentityServer Setup

Here's a complete IdentityServer setup with identity resources, API scope, and an interactive client:

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
        new ApiScope("weatherapi", "Weather API")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "webapp",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.Code,
            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "weatherapi" }
        }
    });

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

This sets up:
- OpenID Connect identity resources for user authentication
- A `weatherapi` API scope
- An interactive web client using authorization code flow with the specified redirect URIs
