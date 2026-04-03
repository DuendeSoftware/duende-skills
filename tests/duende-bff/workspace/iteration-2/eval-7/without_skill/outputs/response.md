When running multiple instances behind a load balancer, users getting randomly logged out is almost certainly a **cookie encryption issue**. Each instance of your ASP.NET Core application generates its own cryptographic keys for encrypting cookies by default.

When a user logs in on Instance A, the authentication cookie is encrypted with Instance A's key. When the next request goes to Instance B, it can't decrypt that cookie, so the user appears logged out.

## Fix: Share the Data Protection Keys

You need to configure ASP.NET Core Data Protection to use a shared key store:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<MyDbContext>()
    .SetApplicationName("my-bff");
```

Or with Redis:
```csharp
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(ConnectionMultiplexer.Connect("redis:6379"), "DataProtection-Keys");
```

You should also consider using a shared session store (like a database or Redis) instead of in-memory sessions, so that session data is accessible regardless of which instance handles the request.

Make sure all instances use the same `SetApplicationName` value so they all share the same key ring.
