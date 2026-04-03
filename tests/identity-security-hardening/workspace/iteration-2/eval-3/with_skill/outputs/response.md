# Migrate spa.legacy from Implicit Flow and Fix Hardcoded Secrets

Three issues to fix:
1. `spa.legacy` uses implicit flow — migrate to authorization code with PKCE
2. `background.worker` has a hardcoded secret
3. `web.app` has a hardcoded secret

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// Load client secrets from configuration
var webAppSecret = builder.Configuration["IdentityServer:Clients:WebApp:Secret"];
var workerSecret = builder.Configuration["IdentityServer:Clients:BackgroundWorker:Secret"];

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

            // Load secret from configuration, not hardcoded
            ClientSecrets = { new Secret(webAppSecret.Sha256()) },

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

        // Migrated from implicit flow to authorization code + PKCE
        new Client
        {
            ClientId = "spa.legacy",
            ClientName = "Legacy SPA",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,
            RequireClientSecret = false,  // Public SPA client

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

            // Load secret from configuration, not hardcoded
            ClientSecrets = { new Secret(workerSecret.Sha256()) },
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

## Add secrets to appsettings.json (or preferably user secrets / environment variables)

```json
{
  "IdentityServer": {
    "Clients": {
      "WebApp": {
        "Secret": "generate-a-strong-random-secret-here"
      },
      "BackgroundWorker": {
        "Secret": "generate-another-strong-random-secret-here"
      }
    }
  }
}
```

> **Important:** For production, use environment variables, Azure Key Vault, or user secrets — not `appsettings.json`.

## Changes Made

### 1. spa.legacy — Migrated from Implicit to Code+PKCE
- `AllowedGrantTypes` changed from `GrantTypes.Implicit` to `GrantTypes.Code`
- Added `RequirePkce = true`
- Added `RequireClientSecret = false` (SPAs are public clients)
- Removed `AllowAccessTokensViaBrowser = true` — no longer needed since tokens aren't returned via browser redirect

### 2. web.app — Secret loaded from configuration
- Replaced `new Secret("SuperSecret123".Sha256())` with `new Secret(webAppSecret.Sha256())` where `webAppSecret` is loaded from `builder.Configuration`

### 3. background.worker — Secret loaded from configuration
- Replaced `new Secret("WorkerSecret!".Sha256())` with `new Secret(workerSecret.Sha256())` where `workerSecret` is loaded from `builder.Configuration`
