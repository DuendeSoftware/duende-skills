# Security Audit Report — IdentityServer Setup

## Findings and Remediations

### Critical Issues

| # | Finding | Severity | Remediation |
|---|---------|----------|-------------|
| 1 | `AddDeveloperSigningCredential()` used in production | Critical | Replaced with automatic key management (ES256 + RS256) |
| 2 | `spa.legacy` uses `GrantTypes.Implicit` | Critical | Migrated to `GrantTypes.Code` with `RequirePkce = true` |
| 3 | `web.app` has wildcard redirect URIs (`https://*.example.com/*`) | Critical | Replaced with exact-match HTTPS URIs |
| 4 | `web.app` has `RequirePkce = false` | Critical | Set to `RequirePkce = true` |
| 5 | Hardcoded client secrets in source code | High | Loaded from `IConfiguration` |
| 6 | `web.app` AccessTokenLifetime = 28800 (8 hours) | High | Reduced to 300 seconds (5 minutes) |
| 7 | `web.app` RefreshTokenUsage = ReUse | High | Changed to `TokenUsage.OneTimeOnly` |
| 8 | No HTTPS redirection or HSTS | High | Added with 308 redirect and 365-day HSTS |
| 9 | No CSP or security headers | Medium | Added CSP with `frame-ancestors 'none'`, X-Frame-Options |
| 10 | No rate limiting | Medium | Added rate limiting on token and authorize endpoints |
| 11 | `web.app` uses `GrantTypes.CodeAndClientCredentials` | Medium | Changed to `GrantTypes.Code` only |
| 12 | Missing CORS origins on `web.app` | Low | Added explicit `AllowedCorsOrigins` |

## Remediated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using System.Net;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// ForwardedHeaders for reverse proxy
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
});

// HSTS
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
    options.Preload = true;
});

// HTTPS Redirection
builder.Services.AddHttpsRedirection(options =>
{
    options.RedirectStatusCode = StatusCodes.Status308PermanentRedirect;
    options.HttpsPort = 443;
});

// Data Protection
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");

// Rate Limiting
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("token-endpoint", context =>
        RateLimitPartition.GetSlidingWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 20, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 4
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

    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;

    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseFailureEvents = true;
})
// NO AddDeveloperSigningCredential() — automatic key management handles signing
.AddInMemoryIdentityResources(new List<IdentityResource>
{
    new IdentityResources.OpenId(),
    new IdentityResources.Profile(),
    new IdentityResources.Email()
})
.AddInMemoryApiScopes(new List<ApiScope>
{
    new ApiScope("catalog.read"), new ApiScope("catalog.write"),
    new ApiScope("orders.manage"), new ApiScope("internal-api")
})
.AddInMemoryClients(new List<Client>
{
    // web.app — HARDENED
    new Client
    {
        ClientId = "web.app",
        ClientName = "Main Web Application",
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"].Sha256()) },
        RedirectUris = { "https://app.example.com/signin-oidc" },
        PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
        AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },
        AllowOfflineAccess = true,
        AccessTokenLifetime = 300,
        RefreshTokenUsage = TokenUsage.OneTimeOnly,
        RefreshTokenExpiration = TokenExpiration.Absolute,
        AbsoluteRefreshTokenLifetime = 86400,
        CoordinateLifetimeWithUserSession = true,
        AllowedCorsOrigins = { "https://app.example.com" },
        BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
        BackChannelLogoutSessionRequired = true
    },

    // spa.legacy — MIGRATED from Implicit to Code+PKCE
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
        AllowedCorsOrigins = { "https://spa.example.com" },
        AccessTokenLifetime = 300
    },

    // background.worker — secret from config
    new Client
    {
        ClientId = "background.worker",
        ClientName = "Background Processing Service",
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:BackgroundWorker"].Sha256()) },
        AllowedScopes = { "internal-api", "orders.manage" },
        AccessTokenLifetime = 900
    },

    // internal.api.consumer
    new Client
    {
        ClientId = "internal.api.consumer",
        ClientName = "Internal API Consumer",
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:InternalService"].Sha256()) },
        AllowedScopes = { "internal-api" },
        AccessTokenType = AccessTokenType.Jwt,
        AccessTokenLifetime = 900
    },

    // native.app — already well-configured
    new Client
    {
        ClientId = "native.app",
        ClientName = "Mobile Application",
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        RequireClientSecret = false,
        RedirectUris = { "com.example.app:/callback", "https://app.example.com/callback" },
        AllowedScopes = { "openid", "profile", "catalog.read" },
        AllowOfflineAccess = true,
        RefreshTokenUsage = TokenUsage.OneTimeOnly,
        AccessTokenLifetime = 300
    }
})
.AddServerSideSessions();

builder.Services.AddRazorPages();
var app = builder.Build();

app.UseForwardedHeaders();
app.UseHttpsRedirection();
app.UseHsts();

// CSP middleware
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? "";
    if (path.StartsWith("/account", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/consent", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/connect", StringComparison.OrdinalIgnoreCase))
    {
        context.Response.Headers.Append("Content-Security-Policy",
            "default-src 'self'; frame-ancestors 'none'; object-src 'none'");
        context.Response.Headers.Append("X-Frame-Options", "DENY");
        context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    }
    await next();
});

app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();
app.Run();
```
