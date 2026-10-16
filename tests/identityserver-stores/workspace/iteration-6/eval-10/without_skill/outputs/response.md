```csharp
var cs = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
        options.ConfigureDbContext = b => b.UseSqlServer(cs, sql => sql.MigrationsAssembly(migrationsAssembly)))
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(cs, sql => sql.MigrationsAssembly(migrationsAssembly));
        options.DefaultSchema = "identity_ops";

        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 900;        // 15 min (seconds)
        options.TokenCleanupBatchSize = 500;
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 600;   // 10 min (seconds)
        options.FuzzTokenCleanupStart = true;      // randomizes first run across instances
    });
```

Notes:
- Intervals and delays are in **seconds**.
- Fuzzing only staggers the initial start of each node's cleanup; with 3 nodes, batched deletes keep contention low.
- `DefaultSchema` is applied when migrations are generated, so create migrations after setting it:
```bash
dotnet ef migrations add InitialGrants -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c PersistedGrantDbContext
```
- To also put the migration history table in that schema: `sql.MigrationsHistoryTable("__EFMigrationsHistory", "identity_ops")`.
