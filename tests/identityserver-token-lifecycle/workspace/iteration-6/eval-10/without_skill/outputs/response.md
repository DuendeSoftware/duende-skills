**Generally no.** Reference tokens are a poor fit for offline-capable apps.

Why:
- Reference tokens are opaque handles; the API must call IdentityServer's introspection endpoint (or you keep a shared store) to validate them. If the device is offline, or the API is reachable but IdentityServer isn't, validation fails. Offline use also can't benefit from local validation.
- "Instant" revocation is only instant for parties that can reach IdentityServer. An offline device can't be revoked anyway until it reconnects; whatever it holds or caches locally continues to work locally.
- Reference tokens add load and a dependency on IdentityServer for every API call (mitigated by caching, which delays revocation).

Better approach:
- Issue **short-lived JWT access tokens** (e.g. 5–15 minutes) validated locally by the API.
- Use **refresh tokens** (`AllowOfflineAccess = true`, `offline_access`) with sliding + absolute lifetimes, `OneTimeOnly` rotation for public/mobile clients, and PKCE. Revoke the refresh token (revocation endpoint or removing the grant) so the device can't obtain new access tokens; exposure is bounded by access token lifetime.
- Use DPoP or secure device storage to limit token theft.
- Where you truly need immediate revocation for specific high-risk APIs, use reference tokens or introspection just for those (via a separate client/resource), or add a revocation/deny-list check in the API when online.

In your config, `mobile_app` is a public PKCE client with `AccessTokenLifetime` unset (default 3600 s); shorten it and add `AllowOfflineAccess = true` plus `offline_access` scope rather than switching to `AccessTokenType.Reference`.
