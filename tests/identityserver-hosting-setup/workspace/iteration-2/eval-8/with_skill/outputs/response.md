# Complete IdentityServer Setup with Identity Resources and Interactive Client

## Updated Program.cs

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
            ClientName = "Interactive Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            ClientSecrets = { new Secret("secret".Sha256()) },

            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },

            AllowedScopes = { "openid", "profile", "weatherapi" },
            AllowOfflineAccess = true
        }
    });

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Key Points

- `AddInMemoryIdentityResources` registers `IdentityResources.OpenId()` (required for OIDC) and `IdentityResources.Profile()` (profile claims).
- `AddInMemoryApiScopes` registers the `weatherapi` scope.
- The client uses `GrantTypes.Code` (authorization code with PKCE) — this is the recommended flow for interactive web applications.
- `RequirePkce = true` ensures PKCE is required (it's the default but shown explicitly).
- `RedirectUris` and `PostLogoutRedirectUris` are set to the exact URIs.
- The middleware pipeline follows the correct order: `UseRouting` → `UseIdentityServer` → `UseAuthorization`.
