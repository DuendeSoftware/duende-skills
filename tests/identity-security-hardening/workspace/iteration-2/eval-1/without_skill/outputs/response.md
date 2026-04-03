# Fix Transport Security Behind AWS ALB

The `IDX20803` error is happening because your IdentityServer is seeing `http://` instead of `https://` since the ALB terminates TLS. You need to set up forwarded headers so ASP.NET Core knows the original request was HTTPS.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.AspNetCore.HttpOverrides;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// Configure forwarded headers
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor |
        ForwardedHeaders.XForwardedProto;

    // Clear defaults and allow all proxies (ALB handles this)
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

// Add HSTS
builder.Services.AddHsts(options =>
{
    options.MaxAge = TimeSpan.FromDays(365);
    options.IncludeSubDomains = true;
});

// HTTPS redirection
builder.Services.AddHttpsRedirection(options =>
{
    options.HttpsPort = 443;
});

// IdentityServer registration
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

app.UseForwardedHeaders();
app.UseHttpsRedirection();

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
```

## What Changed

1. **ForwardedHeaders middleware** — Configured to read `X-Forwarded-For` and `X-Forwarded-Proto` headers from the ALB. Cleared the default known networks and proxies so it accepts forwarded headers.

2. **HSTS** — Added with a 365-day max age and `IncludeSubDomains`.

3. **HTTPS Redirection** — Added with port 443.

4. **Middleware ordering** — `UseForwardedHeaders()` is called first so the scheme is corrected before other middleware runs. HSTS is conditionally applied in non-development environments.
