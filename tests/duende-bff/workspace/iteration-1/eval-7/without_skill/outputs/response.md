# Fixing Random Logouts Behind a Load Balancer

This is a classic problem with multi-instance ASP.NET Core deployments. The issue is that ASP.NET Core uses **Data Protection** to encrypt and decrypt authentication cookies. By default, each instance generates its own set of encryption keys. When a user authenticates on instance A and the load balancer sends their next request to instance B, that instance can't decrypt the cookie and treats the user as unauthenticated.

## Fix: Share the Data Protection Key Ring

You need all instances to use the same Data Protection keys. Configure a shared, persistent key store:

```csharp
// Persist keys to a database
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<ApplicationDbContext>()
    .SetApplicationName("my-bff-app");

// Or persist to Azure Blob Storage
builder.Services.AddDataProtection()
    .PersistKeysToAzureBlobStorage(blobUri)
    .ProtectKeysWithAzureKeyVault(keyVaultUri);

// Or persist to Redis
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redisConnection, "DataProtection-Keys");
```

## Also Consider: Distributed Session Storage

If you're using server-side sessions (rather than embedding everything in the cookie), you'll also need a distributed session store so that all instances can access the same session data. Options include:

- **SQL Server** or **PostgreSQL** with a distributed cache provider
- **Redis** as a distributed cache via `AddStackExchangeRedisCache`

```csharp
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis-server:6379";
    options.InstanceName = "BffSessions:";
});

builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});
```

## Alternative: Sticky Sessions

As a quick workaround, you can configure your load balancer to use sticky sessions (session affinity) so that a user always hits the same instance. However, this is not recommended as a long-term solution because:

- It reduces the effectiveness of load balancing
- If an instance goes down, all its users lose their sessions
- It doesn't help with rolling deployments

## Summary

The primary fix is configuring a shared Data Protection key store across all instances. If you also use server-side session storage, that needs to be distributed as well (e.g., Redis or a database).
