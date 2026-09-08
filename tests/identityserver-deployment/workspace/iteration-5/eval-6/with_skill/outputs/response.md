# Distributed caching for multi-instance IdentityServer

## Why your external OIDC logins fail intermittently

When a user starts an external login (to Google, Entra ID, another OIDC provider, etc.), IdentityServer's **OIDC state data formatter stores the external provider `state` server-side in ASP.NET Core's `IDistributedCache`** rather than round-tripping it all in the URL. The provider later redirects back to your callback with a reference to that state.

In a multi-instance deployment **without a shared distributed cache**, each instance has its own in-memory cache. So:

1. Instance **A** handles the outbound challenge and writes the state to *its* in-memory cache.
2. The user returns from the external provider and the load balancer routes the callback to instance **B**.
3. Instance **B** looks up the state in *its* cache, doesn't find it (A wrote it), and the flow fails.

Because it depends on which instance handles the callback, the failures are **intermittent** — exactly what you're seeing.

## Features that require a shared IDistributedCache

IdentityServer uses `IDistributedCache` for several features that all break across instances without a shared implementation:

| Feature                          | Why it needs a shared cache                                   |
| -------------------------------- | ------------------------------------------------------------- |
| **OIDC state data formatter**    | Stores external provider `state` server-side (your issue)     |
| **JWT replay cache**             | Prevents replay of JWT client-credential assertions           |
| **Device flow throttling**       | Rate-limits device polling consistently across instances      |
| **PAR authorization parameter store** | Stores Pushed Authorization Request data                 |

If state is written on one instance but the follow-up request hits another, any of these fail.

## Configure a shared distributed cache

Register a real distributed cache — Redis is the common choice — so all instances share it:

```csharp
// Program.cs
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis:6379";
    options.InstanceName = "idsrv:";
});
```

SQL Server is also an option:

```csharp
builder.Services.AddSqlServerCache(options =>
{
    options.ConnectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    options.SchemaName = "dbo";
    options.TableName = "DistributedCache";
});
```

## Do NOT rely on the default in-memory cache

The default `IDistributedCache` registered by ASP.NET Core (`MemoryDistributedCache`) is **per-process** — it is *not* actually distributed. Using it in a multi-instance deployment is what causes your problem. Always register `AddStackExchangeRedisCache` / `AddSqlServerCache` (or another genuinely shared backing store) for multi-instance.

## Don't forget the rest of the shared state

Distributed cache is one piece. For a correct multi-instance deployment you also need shared **Data Protection keys**, a shared **operational store** (persisted grants + signing keys via EF Core), and shared **server-side sessions** if enabled. But the intermittent external OIDC failures specifically point at the missing shared `IDistributedCache`.
