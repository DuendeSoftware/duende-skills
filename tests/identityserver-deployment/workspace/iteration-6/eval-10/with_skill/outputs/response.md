# Active-active in two regions

Your symptoms point to four problems.

## 1. Inconsistent issuer
`iss` is derived from the request host. `eu.login...` and `us.login...` issue different issuers, so APIs reject tokens from the other region. Every instance must resolve the **same issuer** for a given request: use one public host name (e.g. `login.example.com` via geo-DNS/global load balancer) with the same path base. With a single issuer you can pin it:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://login.example.com";
});
```
(Multi-Issuer/Spaces legitimately vary per host, but must resolve identically on every instance.)

## 2. Operational data replication lag → `invalid_grant`
Config data tolerates delayed replication; **operational data (codes, refresh tokens, sessions, signing keys) must be visible to every instance almost immediately**. A refresh token written in EU but read from a lagging US replica fails with `invalid_grant`. Use a single writable operational store (or synchronously replicated/multi-write), not independent async replicas.

```csharp
builder.Services.AddIdentityServer(o => o.IssuerUri = "https://login.example.com")
    .AddConfigurationStore(o => o.ConfigureDbContext = b => b.UseSqlServer(configCs))
    .AddOperationalStore(o =>
    {
        o.ConfigureDbContext = b => b.UseSqlServer(primaryCs);   // consistent across regions
        o.EnableTokenCleanup = true;
    });
```

## 3. Shared signing keys
Share signing keys via the shared key store (`ISigningKeyStore`, EF operational store) so APIs can validate tokens from either region; the file-system store is per-instance.

## 4. Shared Data Protection keys + clocks
```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<KeysContext>()
    .ProtectKeysWithCertificate(cert)
    .SetApplicationName("My.IdentityServer");
```
Same explicit application name everywhere; synchronize clocks (NTP).

## Also
- Keep runtime stateless; the current in-memory stores are only OK if every instance runs the identical build.
- Shared distributed cache (Redis) if using OIDC state formatter, PAR, replay cache.
- User accounts live outside IdentityServer stores: plan their replication separately.
- If cross-region synchronous consistency isn't achievable, prefer **active-passive with regional failover** and defined RPO/RTO rather than accepting eventual consistency for operational data.
