# Configuring Distributed Caching for Multi-Instance IdentityServer

## Why Your OIDC Login Flows Are Failing

The intermittent failures in your external OIDC provider login flows are caused by **the OIDC state data formatter storing state in `IDistributedCache`**. When a user starts an OIDC login flow on instance A, the state data (correlation ID, nonce, PKCE verifier, etc.) is stored in the cache on instance A. When the callback returns and is routed to instance B, it cannot find the state data because the default `MemoryDistributedCache` is local to each instance.

This is the classic multi-instance distributed cache problem with IdentityServer.

## What Requires IDistributedCache

Several IdentityServer features rely on ASP.NET Core's `IDistributedCache`:

| Feature | Why It Needs Distributed Cache |
|---------|-------------------------------|
| **OIDC state data formatter** | Stores external provider state (correlation, nonce, PKCE) server-side instead of in the URL |
| **JWT replay cache** | Prevents replay of JWT client credential assertions across instances |
| **Device flow throttling** | Rate-limits device code polling consistently across instances |
| **PAR authorization parameter store** | Stores Pushed Authorization Request data for retrieval during the authorization request |

Without a shared cache, any of these features will malfunction in a multi-instance deployment.

## Solution: Configure a Shared Distributed Cache

### Step 1: Add the Redis Cache Package

```bash
dotnet add package Microsoft.Extensions.Caching.StackExchangeRedis
```

### Step 2: Configure Redis in Program.cs

```csharp
using Duende.IdentityServer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Configure distributed cache with Redis
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis")
        ?? "redis-service:6379";
    options.InstanceName = "IdentityServer:";
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

### Step 3: Add Connection String

Update your `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=IdentityServer;Trusted_Connection=True;MultipleActiveResultSets=true",
    "Redis": "redis-service:6379"
  }
}
```

## Important: Do NOT Use In-Memory Cache

The default `MemoryDistributedCache` (registered by `AddDistributedMemoryCache()`) is local to each process. It does **not** share data across instances. In a multi-instance deployment, you **must** use a real distributed cache like Redis, SQL Server, or NCache.

Alternatives to Redis:

```csharp
// SQL Server
builder.Services.AddDistributedSqlServerCache(options =>
{
    options.ConnectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    options.SchemaName = "dbo";
    options.TableName = "DistributedCache";
});

// NCache
builder.Services.AddNCacheDistributedCache(options =>
{
    options.CacheName = "identityserver-cache";
});
```

## How the Fix Works

Once `AddStackExchangeRedisCache()` is registered, it replaces the default `IDistributedCache` implementation. IdentityServer's OIDC state data formatter and other features automatically use this shared cache. When a user starts an OIDC login on instance A and the callback hits instance B, instance B can read the state from Redis and complete the flow successfully.

## Verification

After deploying:
1. Verify Redis connectivity from all instances
2. Test external OIDC provider login flows multiple times — all should succeed regardless of which instance handles the callback
3. Monitor Redis for the cache entries (you should see keys prefixed with `IdentityServer:`)
