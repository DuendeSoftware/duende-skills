The issue is the **ASP.NET Core Data Protection key ring**. By default, each BFF instance generates its own Data Protection keys in memory. Since the authentication cookie is encrypted with Data Protection, a cookie encrypted by instance A cannot be decrypted by instance B — resulting in a failed cookie read that looks like the user was never authenticated.

## Root Cause

Each BFF instance has its own isolated Data Protection key ring. When a user authenticates on instance A, the session cookie is encrypted with A's keys. When a subsequent request hits instance B (via the load balancer), B cannot decrypt the cookie, so it treats the user as unauthenticated.

## Fix

Two changes are needed:

### 1. Share the Data Protection Key Ring

All instances must share the same encryption keys. Persist keys to a shared store:

```csharp
// Program.cs
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<ApplicationDbContext>()      // Or PersistKeysToAzureBlobStorage, Redis, etc.
    .SetApplicationName("my-bff-app");                   // Ensure consistent application discriminator

// Alternative: Redis
// builder.Services.AddDataProtection()
//     .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys");

// Alternative: Azure Blob + Key Vault
// builder.Services.AddDataProtection()
//     .PersistKeysToAzureBlobStorage(blobClient)
//     .ProtectKeysWithAzureKeyVault(keyVaultKeyUri, credential);
```

### 2. Use Server-Side Sessions with a Shared Store

In-memory sessions are node-local. Use `AddEntityFrameworkServerSideSessions` so session data is persisted in a database accessible to all instances:

```csharp
builder.Services.AddBff()
    .ConfigureOpenIdConnect(options => { /* ... */ })
    .ConfigureCookies(options =>
    {
        options.Cookie.SameSite = SameSiteMode.Lax;
    })
    .AddEntityFrameworkServerSideSessions(options =>
    {
        options.UseSqlServer(builder.Configuration.GetConnectionString("BffSessions"));
    })
    .AddSessionCleanupBackgroundProcess();
```

With these two changes, any instance can decrypt the cookie and find the session data in the shared database.
