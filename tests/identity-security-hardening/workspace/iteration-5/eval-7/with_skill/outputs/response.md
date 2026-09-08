# IdentityServer Security Audit — Findings & Remediations

I audited `Program.cs`, `appsettings.json`, and `IdentityServer.csproj` against the Production Security Checklist. Below is every finding, its severity, and the fix applied.

## Findings summary

| # | Finding | Severity | Remediation |
|---|---------|----------|-------------|
| 1 | `AddDeveloperSigningCredential()` used in production | Critical | Replaced with automatic key management (ES256 primary, RS256 fallback, 90-day rotation, `DataProtectKeys`) + Data Protection to durable storage |
| 2 | `spa.legacy` uses `GrantTypes.Implicit` + `AllowAccessTokensViaBrowser` | Critical | Migrated to `GrantTypes.Code` + `RequirePkce = true`; removed `AllowAccessTokensViaBrowser` |
| 3 | `web.app` has `RequirePkce = false` | Critical | Set `RequirePkce = true` |
| 4 | `web.app` wildcard redirect/post-logout URIs (`https://*.example.com/...`) | Critical | Replaced with exact `https://app.example.com/...` URIs |
| 5 | `web.app` uses `GrantTypes.CodeAndClientCredentials` | High | Reduced to `GrantTypes.Code` (least grant) |
| 6 | Hardcoded secrets (`web.app`, `background.worker`, `internal.api.consumer`) | High | Loaded from `builder.Configuration`, still `.Sha256()`-hashed |
| 7 | `web.app` `AccessTokenLifetime = 28800` (8h) | High | Reduced to `300` (5 min) |
| 8 | `web.app` `RefreshTokenUsage = ReUse` + sliding 30-day | High | `OneTimeOnly` + `Absolute` 24h, `CoordinateLifetimeWithUserSession = true` |
| 9 | No HTTPS redirection / HSTS / forwarded headers | Critical | Added `ForwardedHeaders` (known proxy) → `HttpsRedirection` (308) → `HSTS` (1yr, subdomains, preload) |
| 10 | No CSP / anti-clickjacking headers on UI | High | Added CSP middleware (`frame-ancestors 'none'`, `object-src 'none'`) + `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff` |
| 11 | No rate limiting on token/authorize endpoints | High | Added global limiter partitioned by path (token 20/min sliding, authorize 10/min fixed) |
| 12 | `spa.legacy` empty/missing CORS handled; `web.app` had empty CORS | Low | Left per-client `AllowedCorsOrigins` explicit; no `AllowAnyOrigin` |
| 13 | Audit events not enabled | Medium | Enabled `RaiseSuccessEvents/FailureEvents/ErrorEvents/InformationEvents` |

## Remediated `Program.cs` (key sections)

