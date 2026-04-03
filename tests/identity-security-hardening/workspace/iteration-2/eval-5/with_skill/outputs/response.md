# Replace Developer Signing Credential with Automatic Key Management

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.IdentityModel.Tokens;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// Data Protection for load-balanced deployment
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");

// IdentityServer with automatic key management
builder.Services.AddIdentityServer(options =>
    {
        // Key rotation every 90 days
        options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);

        // Announce new keys 14 days before activation
        options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);

        // Keep retired keys for 14 days for token validation
        options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);

        // Encrypt keys at rest via ASP.NET Core Data Protection
        options.KeyManagement.DataProtectKeys = true;

        // ES256 first = default for new tokens; RS256 for legacy client compatibility
        options.KeyManagement.SigningAlgorithms = new[]
        {
            new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256),
            new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)
        };
    })
    // Removed: .AddDeveloperSigningCredential()
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

## Changes Made

### 1. Removed `AddDeveloperSigningCredential()`
The developer signing credential creates an ephemeral RSA key stored in a temporary file. It is NOT suitable for production — keys are lost on redeployment and shared across environments if the file is committed to source control.

### 2. Configured Automatic Key Management
- **RotationInterval = 90 days** — keys automatically rotate every 90 days
- **PropagationTime = 14 days** — new keys are published in the JWKS 14 days before activation, giving clients time to cache them
- **RetentionDuration = 14 days** — retired keys stay in discovery for 14 days for token validation
- **DataProtectKeys = true** — signing keys are encrypted at rest using ASP.NET Core Data Protection

### 3. Configured Signing Algorithms
- **ES256 (EcdsaSha256)** as the primary algorithm — smaller tokens, modern
- **RS256 (RsaSha256)** as fallback — for legacy client compatibility
- The first algorithm in the array is the default used for signing

### 4. Configured Data Protection
- **PersistKeysToFileSystem** with `/var/identity/dp-keys` — shared across all load-balanced instances
- **SetApplicationName** — ensures consistent key isolation across all instances
