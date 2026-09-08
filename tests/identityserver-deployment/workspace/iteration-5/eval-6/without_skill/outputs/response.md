# Distributed caching for a multi-instance IdentityServer

## The likely cause of the intermittent external OIDC failures

When you run multiple instances behind a load balancer, an external login flow (redirect out to Google/Entra/etc. and back) spans **two requests that may land on different instances**. The challenge is issued by instance A, and the callback may be handled by instance B.

If the per-request state that ties those two hops together isn't available to whichever instance handles the callback, the flow fails — and because it depends on load-balancer routing, it fails **intermittently**. There are two pieces of shared state involved:

1. **Data Protection keys** — the OIDC correlation and nonce cookies are encrypted with Data Protection. If keys aren't shared, instance B can't decrypt the cookie instance A set.
2. **Server-side state / cache** — if any login state is cached in memory on one instance, another instance won't see it.

## Add a shared distributed cache

By default, ASP.NET Core's `IDistributedCache` is an **in-memory** implementation that is not shared between instances. Replace it with a real distributed cache like Redis so all instances read/write the same store:

```csharp
// Program.cs
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis:6379";
    options.InstanceName = "idsrv:";
});
```

Or SQL Server if you'd rather not run Redis:

```csharp
builder.Services.AddSqlServerCache(options =>
{
    options.ConnectionString =
        builder.Configuration.GetConnectionString("DefaultConnection");
    options.SchemaName = "dbo";
    options.TableName = "DistributedCache";
});
```

Do **not** leave the default in-memory `IDistributedCache` in place for a multi-instance deployment — it defeats the purpose.

## Also make sure the rest of the shared state is configured

A distributed cache alone won't fix everything. For a healthy multi-instance deployment you should also:

- **Share Data Protection keys** across instances (`PersistKeysToStackExchangeRedis` / DB + `SetApplicationName`) — this is what most directly fixes external OIDC correlation-cookie failures.
- **Use a shared operational store** (EF Core) so tokens, authorization codes, and consent are visible on every instance.
- **Share signing keys** so tokens signed by one instance validate on another.
- **Enable sticky sessions** on the load balancer as a stop-gap, though sharing state properly is the real fix.

## Summary

Register Redis (or SQL) as the distributed cache instead of the default in-memory one, and make sure Data Protection keys and the operational store are shared too. That eliminates the instance-to-instance state mismatch causing your intermittent external login failures.
