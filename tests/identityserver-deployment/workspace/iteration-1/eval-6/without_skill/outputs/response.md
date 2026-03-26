# Distributed Caching for Multi-Instance IdentityServer

## Problem

In a multi-instance deployment, each instance has its own in-memory cache. When OIDC login flows span multiple instances, the state data can't be found.

## Solution

Use Redis as a distributed cache:

```csharp
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis-service:6379";
});

builder.Services.AddIdentityServer()
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);
```

This ensures all instances share the same cache, so OIDC state data persists across instances. The distributed cache is also used for session management and token storage.
