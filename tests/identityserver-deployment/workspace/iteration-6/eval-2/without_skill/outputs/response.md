# CryptographicException on 3 replicas

**Cause:** ASP.NET Core Data Protection generates keys per instance and stores them locally (container filesystem). Each replica has different keys, so a cookie, antiforgery token, or protected state created by pod A can't be decrypted by pod B → intermittent `CryptographicException`. Pod restarts also lose the keys.

**Fix:** share a key ring and set a common application name.

```csharp
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;

builder.Services.AddDbContext<DataProtectionKeysContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddDataProtection()
    .SetApplicationName("IdentityServer")
    .PersistKeysToDbContext<DataProtectionKeysContext>();
    // optionally .ProtectKeysWithCertificate(cert) or Azure Key Vault
```

```csharp
public class DataProtectionKeysContext : DbContext, IDataProtectionKeyContext
{
    public DataProtectionKeysContext(DbContextOptions<DataProtectionKeysContext> o) : base(o) { }
    public DbSet<DataProtectionKey> DataProtectionKeys { get; set; } = default!;
}
```
(package `Microsoft.AspNetCore.DataProtection.EntityFrameworkCore`; run a migration.)

Alternatives: Redis (`PersistKeysToStackExchangeRedis`), Azure Blob Storage + Key Vault, or a shared persistent volume.

Also:
- Encrypt keys at rest (certificate / Key Vault) — otherwise they're stored in plaintext.
- Use the same signing keys on all replicas (automatic key management with a shared store, or static certificates), and shared operational store (EF) rather than in-memory.
- Use a shared distributed cache if needed (Redis).
- Same `SetApplicationName` on all pods so the key isolation matches.
