# Advanced Token Cleanup for High-Traffic Production

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

var migrationsAssembly = typeof(Program).Assembly.GetName().Name;
var connectionString = builder.Configuration.GetConnectionString("IdentityServer");

builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(migrationsAssembly));
    })
    .AddOperationalStore(options =>
    {
        // Custom schema for operational tables
        options.DefaultSchema = "identity_ops";

        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(migrationsAssembly);
                sql.MigrationsHistoryTable("__OpsMigrationsHistory", "identity_ops");
            });

        // Token cleanup configuration
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 900;          // 15 minutes
        options.TokenCleanupBatchSize = 500;         // 500 tokens per cycle
        options.RemoveConsumedTokens = true;          // Remove consumed tokens
        options.ConsumedTokenCleanupDelay = 600;     // 10-minute grace period
        options.FuzzTokenCleanupStart = true;         // Stagger across nodes
    });

var app = builder.Build();

app.UseIdentityServer();
app.MapGet("/", () => "IdentityServer is running");
app.Run();
```

## Key Points

- **`TokenCleanupBatchSize = 500`** — removes up to 500 expired tokens per cleanup cycle (default is 100)
- **`TokenCleanupInterval = 900`** — runs cleanup every 15 minutes (900 seconds)
- **`RemoveConsumedTokens = true`** — also deletes consumed one-time-use tokens
- **`ConsumedTokenCleanupDelay = 600`** — waits 10 minutes (600 seconds) after consumption before deleting, providing a grace period for replay detection
- **`FuzzTokenCleanupStart = true`** — randomizes the first cleanup run within the interval window to avoid all 3 nodes running cleanup at the same time
- **`DefaultSchema = "identity_ops"`** — places all operational tables in the `identity_ops` schema
