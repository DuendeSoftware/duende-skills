# Diagnosing Random Logouts in Load-Balanced BFF Deployments

The root cause is that each BFF instance generates its own **ASP.NET Core Data Protection key ring** by default. When instance A encrypts the authentication cookie, instances B and C cannot decrypt it because they have different keys. When the load balancer routes a subsequent request to a different instance, that instance sees an unreadable cookie and treats the user as unauthenticated — hence the "random logout."

There are two things you need to fix:

## 1. Share the Data Protection Key Ring

All instances must share the same encryption keys. Use a persistent, shared store:

```csharp
// Option A: Persist keys to a database via Entity Framework
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<ApplicationDbContext>()
    .SetApplicationName("my-bff-app"); // Ensures all instances use the same app discriminator

// Option B: Persist keys to Azure Blob Storage + protect with Key Vault
builder.Services.AddDataProtection()
    .PersistKeysToAzureBlobStorage(new Uri("https://mystore.blob.core.windows.net/keys/dp-keys.xml"))
    .ProtectKeysWithAzureKeyVault(new Uri("https://myvault.vault.azure.net/keys/dp-key"));

// Option C: Persist keys to Redis
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(
        ConnectionMultiplexer.Connect("redis-server:6379"),
        "DataProtection-Keys");
```

Without a shared key store, the default behavior is:

```csharp
// ❌ Each instance generates its own keys in memory/local disk
// Cookies encrypted by instance A cannot be decrypted by instance B
builder.Services.AddDataProtection(); // No shared persistence — broken in clusters
```

## 2. Use Server-Side Sessions with a Shared Store

Even with shared Data Protection keys, the default cookie-based session embeds all claims and tokens directly in the cookie. For production multi-instance deployments, use server-side sessions backed by a shared database so that any instance can resolve the session:

```csharp
builder.Services.AddBff(options =>
{
    options.SessionCleanupInterval = TimeSpan.FromMinutes(5);
})
.AddEntityFrameworkServerSideSessions(options =>
{
    options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
})
.AddSessionCleanupBackgroundProcess();
```

With `AddEntityFrameworkServerSideSessions`, the cookie only carries a session ID. The actual session data (claims, tokens) is stored in SQL Server and accessible by all instances.

**Do not use `AddServerSideSessions()` without EF** — that stores sessions in-memory, which has the same problem: sessions created on one instance are invisible to others.

## Summary

| Problem | Fix |
|---|---|
| Cookie encryption keys differ per instance | `AddDataProtection()` with a shared persistent store |
| Session data embedded in cookie or stored in-memory | `AddEntityFrameworkServerSideSessions()` with a shared database |

Both fixes are required for reliable multi-instance BFF deployments.
