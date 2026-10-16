```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql => sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "identity_ops";
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__OperationalMigrationsHistory", "identity_ops");
            });

        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 900;          // 15 min, seconds
        options.TokenCleanupBatchSize = 500;         // default 100
        options.RemoveConsumedTokens = true;         // required for consumed-token removal
        options.ConsumedTokenCleanupDelay = 600;     // 10 min grace, seconds
        options.FuzzTokenCleanupStart = true;        // randomize first run across the 3 nodes
    });
```

Notes:
- All times are **seconds**. `ConsumedTokenCleanupDelay` only has effect when `RemoveConsumedTokens = true`; `EnableTokenCleanup` alone doesn't remove consumed tokens.
- `FuzzTokenCleanupStart` (default true, since 7.0) randomizes the first run; for very large scale consider disabling cleanup on web nodes and running a dedicated worker.
- Create the migration after setting the schema:
```shell
dotnet ef migrations add InitialIdentityServerOperationalDb \
  --context PersistedGrantDbContext --output-dir Data/Migrations/IdentityServer/OperationalDb
```
- Run migrations from a deploy pipeline, not startup, with 3 instances.
