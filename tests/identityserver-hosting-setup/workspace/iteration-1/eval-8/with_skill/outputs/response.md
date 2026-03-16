# Complete IdentityServer Setup with Identity Resources, API Scope, and Interactive Client

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
            ClientName = "Interactive Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "weatherapi" }
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

## Configuration Breakdown

### Identity Resources
- `IdentityResources.OpenId()` — required for OpenID Connect; provides the `sub` claim
- `IdentityResources.Profile()` — provides standard profile claims (name, family_name, etc.)

### API Scope
- `weatherapi` — the scope that protects the Weather API

### Interactive Client
- **Grant Type**: `GrantTypes.Code` — authorization code flow with PKCE (the recommended flow for interactive web applications)
- **PKCE**: `RequirePkce = true` (this is actually the default in Duende IdentityServer)
- **Redirect URIs**: Where the client expects to receive the authorization code callback
- **Post-Logout Redirect URIs**: Where the client expects to land after signing out
- **Allowed Scopes**: `openid` + `profile` for identity claims, `weatherapi` for API access

### Middleware Pipeline
The pipeline follows the correct ordering:
1. `UseStaticFiles()` — static files first
2. `UseRouting()` — before IdentityServer
3. `UseIdentityServer()` — includes `UseAuthentication()` internally
4. `UseAuthorization()` — after IdentityServer, required for UI template
