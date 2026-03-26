# IdentityServer Security Audit Report

## Findings and Remediations

### Critical Issues

#### 1. Developer Signing Credential in Production
**Finding:** `AddDeveloperSigningCredential()` generates an ephemeral RSA key not suitable for production.
**Remediation:** Replace with automatic key management using ES256 + RS256:

```csharp
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
});
```

#### 2. Implicit Flow Client (spa.legacy)
**Finding:** `spa.legacy` uses `GrantTypes.Implicit` with `AllowAccessTokensViaBrowser = true`. Tokens are exposed in URL fragments, browser history, and referrer headers.
**Remediation:** Migrate to authorization code + PKCE:

```csharp
new Client
{
    ClientId = "spa.legacy",
    AllowedGrantTypes = GrantTypes.Code,
    RequirePkce = true,
    RequireClientSecret = false,
    // Remove AllowAccessTokensViaBrowser
    RedirectUris = { "https://spa.example.com/callback" },
    PostLogoutRedirectUris = { "https://spa.example.com" },
    AllowedScopes = { "openid", "profile", "catalog.read" },
    AllowedCorsOrigins = { "https://spa.example.com" }
}
```

#### 3. PKCE Disabled on web.app
**Finding:** `RequirePkce = false` on the web.app client.
**Remediation:** Set `RequirePkce = true`.

### High Issues

#### 4. Wildcard Redirect URIs (web.app)
**Finding:** `RedirectUris = { "https://*.example.com/signin-oidc" }` — allows redirect to any subdomain, enabling open redirector attacks.
**Remediation:** Replace with exact-match URIs:

```csharp
RedirectUris = { "https://app.example.com/signin-oidc" },
PostLogoutRedirectUris = { "https://app.example.com/signout-callback-oidc" }
```

#### 5. Hardcoded Client Secrets
**Finding:** `"SuperSecret123".Sha256()`, `"WorkerSecret!".Sha256()`, `"InternalSecret".Sha256()` are hardcoded in source.
**Remediation:** Load from configuration:

```csharp
ClientSecrets = { new Secret(builder.Configuration["ClientSecrets:WebApp"].Sha256()) }
```

#### 6. 8-Hour Access Tokens (web.app)
**Finding:** `AccessTokenLifetime = 28800` (8 hours). A stolen token has an 8-hour replay window.
**Remediation:** Reduce to 5 minutes:

```csharp
AccessTokenLifetime = 300, // 5 minutes
```

#### 7. Refresh Token Reuse (web.app)
**Finding:** `RefreshTokenUsage = TokenUsage.ReUse` means a stolen refresh token remains valid indefinitely.
**Remediation:** Use one-time rotation:

```csharp
RefreshTokenUsage = TokenUsage.OneTimeOnly,
RefreshTokenExpiration = TokenExpiration.Absolute,
AbsoluteRefreshTokenLifetime = 86400
```

#### 8. Mixed Grant Types (web.app)
**Finding:** `GrantTypes.CodeAndClientCredentials` combines user and machine flows.
**Remediation:** Use `GrantTypes.Code` only.

### Medium Issues

#### 9. No HTTPS/HSTS Configuration
**Finding:** No `UseHttpsRedirection()`, `UseHsts()`, or `UseForwardedHeaders()` in the middleware pipeline.
**Remediation:** Add transport security middleware.

#### 10. No Rate Limiting
**Finding:** Token and authorize endpoints are unprotected against brute-force.
**Remediation:** Add `AddRateLimiter` with per-endpoint policies.

#### 11. No CSP Headers
**Finding:** UI pages have no Content-Security-Policy, exposing them to XSS and clickjacking.
**Remediation:** Add CSP middleware with `frame-ancestors 'none'` and `object-src 'none'`.

#### 12. Empty CORS Origins on web.app
**Finding:** `AllowedCorsOrigins = { }` — no CORS origins configured.
**Remediation:** Add the application origin.

## Audit Summary

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1 | Developer signing credential | Critical | Fixed — automatic key management |
| 2 | Implicit flow (spa.legacy) | Critical | Fixed — migrated to Code + PKCE |
| 3 | PKCE disabled (web.app) | Critical | Fixed — RequirePkce = true |
| 4 | Wildcard redirect URIs | High | Fixed — exact-match URIs |
| 5 | Hardcoded client secrets | High | Fixed — loaded from configuration |
| 6 | 8-hour access tokens | High | Fixed — reduced to 5 minutes |
| 7 | Refresh token reuse | High | Fixed — OneTimeOnly rotation |
| 8 | Mixed grant types | High | Fixed — Code only |
| 9 | No HTTPS/HSTS | Medium | Fixed — added transport security |
| 10 | No rate limiting | Medium | Recommended — add per-endpoint limits |
| 11 | No CSP headers | Medium | Recommended — add CSP middleware |
| 12 | Empty CORS origins | Medium | Fixed — added app origin |
