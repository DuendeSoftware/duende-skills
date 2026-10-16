# Token caching in v4

v4 moved to .NET's **HybridCache** (`Microsoft.Extensions.Caching.Hybrid`) for client credentials tokens.

- **Default:** an in-process memory cache (L1). If you register an `IDistributedCache` (Redis, SQL Server), HybridCache uses it as L2, shared across instances.
- Entries are keyed by client name (plus parameters such as scope/resource/DPoP), with a prefix.
- Lifetime equals the token's `expires_in` minus a buffer (`CacheLifetimeBuffer`, default 60 seconds), so tokens are renewed slightly before expiry.
- HybridCache provides stampede protection: concurrent requests for the same token share one fetch to the STS.
- In v3, `IDistributedCache` was used directly (`AddDistributedMemoryCache` by default).
- User tokens (OIDC) aren't in this cache; they're stored in the authentication session (cookie) or a custom `IUserTokenStore`.
