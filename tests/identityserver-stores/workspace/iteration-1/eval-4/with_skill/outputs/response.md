# Server-Side Sessions with Token Cleanup

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddServerSideSessions()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));

        options.EnableTokenCleanup = true;
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 300;
    });
```

- `AddServerSideSessions()` enables server-side session storage
- The operational store (EF Core) automatically serves as the session store via `IServerSideSessionStore`
- `RemoveConsumedTokens = true` — removes one-time-use tokens that have been consumed
- `ConsumedTokenCleanupDelay = 300` — waits 300 seconds (5 minutes) after consumption before removal
- Token cleanup also handles expired sessions when server-side sessions are enabled