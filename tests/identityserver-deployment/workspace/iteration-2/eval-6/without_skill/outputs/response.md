# Distributed Caching for Multi-Instance IdentityServer

## Problem

In a multi-instance deployment, you need a shared cache because the default in-memory cache is per-instance. This can cause issues with various features that rely on caching.

## Solution

Use Redis as a distributed cache:

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis-server:6379";
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();
app.UseIdentityServer();
app.Run();
```

This ensures that cached data is shared across all instances. Without it, things like session data and tokens cached on one instance won't be available on another.

You could also use SQL Server distributed cache (`AddSqlServerCache`) or NCache depending on your infrastructure.
