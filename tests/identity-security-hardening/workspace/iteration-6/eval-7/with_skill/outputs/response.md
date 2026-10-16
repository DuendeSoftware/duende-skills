# Security audit against the Production Security Checklist

## Findings

| # | Area | Finding | Fix |
|---|---|---|---|
| 1 | Transport | No HTTPS redirect, no HSTS; `ReverseProxy:ProxyAddress` configured but unused (http:// issuer risk) | `UseForwardedHeaders` (known proxy only), HTTPS redirect 308, HSTS 1y + subdomains + preload |
| 2 | Keys | `AddDeveloperSigningCredential()` | Automatic key management, ES256 + RS256, 90d/14d/14d |
| 3 | Keys | No Data Protection config | Shared persistent keys, app name, certificate protection |
| 4 | Tokens | `web.app` 8h access tokens, `ReUse` refresh, 30d sliding | 300s, `OneTimeOnly`, absolute 24h |
| 5 | Clients | `web.app` `RequirePkce=false` | `true` |
| 6 | Clients | `web.app` wildcard redirect/post-logout URIs | Exact URIs |
| 7 | Clients | `web.app` `CodeAndClientCredentials` | `Code` only |
| 8 | Clients | `spa.legacy` implicit flow, tokens via browser | Code + PKCE, no secret |
| 9 | Secrets | Literals in `web.app`, `background.worker`, `internal.api.consumer` | Load from configuration/vault (+ rotate) |
| 10 | Secrets | Plaintext secrets in `appsettings.json` | Env vars/secret store; fail-fast if missing |
| 11 | Tokens | `internal.api.consumer` JWT, no reference token; worker 1h | Reference tokens for internal API; keep short |
| 12 | CSP | No security headers | CSP, X-Frame-Options, nosniff, referrer policy |
| 13 | Rate limit | None on token/authorize | Global partitioned limiter |
| 14 | Sessions | Cookie sliding, no server-side sessions | Server-side sessions, 8h absolute, back-channel logout |
| 15 | Events | Not enabled | Success/failure/error/information events |
| 16 | Host | `AllowedHosts: "*"` | Restrict to the issuer host |

`native.app` already conforms (PKCE, OneTimeOnly, 5 min tokens, no secret as a public client).

## Updated `Program.cs`

```csharp
using System.Net;
using System.Threading.RateLimiting;
using Duende.IdentityServer;
using Duende.IdentityServer.Configuration;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.IdentityModel.Tokens;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

string RequireSecret(string key) =>
    builder.Configuration[$"ClientSecrets:{key}"]
    ?? throw new InvalidOperationException($"Missing ClientSecrets:{key}");

// ---- Transport ----
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.KnownProxies.Add(IPAddress.Parse(builder.Configuration["ReverseProxy:ProxyAddress"]!));
    o.ForwardLimit = 1;
});
builder.Services.AddHsts(o => { o.MaxAge = TimeSpan.FromDays(365); o.IncludeSubDomains = true; o.Preload = true; });
builder.Services.AddHttpsRedirection(o => { o.RedirectStatusCode = StatusCodes.Status308PermanentRedirect; o.HttpsPort = 443; });

// ---- Data Protection ----
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    // .ProtectKeysWithCertificate(...)  // encrypt at rest in production
    .SetApplicationName("identity-server");

// ---- Rate limiting (global limiter: only this applies to /connect/* endpoints) ----
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
    {
        var ip = ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var path = ctx.Request.Path.Value ?? "/";
        if (path.StartsWith("/connect/token", StringComparison.OrdinalIgnoreCase))
            return RateLimitPartition.GetSlidingWindowLimiter($"token:{ip}", _ => new SlidingWindowRateLimiterOptions
                { PermitLimit = 20, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 4, QueueLimit = 0 });
        if (path.StartsWith("/connect/authorize", StringComparison.OrdinalIgnoreCase))
            return RateLimitPartition.GetFixedWindowLimiter($"authorize:{ip}", _ => new FixedWindowRateLimiterOptions
                { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 });
        return RateLimitPartition.GetNoLimiter("unlimited");
    });
});

var idsvrBuilder = builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = builder.Configuration["IdentityServer:IssuerUri"];

    // Automatic key management
    options.KeyManagement.Enabled = true;
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);
    options.KeyManagement.DeleteRetiredKeys = true;
    options.KeyManagement.DataProtectKeys = true;
    options.KeyManagement.SigningAlgorithms = new[]
    {
        new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256),
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)
    };

    // Sessions
    options.ServerSideSessions.RemoveExpiredSessions = true;
    options.ServerSideSessions.RemoveExpiredSessionsFrequency = TimeSpan.FromMinutes(10);
    options.ServerSideSessions.ExpiredSessionsTriggerBackchannelLogout = true;
    options.Authentication.CoordinateClientLifetimesWithUserSession = true;
    options.Authentication.CookieLifetime = TimeSpan.FromHours(8);
    options.Authentication.CookieSlidingExpiration = false;

    // Audit events
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
})
.AddInMemoryIdentityResources(new List<IdentityResource>
{
    new IdentityResources.OpenId(), new IdentityResources.Profile(), new IdentityResources.Email()
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
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        ClientSecrets = { new Secret(RequireSecret("WebApp").Sha256()) },
        RedirectUris = { "https://app.example.com/signin-oidc" },
        PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
        AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },
        AccessTokenLifetime = 300,
        AllowOfflineAccess = true,
        RefreshTokenUsage = TokenUsage.OneTimeOnly,
        RefreshTokenExpiration = TokenExpiration.Absolute,
        AbsoluteRefreshTokenLifetime = 86400,
        CoordinateLifetimeWithUserSession = true,
        BackChannelLogoutUri = "https://app.example.com/bff/backchannel",
        BackChannelLogoutSessionRequired = true
    },
    new Client
    {
        ClientId = "spa.legacy",
        ClientName = "Legacy SPA",
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        RequireClientSecret = false,
        AllowAccessTokensViaBrowser = false,
        RedirectUris = { "https://spa.example.com/callback" },
        PostLogoutRedirectUris = { "https://spa.example.com" },
        AllowedScopes = { "openid", "profile", "catalog.read" },
        AllowedCorsOrigins = { "https://spa.example.com" },
        AccessTokenLifetime = 300
    },
    new Client
    {
        ClientId = "background.worker",
        ClientName = "Background Processing Service",
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret(RequireSecret("Worker").Sha256()) },
        AllowedScopes = { "internal-api", "orders.manage" },
        AccessTokenLifetime = 300
    },
    new Client
    {
        ClientId = "internal.api.consumer",
        ClientName = "Internal API Consumer",
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret(RequireSecret("InternalService").Sha256()) },
        AllowedScopes = { "internal-api" },
        AccessTokenType = AccessTokenType.Reference,   // revocable; API must use introspection
        AccessTokenLifetime = 300
    },
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
});

idsvrBuilder.AddServerSideSessions();   // needs license entitlement on v8
builder.Services.AddTransient<IEventSink, SeqEventSink>(); // or your audit sink; forwards to ILogger

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseForwardedHeaders();      // first
app.UseHttpsRedirection();
app.UseHsts();

app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? string.Empty;
    if (path.StartsWith("/account", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/consent", StringComparison.OrdinalIgnoreCase) ||
        path.StartsWith("/diagnostics", StringComparison.OrdinalIgnoreCase))
    {
        context.Response.Headers.Append("Content-Security-Policy",
            "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; " +
            "frame-ancestors 'none'; form-action 'self'; base-uri 'self'; object-src 'none'");
        context.Response.Headers.Append("X-Frame-Options", "DENY");
        context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
        context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    }
    await next();
});

app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();           // before UseIdentityServer
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();
app.Run();

public sealed class SeqEventSink : IEventSink
{
    private readonly ILogger<SeqEventSink> _logger;
    public SeqEventSink(ILogger<SeqEventSink> logger) => _logger = logger;
    public Task PersistAsync(Duende.IdentityServer.Events.Event evt)
    {
        _logger.LogInformation("{Name} ({Id}) {@Event}", evt.Name, evt.Id, evt);
        return Task.CompletedTask;
    }
}
```

## `appsettings.json` changes
- `"AllowedHosts": "identity.example.com"` instead of `*`.
- Remove committed secret values; provide `ClientSecrets__WebApp`, `ClientSecrets__Worker`, `ClientSecrets__InternalService` through environment variables/vault. The existing values and the old literals (`SuperSecret123`, `WorkerSecret!`, `InternalSecret`) are in git history, so rotate them (register new secret alongside old, then remove).

## Checklist status after the changes
- **Transport**: redirect ✔, HSTS ≥1y+subdomains ✔, forwarded headers restricted to `10.0.0.1` ✔. TLS 1.2+ is configured on the ALB listener (or Kestrel `ConfigureHttpsDefaults` if exposed directly).
- **Keys**: AKM enabled ✔, `DataProtectKeys` + durable shared Data Protection ✔ (add `ProtectKeysWithCertificate`), propagation ≥24h ✔, retention ≥ token lifetime ✔, ES256/RS256 ✔.
- **Tokens**: ≤300s ✔, `OneTimeOnly` ✔, audience validation: **you must enable at each API** (`ValidateAudience = true`, consider `ApiResource` per API).
- **Clients**: PKCE ✔, no implicit ✔, no wildcards ✔, secrets from config ✔; `private_key_jwt`/mTLS recommended for M2M.
- **CORS**: per-client exact origins ✔. **CSP** ✔. **Sessions** ✔. **Rate limiting** ✔ (global limiter, since protocol endpoints ignore named policies). **Events** ✔, plus raise `UserLoginSuccess/FailureEvent` in your login UI.

Remaining caveats: the in-memory stores don't persist sessions/keys across nodes; use the EF operational store for load-balanced production. Update Serilog and other packages regularly.
