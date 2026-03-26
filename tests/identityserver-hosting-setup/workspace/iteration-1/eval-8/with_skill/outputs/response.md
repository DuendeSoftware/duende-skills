# Complete IdentityServer Setup with Interactive Client

## Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    // Identity resources for user claims
    .AddInMemoryIdentityResources(new IdentityResource[]
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    // API scope for the weather API
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("weatherapi", "Weather API")
    })
    // Interactive web client
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "webapp",
            ClientName = "Web Application",

            // Authorization Code with PKCE
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            // Client secret for confidential client
            ClientSecrets = { new Secret("secret".Sha256()) },

            // Redirect URIs
            RedirectUris = { "https://webapp.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://webapp.example.com/signout-callback-oidc" },

            // Scopes the client can request
            AllowedScopes = { "openid", "profile", "weatherapi" }
        }
    });

var app = builder.Build();

// Correct middleware pipeline ordering
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();    // After UseRouting, includes UseAuthentication
app.UseAuthorization();     // After UseIdentityServer

app.MapDefaultControllerRoute();

app.Run();
```

## Configuration Details

### Identity Resources

- **`IdentityResources.OpenId()`** — Required. Maps to the `openid` scope and includes the `sub` (subject) claim.
- **`IdentityResources.Profile()`** — Maps to the `profile` scope and includes standard profile claims (name, family_name, etc.).

### API Scope

- **`weatherapi`** — The scope that protects access to the Weather API. The client includes this in its `AllowedScopes` so it can request access tokens for the API.

### Client Configuration

- **`GrantTypes.Code`** — Authorization Code flow with PKCE. This is the recommended flow for interactive web applications.
- **`RequirePkce = true`** — Enforces PKCE (Proof Key for Code Exchange). This is the default in Duende IdentityServer, but included here for clarity.
- **`RedirectUris`** — Where the authorization server redirects after authentication. Must match exactly what the client application configures.
- **`PostLogoutRedirectUris`** — Where to redirect after logout.

### Pipeline Ordering

The middleware pipeline follows the required order:
1. `UseStaticFiles()` — serves static files for the UI
2. `UseRouting()` — **before** IdentityServer
3. `UseIdentityServer()` — processes OIDC/OAuth requests (includes authentication internally)
4. `UseAuthorization()` — **after** IdentityServer, required for UI pages
