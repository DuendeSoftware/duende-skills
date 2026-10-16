# IdentityServer security audit

## Findings and fixes

| # | Issue | Severity | Fix |
|---|---|---|---|
| 1 | `AddDeveloperSigningCredential()` | High | Automatic key management + shared Data Protection |
| 2 | No HTTPS redirect / HSTS / forwarded headers | High | Added |
| 3 | `web.app`: PKCE off, wildcard URIs, 8h tokens, ReUse refresh, mixed grants | High | Hardened |
| 4 | `spa.legacy` uses implicit | High | Code + PKCE |
| 5 | Hardcoded secrets, SHA256 literals | High | From configuration |
| 6 | Secrets in appsettings.json (plaintext) | Med | Secret store/env vars |
| 7 | `AllowedHosts: "*"` | Low | Restrict host |
| 8 | No events/audit logging | Med | Enable events |
| 9 | No rate limiting / CSP | Med | Added |
| 10 | Old Serilog package, other deps | Low | Update |
| 11 | `background.worker` has wide scopes; `internal-api` shared | Low | Least privilege |
| 12 | native.app refresh/RequireClientSecret=false OK (public client) | Info | fine |

## Updated Program.cs (key parts)

```csharp
using System.Net;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseSerilog((ctx, lc) => lc.WriteTo.Console().ReadFrom.Configuration(ctx.Configuration));

string Secret(string key) => builder.Configuration[$"ClientSecrets:{key}"]
    ?? throw new InvalidOperationException($"Missing ClientSecrets:{key}");

builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.KnownProxies.Clear(); o.KnownNetworks.Clear();
    o.KnownProxies.Add(IPAddress.Parse(builder.Configuration["ReverseProxy:ProxyAddress"]!));
});
builder.Services.AddHsts(o => { o.MaxAge = TimeSpan.FromDays(365); o.IncludeSubDomains = true; o.Preload = true; });

builder.Services.AddDataProtection()
    .SetApplicationName("IdentityServer")
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"));

builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = 429;
    o.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
    {
        var ip = ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        if (ctx.Request.Path.StartsWithSegments("/connect/token"))
            return RateLimitPartition.GetSlidingWindowLimiter($"t:{ip}", _ => new() { PermitLimit = 20, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 6 });
        if (ctx.Request.Path.StartsWithSegments("/connect/authorize"))
            return RateLimitPartition.GetSlidingWindowLimiter($"a:{ip}", _ => new() { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), SegmentsPerWindow = 6 });
        return RateLimitPartition.GetNoLimiter("none");
    });
});

builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = builder.Configuration["IdentityServer:IssuerUri"];
    options.KeyManagement.Enabled = true;
    options.KeyManagement.SigningAlgorithms = new[]
    {
        new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256),
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)
    };
    options.Events.RaiseSuccessEvents = true;
    options.Events.RaiseFailureEvents = true;
    options.Events.RaiseErrorEvents = true;
    options.Events.RaiseInformationEvents = true;
})
.AddInMemoryIdentityResources(/* unchanged */)
.AddInMemoryApiScopes(/* unchanged */)
.AddInMemoryClients(new List<Client>
{
    new Client
    {
        ClientId = "web.app",
        AllowedGrantTypes = GrantTypes.Code,
        RequirePkce = true,
        ClientSecrets = { new Secret(Secret("WebApp").Sha256()) },
        RedirectUris = { "https://app.example.com/signin-oidc" },
        PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
        AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },
        AllowOfflineAccess = true,
        AccessTokenLifetime = 300,
        RefreshTokenUsage = TokenUsage.OneTimeOnly,
        RefreshTokenExpiration = TokenExpiration.Absolute,
        AbsoluteRefreshTokenLifetime = 28800
    },
    new Client
    {
        ClientId = "spa.legacy",
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
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret(Secret("Worker").Sha256()) },
        AllowedScopes = { "internal-api", "orders.manage" },
        AccessTokenLifetime = 3600
    },
    new Client
    {
        ClientId = "internal.api.consumer",
        AllowedGrantTypes = GrantTypes.ClientCredentials,
        ClientSecrets = { new Secret(Secret("InternalService").Sha256()) },
        AllowedScopes = { "internal-api" },
        AccessTokenType = AccessTokenType.Jwt,
        AccessTokenLifetime = 3600
    },
    // native.app unchanged (already PKCE, rotating refresh tokens, short lifetime)
});

builder.Services.AddRazorPages();
var app = builder.Build();

app.UseForwardedHeaders();
if (!app.Environment.IsDevelopment()) app.UseHsts();
app.UseHttpsRedirection();
app.Use(async (ctx, next) =>
{
    ctx.Response.Headers["Content-Security-Policy"] = "default-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'";
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    ctx.Response.Headers["Referrer-Policy"] = "no-referrer";
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

`appsettings.json`: replace `AllowedHosts` with `identity.example.com`, remove plaintext secrets from the file and supply them through environment variables / a vault (and rotate the ones that were committed). Also `GrantTypes.CodeAndClientCredentials` was removed from web.app; if the app needs M2M, create a separate client. Consider moving clients/config to an EF store, and updating Serilog/Google auth packages. Remaining recommendations: server-side sessions, client-credentials secrets with private_key_jwt, regular key rotation reviews, and monitoring of events.
