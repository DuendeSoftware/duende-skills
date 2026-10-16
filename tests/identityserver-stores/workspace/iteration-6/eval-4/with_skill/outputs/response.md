```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddServerSideSessions()   // must be called to enable the feature
    .AddConfigurationStore(options =>
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly)))
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly));

        options.EnableTokenCleanup = true;
        options.RemoveConsumedTokens = true;      // consumed tokens are not removed otherwise
        options.ConsumedTokenCleanupDelay = 300;  // seconds
    });
```

- `AddServerSideSessions()` goes before/alongside `AddOperationalStore()`; otherwise session data isn't persisted. The operational store supplies the EF `IServerSideSessionStore` on `PersistedGrantDbContext`.
- `EnableTokenCleanup` alone doesn't remove consumed tokens; `RemoveConsumedTokens = true` does, after `ConsumedTokenCleanupDelay` (seconds, 6.3+). The cleanup also removes expired server-side sessions.
- Add a migration for the sessions table:
```shell
dotnet ef migrations add ServerSideSessions --context PersistedGrantDbContext \
  --output-dir Data/Migrations/IdentityServer/OperationalDb
```
