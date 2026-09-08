# Random logouts across 3 BFF instances — Data Protection key ring

## Root cause

Your BFF's authentication cookie (and anti-forgery tokens) are encrypted with **ASP.NET Core Data Protection**. By default each instance generates its **own** in-memory key ring. So a cookie encrypted by instance A **cannot be decrypted** by instance B or C. When the load balancer sends a user to a different instance than the one that issued their cookie, decryption fails and they appear logged out — exactly the "random" pattern you see.

BFF depends on Data Protection the same way IdentityServer does; in any multi-instance deployment the key ring **must be shared**.

## Fix 1 (required): share the Data Protection key ring

Persist keys to a store all three instances can read. Any of these works — pick what fits your infra:

```csharp
// ✅ Option A: database-backed key ring (EF Core)
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<ApplicationDbContext>()
    .SetApplicationName("bff-host");   // same app name on every instance

// ✅ Option B: Azure Blob Storage + Key Vault
builder.Services.AddDataProtection()
    .PersistKeysToAzureBlobStorage(blobUri, tokenCredential)
    .ProtectKeysWithAzureKeyVault(keyVaultKeyId, tokenCredential)
    .SetApplicationName("bff-host");

// ✅ Option C: Redis
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redisConnection, "DataProtection-Keys")
    .SetApplicationName("bff-host");
```

The critical point is that **all instances use the same persistent key store and the same application name**, so keys created by one node are usable by the others.

## Fix 2 (strongly recommended): shared server-side sessions

Even with a shared key ring, the default in-memory session store isn't shared. Move sessions to a **persistent, shared** store so a request landing on any node finds the session:

```csharp
// dotnet add package Duende.BFF.EntityFramework
builder.Services.AddBff()
    .AddEntityFrameworkServerSideSessions(options =>
    {
        options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
    });
```

This also gives you server-side revocation and keeps the cookie tiny (just a session id).

## Summary

- **Cause:** per-instance Data Protection keys → cookies from one node can't be decrypted by another.
- **Primary fix:** `AddDataProtection().PersistKeysTo…()` with a shared store + a common `SetApplicationName`.
- **Also do:** `AddEntityFrameworkServerSideSessions()` for a shared session store instead of in-memory.

Avoid relying on load-balancer sticky sessions as the "fix" — it masks the problem and still fails on scale-in/rollout.
