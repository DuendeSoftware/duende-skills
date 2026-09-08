# Security Audit of the IdentityServer Configuration

I reviewed `Program.cs`, `appsettings.json`, and the project file. Here are the issues I found and what I changed.

## Issues found and fixed

1. **Developer signing credential in production** — `AddDeveloperSigningCredential()` creates a temporary/dev key. Replaced it with Duende's automatic key management so keys are generated, rotated, and stored properly.
2. **Implicit flow** — `spa.legacy` used `GrantTypes.Implicit` with `AllowAccessTokensViaBrowser`. Migrated it to authorization code + PKCE and removed the browser-token setting.
3. **PKCE disabled** — `web.app` had `RequirePkce = false`. Set it to `true`.
4. **Wildcard redirect URIs** — `web.app` used `https://*.example.com/...`. Replaced with exact URIs.
5. **Over-broad grant type** — `web.app` used `CodeAndClientCredentials`. Reduced to `GrantTypes.Code`.
6. **Hardcoded secrets** — `web.app`, `background.worker`, and `internal.api.consumer` had inline secrets. Loaded them from configuration.
7. **Long access token** — `web.app` had an 8-hour access token. Reduced to 5 minutes.
8. **Refresh token reuse** — `web.app` reused refresh tokens with a 30-day sliding window. Switched to one-time use with an absolute lifetime.
9. **No HTTPS/HSTS** — Added forwarded headers (for the proxy), HTTPS redirection (308), and HSTS.
10. **No security headers** — Added a CSP + `X-Frame-Options: DENY` on the UI pages.

## Updated clients

```csharp
var config = builder.Configuration;

// web.app
new Client
{
    ClientId = "web.app",
    ClientName = "Main Web Application",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    ClientSecrets = { new Secret(config["ClientSecrets:WebApp"]!.Sha256()) },
    RedirectUris = { "https://app.example.com/signin-oidc" },
    PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" },
    AllowedScopes = { "openid", "profile", "email", "catalog.read", "catalog.write" },
    AllowOfflineAccess = true,
    AccessTokenLifetime = 300,
    RefreshTokenUsage = TokenUsage.OneTimeOnly,
    RefreshTokenExpiration = TokenExpiration.Absolute,
    AbsoluteRefreshTokenLifetime = 86400
},

// spa.legacy (migrated)
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

// background.worker & internal.api.consumer — secrets from config
new Client
{
    ClientId = "background.worker",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret(config["ClientSecrets:BackgroundWorker"]!.Sha256()) },
    AllowedScopes = { "internal-api", "orders.manage" },
    AccessTokenLifetime = 3600
}
```

## Key management + transport (outline)

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);
    options.KeyManagement.DataProtectKeys = true;
})
// AddDeveloperSigningCredential removed
.AddInMemoryClients(/* ... */);

builder.Services.AddHsts(o => { o.MaxAge = TimeSpan.FromDays(365); o.IncludeSubDomains = true; o.Preload = true; });
builder.Services.AddHttpsRedirection(o => o.RedirectStatusCode = StatusCodes.Status308PermanentRedirect);

var app = builder.Build();
app.UseForwardedHeaders();
app.UseHttpsRedirection();
app.UseHsts();
app.UseIdentityServer();
```

## Summary

The biggest risks were the developer signing key in production, the implicit-flow SPA, disabled PKCE, and wildcard redirect URIs — all of which are now fixed. I also shortened the access token lifetime, switched refresh tokens to one-time use, externalized the secrets, and added HTTPS/HSTS plus CSP headers. M2M clients (`background.worker`, `internal.api.consumer`) keep their 1-hour tokens since they aren't interactive, but ideally they'd move to certificate/`private_key_jwt` authentication instead of shared secrets. I'd also recommend adding rate limiting to the token and authorize endpoints and enabling audit events.
