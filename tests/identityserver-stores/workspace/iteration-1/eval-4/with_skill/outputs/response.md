# Server-Side Sessions with EF Core Operational Store

```csharp
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

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

- `AddServerSideSessions()` enables server-side session storage in the EF operational store.
- `EnableTokenCleanup = true` turns on the cleanup background service.
- `RemoveConsumedTokens = true` ensures consumed one-time tokens are cleaned up.
- `ConsumedTokenCleanupDelay = 300` waits 300 seconds after consumption before deleting.
