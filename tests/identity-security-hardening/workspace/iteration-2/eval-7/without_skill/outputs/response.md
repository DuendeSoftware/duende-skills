# Security Audit — IdentityServer Configuration

## Issues Found

| # | Issue | Severity |
|---|-------|----------|
| 1 | Developer signing credential in production | Critical |
| 2 | Implicit flow on spa.legacy | High |
| 3 | Wildcard redirect URIs on web.app | High |
| 4 | PKCE disabled on web.app | High |
| 5 | Hardcoded client secrets | Medium |
| 6 | Long access token lifetime on web.app | Medium |
| 7 | Refresh token reuse on web.app | Medium |

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

var config = builder.Configuration;

builder.Services.AddIdentityServer()
    .AddSigningCredential(new X509Certificate2("signing-cert.pfx", config["CertPassword"]))
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
            AllowedGrantTypes = GrantTypes.Code,
            RequirePkce = true,

            ClientSecrets = { new Secret(config["ClientSecrets:WebApp"].Sha256()) },

            RedirectUris = { "https://app.example.com/signin-oidc" },
            PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },

            AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },

            AllowOfflineAccess = true,
            AccessTokenLifetime = 3600,
            RefreshTokenUsage = TokenUsage.OneTimeOnly,
            RefreshTokenExpiration = TokenExpiration.Absolute,
            AbsoluteRefreshTokenLifetime = 86400,

            AllowedCorsOrigins = { "https://app.example.com" }
        },

        // Migrated from implicit to authorization code
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
            ClientSecrets = { new Secret(config["ClientSecrets:Worker"].Sha256()) },
            AllowedScopes = { "internal-api", "orders.manage" },
            AccessTokenLifetime = 3600
        },

        new Client
        {
            ClientId = "internal.api.consumer",
            ClientName = "Internal API Consumer",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret(config["ClientSecrets:Internal"].Sha256()) },
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

## Remediation Summary

1. **Developer signing credential** — Replaced `AddDeveloperSigningCredential()` with `AddSigningCredential()` using an X.509 certificate. For production, use a certificate stored in a certificate store or key vault.

2. **Implicit flow** — Migrated `spa.legacy` from `GrantTypes.Implicit` to `GrantTypes.Code` with `RequirePkce = true`. Removed `AllowAccessTokensViaBrowser`.

3. **Wildcard redirect URIs** — Replaced `https://*.example.com/signin-oidc` with exact match `https://app.example.com/signin-oidc`.

4. **PKCE** — Enabled `RequirePkce = true` on `web.app`.

5. **Hardcoded secrets** — All client secrets now loaded from configuration.

6. **Token lifetime** — Reduced `web.app` access token from 8 hours to 1 hour.

7. **Refresh token reuse** — Changed to `TokenUsage.OneTimeOnly` with absolute expiration.
