**Generally no — reference tokens are a poor fit for offline-capable apps.**

Reasons:
- Reference tokens are pointers to data in the persisted grant store. An API can only validate one by calling the introspection endpoint (or its cache), so validation needs a live connection to IdentityServer. That's exactly what offline/intermittently connected scenarios lack.
- Revocation is immediate (delete the stored grant), but only matters to parties that can reach IdentityServer. An offline field app can't be affected until it reconnects, so you gain little.
- It adds introspection latency and a hard availability dependency at scale; caching introspection delays revocation.

Recommended alternative:
- Use **JWT access tokens** (default type), validated locally by signature via JWKS — no network call at validation time.
- Keep them **short-lived (5–15 minutes)**, since JWTs can't be revoked before `exp`.
- Use **refresh tokens** (`AllowOfflineAccess = true`, `offline_access` scope, sliding + absolute lifetimes) for longevity. Revocation via `/connect/revocation` applies to refresh tokens (and reference tokens), so revoking the refresh token stops the app from getting new access tokens; the exposure window is bounded by the access token lifetime.
- `ReUse` rotation (default) is robust to network drops — important for field apps with flaky connectivity.

```csharp
new Client
{
    ClientId = "mobile_app",
    // ...
    AllowedScopes = { "openid", "profile", "api1", "offline_access" },
    AllowOfflineAccess = true,
    AccessTokenType = AccessTokenType.Jwt,   // default
    AccessTokenLifetime = 600,
    RefreshTokenExpiration = TokenExpiration.Sliding,
    AbsoluteRefreshTokenLifetime = 2592000,
    SlidingRefreshTokenLifetime = 86400
}
```

Use reference tokens only for online-only, sensitive APIs where instant revocation matters more than availability.
