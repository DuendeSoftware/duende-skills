# Migrate spa.legacy and Fix Hardcoded Secrets

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// Load secrets from configuration
var config = builder.Configuration;

builder.Services.AddIdentityServer()
    .AddDeveloperSigningCredential()
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResources.Email()
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("catalog.read", "Read access to the catalog"),
        new ApiScope("catalog.write", "Write access to the catalog"),
        new ApiScope("orders.manage", "Manage orders"),
        new ApiScope("internal-api", "Internal API access")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web.app",
            ClientName = "Main Web Application",
            AllowedGrantTypes = GrantTypes.CodeAndClientCredentials,
            RequirePkce = false,

            // Load from configuration instead of hardcoding
            ClientSecrets = { new Secret(config["ClientSecrets:WebApp"].Sha256()) },

            RedirectUris = { "https://*.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://*.example.com/signout-callback-oidc" },

            AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

            AllowOfflineAccess = true,
            AccessTokenLifetime = 28800,
            RefreshTokenUsage = TokenUsage.ReUse,
            RefreshTokenExpiration = TokenExpiration.Sliding,
            AbsoluteRefreshTokenLifetime = 2592000,

            AllowedCorsOrigins = { }
        },

        // Migrated from implicit to authorization code + PKCE
        new Client
        {
            ClientId = "spa.legacy",
            ClientName = "Legacy SPA",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = false,

            RedirectUris = { "https://spa.example.com/callback" },
            PostLogoutRedirectUris = { "https://spa.example.com" },

            AllowedScopes = { "openid", "profile", "catalog.read" },
            AllowedCorsOrigins = { "https://spa.example.com" }
        },

        new Client
        {
            ClientId = "background.worker",
            ClientName = "Background Processing Service",
            AllowedGrantTypes = GrantTypes.ClientCredentials,

            // Load from configuration instead of hardcoding
            ClientSecrets = { new Secret(config["ClientSecrets:BackgroundWorker"].Sha256()) },
            AllowedScopes = { "internal-api", "orders.manage" },

            AccessTokenLifetime = 3600
        },

        new Client
        {
            ClientId = "internal.api.consumer",
            ClientName = "Internal API Consumer",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("InternalSecret".Sha256()) },
            AllowedScopes = { "internal-api" },
            AccessTokenType = AccessTokenType.Jwt,
            AccessTokenLifetime = 3600
        },

        new Client
        {
            ClientId = "native.app",
            ClientName = "Mobile Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = false,
            RedirectUris =
            {
                "com.example.app:/callback",
                "https://app.example.com/callback"
            },
            AllowedScopes = { "openid", "profile", "catalog.read" },
            AllowOfflineAccess = true,
            RefreshTokenUsage = TokenUsage.OneTimeOnly,
            AccessTokenLifetime = 300
        }
    });

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
```

## What Changed

### 1. spa.legacy — Migrated to Authorization Code + PKCE
- Changed `AllowedGrantTypes` from `GrantTypes.Implicit` to `GrantTypes.Code`
- Added `RequirePkce = true` 
- Added `RequireClientSecret = false` since SPAs are public clients
- Removed `AllowAccessTokensViaBrowser = true`

### 2. web.app and background.worker — Secrets from Configuration
- Both client secrets now loaded from `builder.Configuration` instead of hardcoded strings
- Add the secrets to your `appsettings.json` or preferably use user secrets / environment variables:

```json
{
  "ClientSecrets": {
    "WebApp": "your-secure-secret-here",
    "BackgroundWorker": "your-secure-secret-here"
  }
}
```