```csharp
using System.Net;
using System.Threading.RateLimiting;
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.IdentityModel.Tokens;
using Serilog;

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;

builder.Host.UseSerilog((ctx, lc) => lc.WriteTo.Console().ReadFrom.Configuration(ctx.Configuration));

// --- Transport (finding 9) ---
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.KnownNetworks.Clear(); o.KnownProxies.Clear();
    o.KnownProxies.Add(IPAddress.Parse(config["ReverseProxy:ProxyAddress"] ?? "10.0.0.1"));
    o.ForwardLimit = 1;
});
builder.Services.AddHsts(o => { o.MaxAge = TimeSpan.FromDays(365); o.IncludeSubDomains = true; o.Preload = true; });
builder.Services.AddHttpsRedirection(o => { o.RedirectStatusCode = StatusCodes.Status308PermanentRedirect; o.HttpsPort = 443; });

// --- Rate limiting (finding 11) ---
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
    {
        var ip = ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var path = ctx.Request.Path.Value ?? "/";
        if (path.StartsWith("/connect/token", StringComparison.OrdinalIgnoreCase))
            return RateLimitPartition.GetSlidingWindowLimiter($"token:{ip}",
                _ => new SlidingWindowRateLimiterOptions { PermitLimit = 20, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 4, QueueLimit = 0 });
        if (path.StartsWith("/connect/authorize", StringComparison.OrdinalIgnoreCase))
            return RateLimitPartition.GetFixedWindowLimiter($"authorize:{ip}",
                _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 });
        return RateLimitPartition.GetNoLimiter("unlimited");
    });
});

// --- IdentityServer (findings 1, 13) ---
var idsvr = builder.Services.AddIdentityServer(options =>
{
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;

    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
    options.KeyManagement.PropagationTime  = TimeSpan.FromDays(14);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);
    options.KeyManagement.DataProtectKeys = true;
    options.KeyManagement.SigningAlgorithms = new[]
    {
        new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256),
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256) { UseX509Certificate = true }
    };
})
// finding 1: AddDeveloperSigningCredential() REMOVED
.AddInMemoryIdentityResources(new List<IdentityResource>
{
    new IdentityResources.OpenId(), new IdentityResources.Profile(), new IdentityResources.Email()
})
.AddInMemoryApiScopes(new List<ApiScope>
{
    new("catalog.read","Read access to the catalog"), new("catalog.write","Write access to the catalog"),
    new("orders.manage","Manage orders"), new("internal-api","Internal API access")
})
.AddInMemoryClients(new List<Client>
{
    // web.app — findings 3,4,5,6,7,8
    new Client
    {
        ClientId = "web.app", ClientName = "Main Web Application",
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        ClientSecrets = { new Secret(config["ClientSecrets:WebApp"]!.Sha256()) },
        RedirectUris = { "https://app.example.com/signin-oidc" },
        PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
        AllowedScopes = { "openid","profile","email","catalog.read","catalog.write" },
        AllowOfflineAccess = true,
        AccessTokenLifetime = 300,
        RefreshTokenUsage = TokenUsage.OneTimeOnly,
        RefreshTokenExpiration = TokenExpiration.Absolute,
        AbsoluteRefreshTokenLifetime = 86400,
        CoordinateLifetimeWithUserSession = true
    },
    // spa.legacy — finding 2
    new Client
    {
        ClientId = "spa.legacy", ClientName = "Legacy SPA",
        AllowedGrantTypes = GrantTypes.Code, RequirePkce = true, RequireClientSecret = false,
        RedirectUris = { "https://spa.example.com/callback" },
        PostLogoutRedirectUris = { "https://spa.example.com" },
        AllowedScopes = { "openid","profile","catalog.read" },
        AllowedCorsOrigins = { "https://spa.example.com" },
        AccessTokenLifetime = 300
    },
    // background.worker — finding 6
    new Client
    {
        ClientId = "background.worker", ClientName = "Background Processing Service",
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret(config["ClientSecrets:BackgroundWorker"]!.Sha256()) },
        AllowedScopes = { "internal-api","orders.manage" },
        AccessTokenLifetime = 3600 // M2M, not interactive
    },
    // internal.api.consumer — finding 6
    new Client
    {
        ClientId = "internal.api.consumer", ClientName = "Internal API Consumer",
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret(config["ClientSecrets:InternalService"]!.Sha256()) },
        AllowedScopes = { "internal-api" },
        AccessTokenType = AccessTokenType.Reference, // immediate revocation for internal API
        AccessTokenLifetime = 3600
    },
    // native.app — already hardened
    new Client
    {
        ClientId = "native.app", ClientName = "Mobile Application",
        AllowedGrantTypes = GrantTypes.Code, RequirePkce = true, RequireClientSecret = false,
        RedirectUris = { "com.example.app:/callback", "https://app.example.com/callback" },
        AllowedScopes = { "openid","profile","catalog.read" },
        AllowOfflineAccess = true, RefreshTokenUsage = TokenUsage.OneTimeOnly, AccessTokenLifetime = 300
    }
});

builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");

builder.Services.AddRazorPages();

var app = builder.Build();

// --- Pipeline order (finding 9, 10, 11) ---
app.UseForwardedHeaders();
app.UseHttpsRedirection();
app.UseHsts();

app.Use(async (ctx, next) =>   // CSP (finding 10)
{
    var p = ctx.Request.Path.Value ?? "";
    if (p.StartsWith("/account", StringComparison.OrdinalIgnoreCase) ||
        p.StartsWith("/consent", StringComparison.OrdinalIgnoreCase) ||
        p.StartsWith("/diagnostics", StringComparison.OrdinalIgnoreCase))
    {
        ctx.Response.Headers.Append("Content-Security-Policy",
            "default-src 'self'; frame-ancestors 'none'; object-src 'none'; base-uri 'self'; form-action 'self'");
        ctx.Response.Headers.Append("X-Frame-Options", "DENY");
        ctx.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    }
    await next();
});

app.UseRateLimiter();
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();
app.Run();
```

Also add `ClientSecrets:BackgroundWorker` to `appsettings.json` (real values via env/vault, not committed).

## Residual recommendations (not code-changed here)
- Upgrade sensitive M2M clients (`background.worker`) from shared secrets to `private_key_jwt` or mTLS.
- Enable server-side sessions + back-channel logout.
- Register a custom `IEventSink` to ship audit events to your SIEM.
- Set Kestrel `SslProtocols` to TLS 1.2+ if any instance is directly exposed.
