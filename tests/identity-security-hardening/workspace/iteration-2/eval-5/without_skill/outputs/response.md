# Replace Developer Signing Credential with Key Management

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.DataProtection;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// Data Protection for load-balanced deployment
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");

// IdentityServer with key management
builder.Services.AddIdentityServer(options =>
    {
        // Key rotation settings
        options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
        options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);
        options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);

        // Use RS256 as primary, ES256 as secondary
        options.KeyManagement.SigningAlgorithms = new[]
        {
            new SigningAlgorithmOptions("RS256"),
            new SigningAlgorithmOptions("ES256")
        };
    })
    // Removed AddDeveloperSigningCredential()
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
            ClientSecrets = { new Secret("SuperSecret123".Sha256()) },
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
        new Client
        {
            ClientId = "spa.legacy",
            ClientName = "Legacy SPA",
            AllowedGrantTypes = GrantTypes.Implicit,
            AllowAccessTokensViaBrowser = true,
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
            ClientSecrets = { new Secret("WorkerSecret!".Sha256()) },
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

1. **Removed `AddDeveloperSigningCredential()`** — This is only for development and generates a temporary RSA key that gets lost on restart.

2. **Configured automatic key management** — 90-day rotation with 14-day propagation and retention. RS256 as primary algorithm with ES256 as secondary.

3. **Data Protection** — Configured with `PersistKeysToFileSystem` to `/var/identity/dp-keys` for shared key storage in the load-balanced deployment, with a consistent application name.
