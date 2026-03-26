# Advanced Operational Store Configuration

```csharp
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");
var migrationsAssembly = typeof(Program).Assembly.GetName().Name;

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.DefaultSchema = "identity_ops";

        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__EFMigrationsHistory", "identity_ops");
            });

        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 900;          // 15 minutes
        options.TokenCleanupBatchSize = 500;         // 500 tokens per cycle
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 600;     // 10-minute grace period
        options.FuzzTokenCleanupStart = true;        // randomize first run
    });
```