# Active-active across two regions

Problems:
1. **Different issuers.** Each host builds its issuer from the request host, so tokens from `eu.` have `iss=https://eu...` and the APIs only trust one. Fix: use one common public host/issuer (a global `login.example.com` via GeoDNS/traffic manager) or set `options.IssuerUri = "https://login.example.com"` on both.
2. **Different signing keys** → APIs can't validate tokens from the other region. Share signing keys: use the same static certificate/key or a shared key store.
3. **Separate DB replicas with lag** → refresh token / grant written in EU isn't yet in the US replica → `invalid_grant`. Write operational data (persisted grants) to a single primary/multi-writer DB with strong consistency, or use sticky routing by session.
4. **Data Protection keys** must be shared, with the same application name.

```csharp
builder.Services.AddIdentityServer(o =>
{
    o.IssuerUri = "https://login.example.com";
})
.AddOperationalStore(o => o.ConfigureDbContext = b => b.UseSqlServer(primaryCs))
.AddConfigurationStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs))
.AddSigningCredential(cert);   // same cert in both regions

builder.Services.AddDataProtection()
    .SetApplicationName("IdentityServer")
    .PersistKeysToDbContext<KeysContext>();
```
Also share a distributed cache, and keep clocks in sync.
