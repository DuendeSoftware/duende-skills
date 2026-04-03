# Security Audit — IdentityServer Configuration

## Findings and Remediations

| # | Finding | Severity | Remediation |
|---|---------|----------|-------------|
| 1 | `AddDeveloperSigningCredential()` in use | Critical | Replaced with automatic key management (ES256 + RS256) |
| 2 | `spa.legacy` uses implicit flow | Critical | Migrated to `GrantTypes.Code` with `RequirePkce = true` |
| 3 | `web.app` has wildcard redirect URIs | Critical | Replaced with exact-match URIs |
| 4 | `web.app` has `RequirePkce = false` | Critical | Changed to `RequirePkce = true` |
| 5 | `web.app` uses `CodeAndClientCredentials` | High | Changed to `GrantTypes.Code` |
| 6 | Hardcoded client secrets in source code | High | Loaded from configuration |
| 7 | `web.app` has 8-hour access token lifetime | High | Reduced to 300 seconds (5 minutes) |
| 8 | `web.app` uses `RefreshTokenUsage.ReUse` | High | Changed to `OneTimeOnly` |
| 9 | `web.app` has no CORS origins configured | Medium | Added exact origin |
| 10 | No HTTPS enforcement or HSTS | High | Added HSTS, HTTPS redirection |
| 11 | No Content Security Policy headers | Medium | Added CSP middleware |
| 12 | No rate limiting on endpoints | Medium | Added rate limiting on token and authorize endpoints |

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// Load client secrets from configuration
var webAppSecret = builder.Configuration["IdentityServer:Clients:WebApp:Secret"];
var workerSecret = builder.Configuration["IdentityServer:Clients:BackgroundWorker:Secret"];
var internalSecret = builder.Configuration["IdentityServer:Clients:InternalApi:Secret"];

// HSTS configuration
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});

builder.Services.AddHttpsRedirection(options =>
{
    options.RedirectStatusCode = StatusCodes.Status308PermanentRedirect;
    options.HttpsPort = 443;
});

// Data Protection
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");

// Rate limiting
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.AddPolicy("token-endpoint", context =>
        RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 4,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            }));

    options.AddPolicy("authorize-endpoint", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            }));
});

// IdentityServer with automatic key management
builder.Services.AddIdentityServer(options =>
    {
        options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
        options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);
        options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);
        options.KeyManagement.DataProtectKeys = true;

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
        // Hardened interactive web application
        new Client
        {
            ClientId = "web.app",
            ClientName = "Main Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            ClientSecrets = { new Secret(webAppSecret.Sha256()) },

            RedirectUris = { "https://app.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

            AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

            AllowOfflineAccess = true,
            AccessTokenLifetime = 300,
            RefreshTokenUsage = TokenUsage.OneTimeOnly,
            RefreshTokenExpiration = TokenExpiration.Absolute,
            AbsoluteRefreshTokenLifetime = 86400,
            CoordinateLifetimeWithUserSession = true,

            AllowedCorsOrigins = { "https://app.example.com" }
        },

        // Migrated from implicit to code+PKCE
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
            ClientSecrets = { new Secret(workerSecret.Sha256()) },
            AllowedScopes = { "internal-api", "orders.manage" },
            AccessTokenLifetime = 900
        },

        new Client
        {
            ClientId = "internal.api.consumer",
            ClientName = "Internal API Consumer",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret(internalSecret.Sha256()) },
            AllowedScopes = { "internal-api" },
            AccessTokenType = AccessTokenType.Jwt,
            AccessTokenLifetime = 900
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

// CSP middleware
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? string.Empty;
    var isIdentityUiPath =
        path.StartsWith("/account", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/consent", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/connect", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/diagnostics", StringComparison.OrdinalIgnoreCase);

    if (isIdentityUiPath)
    {
        context.Response.Headers.Append("Content-Security-Policy",
            "default-src 'self'; " +
            "script-src 'self'; " +
            "style-src 'self'; " +
            "img-src 'self' data:; " +
            "font-src 'self'; " +
            "frame-ancestors 'none'; " +
            "form-action 'self'; " +
            "base-uri 'self'; " +
            "object-src 'none'");

        context.Response.Headers.Append("X-Frame-Options", "DENY");
        context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    }

    await next();
});

app.UseHttpsRedirection();
app.UseHsts();
app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.MapGroup("/connect/token").RequireRateLimiting("token-endpoint");
app.MapGroup("/connect/authorize").RequireRateLimiting("authorize-endpoint");

app.Run();
```

## Detailed Audit Summary

### Critical Findings

1. **Developer signing credential (Finding #1)**: `AddDeveloperSigningCredential()` creates an ephemeral RSA key for development. In production, this key is lost on redeployment, may be shared across environments if committed to source control, and provides no rotation. **Fixed**: Replaced with automatic key management using ES256 (primary) and RS256 (fallback) with 90-day rotation.

2. **Implicit flow on spa.legacy (Finding #2)**: Implicit flow is deprecated by RFC 9700 because it exposes tokens in URL fragments, browser history, and referrer headers. **Fixed**: Migrated to `GrantTypes.Code` with `RequirePkce = true` and `RequireClientSecret = false` (public client).

3. **Wildcard redirect URIs on web.app (Finding #3)**: `https://*.example.com/signin-oidc` is an open redirector — an attacker can register a subdomain and intercept authorization codes. **Fixed**: Replaced with exact-match URI `https://app.example.com/signin-oidc`.

4. **PKCE disabled on web.app (Finding #4)**: `RequirePkce = false` makes authorization code interception trivially exploitable. **Fixed**: Set to `true`.

### High Severity Findings

5. **Overly broad grant types on web.app (Finding #5)**: `CodeAndClientCredentials` allows both user and M2M flows on a single client, violating the principle of least grant. **Fixed**: Changed to `GrantTypes.Code`.

6. **Hardcoded secrets (Finding #6)**: `"SuperSecret123"`, `"WorkerSecret!"`, and `"InternalSecret"` are committed in source code. **Fixed**: All secrets loaded from `builder.Configuration`.

7. **8-hour access token lifetime (Finding #7)**: An attacker with a stolen token has an 8-hour replay window. **Fixed**: Reduced to 300 seconds (5 minutes).

8. **Refresh token reuse (Finding #8)**: `TokenUsage.ReUse` means a stolen refresh token can be used indefinitely. **Fixed**: Changed to `TokenUsage.OneTimeOnly` with absolute expiration.

### Medium Severity Findings

9-12. Added CORS origins, HTTPS/HSTS enforcement, CSP headers, and rate limiting as described above.
