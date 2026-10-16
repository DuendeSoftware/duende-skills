# Distributed cache in multi-instance IdentityServer

IdentityServer uses `IDistributedCache` for some state. Out of the box it's an in-memory implementation per instance. Notably, when you use external OIDC providers (`AddOpenIdConnect`), the handler stores state/nonce, and the OIDC authentication state is protected via Data Protection and – in some setups – `IDistributedCache` (e.g. the `ConfigureOpenIdConnectForStateDataFormat`/state caching, PAR, device flow throttling, replay cache for JWT client assertions). If the login request starts on instance A and the callback lands on instance B, B lacks the state/keys and login fails intermittently.

What you need:
1. **Distributed cache** (Redis or SQL Server):
```csharp
builder.Services.AddStackExchangeRedisCache(o =>
    o.Configuration = builder.Configuration.GetConnectionString("Redis"));
```
2. **Shared Data Protection keys** with a common application name:
```csharp
builder.Services.AddDataProtection()
    .SetApplicationName("IdentityServer")
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys");
```
3. Shared operational store (EF) and shared signing keys.
4. Make sure correlation/nonce cookies work: `SameSite=None; Secure` where needed, and sticky sessions are optional but not a replacement.

Also consider IdentityServer's own caching (`AddConfigurationStoreCache()`) — it's in-memory per node, which is fine, but expect brief inconsistency after config changes.
